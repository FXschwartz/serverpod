import 'dart:async';
import 'dart:io';

import 'package:serverpod/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'future_call_diagnostics_service.dart';

/// Callback used to dispatch entries from the scanner.
typedef DispatchEntries = void Function(List<FutureCallEntry> entries);

/// A function that determines whether the scanner should skip the scan.
/// If true, the scanner will not scan the database.
typedef ShouldSkipScan = bool Function();

/// Scans the database for overdue future calls and dispatches them.
/// Also scans the reactive outbox for unclaimed events.
class FutureCallScanner {
  final Session _internalSession;
  final FutureCallDiagnosticsService _diagnosticReporting;

  Timer? _timer;
  Timer? _reactiveTimer;

  final Duration _scanInterval;

  final ShouldSkipScan _shouldSkipScan;
  final DispatchEntries _dispatchEntries;

  bool _isStopping = false;

  var _scanCompleter = Completer<void>()..complete();
  var _reactiveScanCompleter = Completer<void>()..complete();

  /// Creates a new [FutureCallScanner].
  ///
  /// The [internalSession] is used to access the database.
  ///
  /// The [scanInterval] is the interval at which the scanner will scan the
  /// database for overdue future calls.
  ///
  /// The [shouldSkipScan] is a callback that determines whether the scanner
  /// should skip the scan. If it returns true, the scanner will not scan the
  /// database.
  ///
  /// The [dispatchEntries] is a callback that is called with the list of
  /// overdue future calls that were found in the database.
  ///
  /// The [diagnosticsService] is used to report any errors that occur during
  /// the scan.
  FutureCallScanner({
    required Session internalSession,
    required Duration scanInterval,
    required ShouldSkipScan shouldSkipScan,
    required DispatchEntries dispatchEntries,
    required FutureCallDiagnosticsService diagnosticsService,
  }) : _internalSession = internalSession,
       _scanInterval = scanInterval,
       _shouldSkipScan = shouldSkipScan,
       _dispatchEntries = dispatchEntries,
       _diagnosticReporting = diagnosticsService;

  /// Scans the database for overdue future calls and queues them for execution.
  Future<void> scanFutureCallEntries() async {
    if (_isStopping || !_scanCompleter.isCompleted || _shouldSkipScan()) {
      return;
    }

    _scanCompleter = Completer<void>();

    try {
      final now = DateTime.now().toUtc();

      final entries = await FutureCallEntry.db.find(
        _internalSession,
        where: (row) => row.time <= now,
      );

      entries.sort((a, b) => a.time.compareTo(b.time));

      _dispatchEntries(entries);
    } catch (error, stackTrace) {
      // Most likely we lost connection to the database
      var message =
          'Internal server error. Failed to connect to database in future call manager.';

      _diagnosticReporting.submitFrameworkException(
        error,
        stackTrace,
        message: message,
      );

      stderr.writeln('${DateTime.now().toUtc()} $message');
      stderr.writeln('$error');
      stderr.writeln('$stackTrace');
      stderr.writeln('Local stacktrace:');
      stderr.writeln('${StackTrace.current}');
    }

    _scanCompleter.complete();
  }

  /// Scans the reactive outbox for unclaimed events and creates
  /// [FutureCallEntry] records for them.
  ///
  /// Groups unclaimed outbox events by `futureCallName`, creates a
  /// [FutureCallEntry] for each group with `time` set to now (immediate
  /// execution), then claims the outbox events by setting their
  /// `futureCallEntryId` to the new entry's ID.
  ///
  /// All operations for each group are performed in a transaction to
  /// prevent race conditions across server instances.
  Future<void> scanReactiveOutbox() async {
    if (_isStopping || !_reactiveScanCompleter.isCompleted) {
      return;
    }

    _reactiveScanCompleter = Completer<void>();

    try {
      // Find all unclaimed outbox events.
      final unclaimedEvents = await ReactiveDatabaseCallEntry.db.find(
        _internalSession,
        where: (t) => t.futureCallEntryId.equals(null),
      );

      if (unclaimedEvents.isEmpty) {
        _reactiveScanCompleter.complete();
        return;
      }

      // Group by future call name.
      final groupedEvents = <String, List<ReactiveDatabaseCallEntry>>{};
      for (final event in unclaimedEvents) {
        groupedEvents.putIfAbsent(event.futureCallName, () => []).add(event);
      }

      // For each group, create a FutureCallEntry and claim the events.
      for (final entry in groupedEvents.entries) {
        final futureCallName = entry.key;
        final events = entry.value;

        try {
          await _internalSession.db.transaction((transaction) async {
            // Create a FutureCallEntry for immediate execution.
            final futureCallEntry = await FutureCallEntry.db.insertRow(
              _internalSession,
              FutureCallEntry(
                name: futureCallName,
                time: DateTime.now().toUtc(),
                serverId: 'reactive',
              ),
              transaction: transaction,
            );

            // Claim all outbox events by setting their futureCallEntryId.
            for (final event in events) {
              await ReactiveDatabaseCallEntry.db.updateRow(
                _internalSession,
                event.copyWith(futureCallEntryId: futureCallEntry.id),
                transaction: transaction,
              );
            }
          });
        } catch (error, stackTrace) {
          _diagnosticReporting.submitFrameworkException(
            error,
            stackTrace,
            message:
                'Failed to claim reactive outbox events for $futureCallName.',
          );
        }
      }
    } catch (error, stackTrace) {
      var message = 'Internal server error. Failed to scan reactive outbox.';

      _diagnosticReporting.submitFrameworkException(
        error,
        stackTrace,
        message: message,
      );

      stderr.writeln('${DateTime.now().toUtc()} $message');
      stderr.writeln('$error');
      stderr.writeln('$stackTrace');
    }

    _reactiveScanCompleter.complete();
  }

  /// Starts the task scanner, which will scan the database for overdue future
  /// calls at the given interval.
  void start() {
    if (_timer != null) {
      return;
    }

    _timer = Timer.periodic(
      _scanInterval,
      (_) => scanFutureCallEntries(),
    );
  }

  /// Starts the reactive outbox scanner with the given [scanInterval].
  void startReactiveOutboxScanner({required Duration scanInterval}) {
    if (_reactiveTimer != null) {
      return;
    }

    _reactiveTimer = Timer.periodic(
      scanInterval,
      (_) => scanReactiveOutbox(),
    );
  }

  /// Stops the task scanner.
  Future<void> stop() async {
    _isStopping = true;

    _timer?.cancel();
    _reactiveTimer?.cancel();

    await _scanCompleter.future;
    await _reactiveScanCompleter.future;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:serverpod/src/generated/reactive_database_call_entry.dart';
import 'package:serverpod/src/server/reactive_database_call_manager/reactive_database_call.dart';
import 'package:serverpod/src/server/reactive_database_call_manager/trigger_sql_builder.dart';
import 'package:serverpod/src/server/session.dart';
import 'package:serverpod_database/serverpod_database.dart';

/// Callback to build a [Session] for executing a reactive database call.
typedef ReactiveCallSessionBuilder = Session Function(String handlerName);

/// Manages the lifecycle of [ReactiveDatabaseCall] triggers and outbox
/// scanning.
///
/// Responsible for:
/// - Creating triggers during initialization via `CREATE OR REPLACE`
/// - Cleaning up orphaned triggers from previously registered handlers
/// - Polling the outbox table for new entries
/// - Dispatching entries to the appropriate [ReactiveDatabaseCall.react] method
class ReactiveDatabaseCallManager {
  final Session _internalSession;
  final ReactiveCallSessionBuilder _sessionBuilder;
  final SerializationManagerServer _serializationManager;

  final Map<String, ReactiveDatabaseCall> _reactiveCalls = {};

  Timer? _timer;
  final Duration _scanInterval;
  bool _isStopping = false;
  var _scanCompleter = Completer<void>()..complete();

  /// Creates a new [ReactiveDatabaseCallManager].
  ReactiveDatabaseCallManager({
    required Session internalSession,
    required ReactiveCallSessionBuilder sessionBuilder,
    required SerializationManagerServer serializationManager,
    Duration scanInterval = const Duration(seconds: 1),
  }) : _internalSession = internalSession,
       _sessionBuilder = sessionBuilder,
       _serializationManager = serializationManager,
       _scanInterval = scanInterval;

  /// Registers a [ReactiveDatabaseCall] with the manager
  void register(String name, ReactiveDatabaseCall call) {
    _reactiveCalls[name] = call;
  }

  /// Initializes all triggers for registered reactive calls and cleans up
  /// orphaned triggers from handlers that are no longer registered.
  Future<void> initializeTriggers() async {
    for (var entry in _reactiveCalls.entries) {
      await _createTrigger(entry.key, entry.value);
    }
    await _cleanupOrphanedTriggers();
  }

  /// Starts the outbox scanner, which polls the outbox table at the configured
  /// interval and dispatches entries to the appropriate handlers.
  void start() {
    if (_timer != null || _reactiveCalls.isEmpty) return;
    _timer = Timer.periodic(_scanInterval, (_) => scanOutboxEntries());
  }

  /// Stops the outbox scanner
  Future<void> stop() async {
    _isStopping = true;
    _timer?.cancel();
    _timer = null;
    await _scanCompleter.future;
  }

  /// Scans the outbox table for entries and dispatches them to the appropriate
  /// handlers.
  Future<void> scanOutboxEntries() async {
    if (_isStopping || !_scanCompleter.isCompleted) return;
    _scanCompleter = Completer<void>();

    try {
      // Atomically delete-and-return all entries to prevent double processing
      var entries = await ReactiveDatabaseCallEntry.db.deleteWhere(
        _internalSession,
        where: (row) => row.id > const Expression(0),
      );

      if (entries.isEmpty) {
        _scanCompleter.complete();
        return;
      }

      entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Group entries by handler name
      final grouped = <String, List<ReactiveDatabaseCallEntry>>{};
      for (var entry in entries) {
        grouped.putIfAbsent(entry.handlerName, () => []).add(entry);
      }

      // Dispatch each group to the corresponding handler
      for (var group in grouped.entries) {
        var handler = _reactiveCalls[group.key];
        if (handler == null) {
          stderr.writeln(
            '${DateTime.now().toUtc()} Reactive database call handler '
            '"${group.key}" not found. Skipping ${group.value.length} entries.',
          );
          continue;
        }
        await _dispatchToHandler(handler, group.key, group.value);
      }
    } catch (error, stackTrace) {
      stderr.writeln(
        '${DateTime.now().toUtc()} Error scanning reactive database call '
        'outbox: $error',
      );
      stderr.writeln('$stackTrace');
    }
    _scanCompleter.complete();
  }

  Future<void> _dispatchToHandler(
    ReactiveDatabaseCall handler,
    String handlerName,
    List<ReactiveDatabaseCallEntry> entries,
  ) async {
    var session = _sessionBuilder(handlerName);

    try {
      var objects = entries
          .map((e) => _deserializeRowData(e.rowData, handler.dataType))
          .whereType<TableRow>()
          .toList();

      if (objects.isNotEmpty) {
        await handler.react(session, objects);
      }
      await session.close();
    } catch (error, stackTrace) {
      stderr.writeln(
        '${DateTime.now().toUtc()} Error dispatching reactive database call '
        '"$handlerName": $error',
      );
      stderr.writeln('$stackTrace');
      await session.close(error: error, stackTrace: stackTrace);
    }
  }

  TableRow? _deserializeRowData(String rowDataJson, Type dataType) {
    try {
      var jsonData = jsonDecode(rowDataJson) as Map<String, dynamic>;
      return _serializationManager.deserialize<TableRow>(jsonData, dataType);
    } catch (error, _) {
      stderr.writeln(
        '${DateTime.now().toUtc()} Error deserializing reactive database '
        'call row data: $error',
      );
      return null;
    }
  }

  Future<void> _createTrigger(
    String handlerName,
    ReactiveDatabaseCall call,
  ) async {
    final builder = TriggerSqlBuilder(
      handlerName: handlerName,
      tableName: call.tableName,
      condition: call.condition,
    );

    await _internalSession.db.unsafeExecute(builder.buildFunctionSql());
    await _internalSession.db.unsafeExecute(builder.buildTriggerSql());
  }

  /// Queries pg_trigger for triggers matching the `_serverpod_reactive_%`
  /// naming convention and drops any that don't have a matching registered
  /// handler.
  Future<void> _cleanupOrphanedTriggers() async {
    final result = await _internalSession.db.unsafeQuery(
      'SELECT tgname, relname FROM pg_trigger '
      'JOIN pg_class ON pg_trigger.tgrelid = pg_class.oid '
      "WHERE tgname LIKE '_serverpod_reactive_%' "
      'AND NOT tgisinternal;',
    );
    for (var row in result) {
      var triggerName = row[0] as String;
      var tableName = row[1] as String;

      // Extract handler name by removed the prefix
      var handlerName = triggerName.replaceFirst('_serverpod_reactive_', '');

      if (!_reactiveCalls.containsKey(handlerName)) {
        await _internalSession.db.unsafeExecute(
          TriggerSqlBuilder.buildDropTriggerSql(triggerName, tableName),
        );
        await _internalSession.db.unsafeExecute(
          TriggerSqlBuilder.buildDropFunctionSql('${triggerName}_fn'),
        );
      }
    }
  }
}

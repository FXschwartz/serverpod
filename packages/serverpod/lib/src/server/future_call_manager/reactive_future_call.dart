import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../../generated/protocol.dart';
import '../session.dart';
import 'future_call.dart';

/// An event representing a database row change detected by a reactive trigger.
class ReactiveEvent<T> {
  /// The row data, deserialized to the model type.
  final T row;

  /// The type of operation that triggered this event:
  /// `INSERT`, `UPDATE`, or `DELETE`.
  final String operation;

  /// Creates a new [ReactiveEvent].
  ReactiveEvent({required this.row, required this.operation});
}

/// A [FutureCall] that reacts to database table changes.
///
/// Subclass this to define a reactive future call that watches a specific
/// database table for changes and processes batched events.
///
/// ```dart
/// class TripChangeHandler extends ReactiveFutureCall<Trip> {
///   @override
///   String get watchTable => 'trip';
///
///   @override
///   TriggerExpression? get when => Trip.t.status.hasChanged();
///
///   @override
///   Future<void> react(Session session, List<ReactiveEvent<Trip>> events) async {
///     for (final event in events) {
///       print('Trip ${event.row.id} was ${event.operation}');
///     }
///   }
/// }
/// ```
abstract class ReactiveFutureCall<T extends SerializableModel>
    extends FutureCall<SerializableModel> {
  /// The name of the database table to watch for changes.
  String get watchTable;

  /// Optional trigger condition expression.
  ///
  /// If null, the trigger fires on all INSERT, UPDATE, and DELETE operations.
  /// Use [Column.hasChanged] to create expressions that filter by column changes:
  ///
  /// ```dart
  /// @override
  /// TriggerExpression? get when => Trip.t.status.hasChanged();
  /// ```
  TriggerExpression? get when => null;

  /// Called when database changes are detected on the watched table.
  ///
  /// The [events] list contains one or more [ReactiveEvent]s that were
  /// batched together since the last scan. Each event contains the
  /// deserialized row data and the operation type.
  Future<void> react(Session session, List<ReactiveEvent<T>> events);

  /// Internal method called by [FutureCallManager] to process claimed
  /// outbox events for a specific [FutureCallEntry].
  ///
  /// Queries the outbox for events claimed by [entryId], deserializes
  /// each row's JSON data to type [T], and calls [react] with the
  /// typed events.
  Future<void> invokeWithEntryId(
    Session session,
    int entryId,
    SerializationManager serializationManager,
  ) async {
    final outboxEvents = await ReactiveDatabaseCallEntry.db.find(
      session,
      where: (t) => t.futureCallEntryId.equals(entryId),
    );

    final typedEvents = outboxEvents.map((event) {
      return ReactiveEvent<T>(
        row: serializationManager.decode<T>(event.rowData, T),
        operation: event.operation,
      );
    }).toList();

    await react(session, typedEvents);
  }

  /// Reactive future calls should not be invoked directly.
  /// Use [invokeWithEntryId] instead.
  @override
  Future<void> invoke(Session session, SerializableModel? object) {
    throw StateError(
      'ReactiveFutureCall should not be invoked directly. '
      'Use invokeWithEntryId instead.',
    );
  }
}

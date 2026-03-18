import 'package:serverpod_database/serverpod_database.dart';

import '../future_call_manager/future_call.dart';
import '../session.dart';

/// A [FutureCall] that reacts to changes in the database.
///
/// Subclasses define a [condition] that is used as a `WHEN` clause on a
/// PostgreSQL trigger. When matching rows are inserted, updated, or deleted,
/// the change is recorded in an outbox table and dispatched to [react].
///
/// Typically, users extend a generated per-model intermediate class
/// (e.g., `TripReactiveDatabaseCall`) rather than this class directly.
abstract class ReactiveDatabaseCall<T extends TableRow> extends FutureCall<T> {
  /// The database table this reactive call watches.
  String get tableName;

  /// The trigger WHEN clause condition. If null, all changes fire the trigger.
  Expression? get condition => null;

  /// Called when matching changes are detected in the outbox.
  Future<void> react(Session session, List<T> objects);

  @override
  Future<void> invoke(Session session, T? object) => Future.value();
}

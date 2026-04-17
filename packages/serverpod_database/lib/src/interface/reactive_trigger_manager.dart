import '../../serverpod_database.dart';

/// Abstract interface for managing reactive database triggers.
///
/// Reactive triggers watch for changes on specific tables and write events
/// to an outbox table. The [ReactiveFutureCall] system then processes
/// those events.
///
/// Each database dialect provides its own implementation. Dialects that
/// do not support triggers return `null` from
/// [DatabaseProvider.createReactiveTriggerManager].
abstract interface class ReactiveTriggerManager {
  /// The prefix used for all reactive trigger names.
  static const triggerNamePrefix = 'serverpod_reactive_';

  /// The prefix used for all reactive trigger function names.
  static const triggerFunctionPrefix = 'serverpod_reactive_fn_';

  /// Creates or replaces a trigger on [tableName] that writes events to
  /// [outboxTableName] when rows change.
  ///
  /// - [triggerName]: Unique name for the trigger (should use [triggerNamePrefix]).
  /// - [tableName]: The table to watch for changes.
  /// - [outboxTableName]: The outbox table to write events to.
  /// - [futureCallName]: The name of the future call to associate with events.
  /// - [when]: Optional expression to filter which changes trigger an event.
  ///   If null, all INSERT, UPDATE, and DELETE operations trigger events.
  ///   If the expression only references `OLD` values (i.e., `hasChanged()`),
  ///   the trigger fires on UPDATE only. If it references `NEW` values,
  ///   the trigger fires on INSERT and UPDATE.
  Future<void> createOrReplaceTrigger({
    required String triggerName,
    required String tableName,
    required String outboxTableName,
    required String futureCallName,
    TriggerExpression? when,
  });

  /// Drops a specific trigger and its associated function by [triggerName].
  Future<void> dropTrigger({
    required String triggerName,
    required String tableName,
  });

  /// Drops all reactive triggers (those with the [triggerNamePrefix]).
  Future<void> dropAllReactiveTriggers();

  /// Lists all reactive trigger names currently in the database.
  Future<List<String>> listReactiveTriggers();

  /// Lists all reactive triggers with their associated table names.
  /// Used for targeted cleanup of orphaned triggers.
  Future<List<({String triggerName, String tableName})>>
  listReactiveTriggersWithTables();
}

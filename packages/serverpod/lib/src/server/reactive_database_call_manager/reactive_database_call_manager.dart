import 'package:serverpod/src/server/reactive_database_call_manager/reactive_database_call.dart';
import 'package:serverpod/src/server/reactive_database_call_manager/trigger_sql_builder.dart';
import 'package:serverpod/src/server/session.dart';

/// Manages the lifecycle of [ReactiveDatabaseCall] triggers.
///
/// Responsible for:
/// - Creating triggers during initialization via `CREATE OR REPLACE`
/// - Cleaning up orphaned triggers from previously registered handlers
class ReactiveDatabaseCallManager {
  final Session _internalSession;
  final Map<String, ReactiveDatabaseCall> _reactiveCalls = {};

  /// Creates a new [ReactiveDatabaseCallManager].
  ReactiveDatabaseCallManager({required Session internalSession})
    : _internalSession = internalSession;

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

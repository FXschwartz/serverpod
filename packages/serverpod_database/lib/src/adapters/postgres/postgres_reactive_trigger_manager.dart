import 'package:meta/meta.dart';

import '../../../serverpod_database.dart';

/// PostgreSQL implementation of [ReactiveTriggerManager].
///
/// Creates triggers that write row change events to an outbox table
/// using `row_to_json(NEW)` / `row_to_json(OLD)` for serialization.
@internal
class PostgresReactiveTriggerManager implements ReactiveTriggerManager {
  final Database _database;

  /// Creates a new [PostgresReactiveTriggerManager].
  PostgresReactiveTriggerManager(this._database);

  @override
  Future<void> createOrReplaceTrigger({
    required String triggerName,
    required String tableName,
    required String outboxTableName,
    required String futureCallName,
    TriggerExpression? when,
  }) async {
    final functionName =
        '${ReactiveTriggerManager.triggerFunctionPrefix}$triggerName';

    final triggerEvents = _resolveTriggerEvents(when);
    final whenClause =
        when != null ? '\n  WHEN (${when.toWhenClause()})' : '';

    final functionSql = '''
CREATE OR REPLACE FUNCTION "$functionName"()
RETURNS TRIGGER AS \$\$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    INSERT INTO "$outboxTableName"
      ("futureCallName", "sourceTable", "operation", "rowData", "createdAt")
    VALUES
      ('$futureCallName', '$tableName', TG_OP, row_to_json(OLD)::text, now());
    RETURN OLD;
  ELSE
    INSERT INTO "$outboxTableName"
      ("futureCallName", "sourceTable", "operation", "rowData", "createdAt")
    VALUES
      ('$futureCallName', '$tableName', TG_OP, row_to_json(NEW)::text, now());
    RETURN NEW;
  END IF;
END;
\$\$ LANGUAGE plpgsql;''';

    final triggerSql = '''
CREATE OR REPLACE TRIGGER "$triggerName"
  AFTER $triggerEvents ON "$tableName"
  FOR EACH ROW$whenClause
  EXECUTE FUNCTION "$functionName"();''';

    await _database.unsafeExecute('$functionSql\n$triggerSql');
  }

  @override
  Future<void> dropTrigger({
    required String triggerName,
    required String tableName,
  }) async {
    final functionName =
        '${ReactiveTriggerManager.triggerFunctionPrefix}$triggerName';

    await _database.unsafeExecute('''
DROP TRIGGER IF EXISTS "$triggerName" ON "$tableName";
DROP FUNCTION IF EXISTS "$functionName"();''');
  }

  @override
  Future<void> dropAllReactiveTriggers() async {
    // Query for all reactive triggers and their tables.
    final result = await _database.unsafeQuery('''
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_name LIKE '${ReactiveTriggerManager.triggerNamePrefix}%'
GROUP BY trigger_name, event_object_table;''');

    for (final row in result) {
      final triggerName = row[0] as String;
      final tableName = row[1] as String;

      await dropTrigger(triggerName: triggerName, tableName: tableName);
    }
  }

  @override
  Future<List<String>> listReactiveTriggers() async {
    final result = await _database.unsafeQuery('''
SELECT DISTINCT trigger_name
FROM information_schema.triggers
WHERE trigger_name LIKE '${ReactiveTriggerManager.triggerNamePrefix}%';''');

    return result.map((row) => row[0] as String).toList();
  }

  @override
  Future<List<({String triggerName, String tableName})>>
  listReactiveTriggersWithTables() async {
    final result = await _database.unsafeQuery('''
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_name LIKE '${ReactiveTriggerManager.triggerNamePrefix}%'
GROUP BY trigger_name, event_object_table;''');

    return result
        .map(
          (row) => (
            triggerName: row[0] as String,
            tableName: row[1] as String,
          ),
        )
        .toList();
  }

  /// Determines the trigger events based on the [when] expression.
  ///
  /// - No expression: `INSERT OR UPDATE OR DELETE`
  /// - Expression with only `hasChanged()` (references OLD only):
  ///   `UPDATE` (since INSERT has no OLD row)
  /// - Expression referencing NEW values: `INSERT OR UPDATE`
  String _resolveTriggerEvents(TriggerExpression? when) {
    if (when == null) {
      return 'INSERT OR UPDATE OR DELETE';
    }

    // HasChangedExpression uses OLD IS DISTINCT FROM NEW, which requires
    // both OLD and NEW to exist. This means it can only fire on UPDATE.
    // However, users may want to also catch INSERTs. We use INSERT OR UPDATE
    // as the default when a WHEN clause is present, since the WHEN clause
    // itself will filter out non-matching events.
    return 'INSERT OR UPDATE';
  }
}

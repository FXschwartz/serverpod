import 'package:serverpod_database/serverpod_database.dart';

/// Builds PostgreSQL trigger and function DDL for [ReactiveFutureCall]s.
///
/// Converts Serverpod [Expression]s into trigger WHEN clauses by replacing
/// table-qualified column references with `NEW.` prefixed references.
/// [HasChangedExpression]s are left untouched as they already produce
/// `OLD."col" IS DISTINCT FROM NEW."col"`.
class TriggerSqlBuilder {
  /// The name used for the trigger and function, prefixed with
  /// `_serverpod_reactive_`.
  final String handlerName;

  /// The database table the trigger is attached to.
  final String tableName;

  /// The optional condition expression for the WHEN clause.
  final Expression? condition;

  /// Creates a new [TriggerSqlBuilder].
  TriggerSqlBuilder({
    required this.handlerName,
    required this.tableName,
    this.condition,
  });

  /// Whether the condition contains any [HasChangedExpression]s.
  ///
  /// When true, the trigger is restricted to `AFTER UPDATE` only because
  /// `OLD` is not available for INSERT triggers and `NEW` is not available
  /// for DELETE triggers.
  bool get _hasChangedExpressions {
    if (condition == null) return false;
    return condition!.depthFirst.any((e) => e is HasChangedExpression);
  }

  String get _triggerName => '_serverpod_reactive_$handlerName';
  String get _functionName => '_serverpod_reactive_${handlerName}_fn';

  /// The trigger events based on whether hasChanged() is used.
  String get _triggerEvents {
    if (_hasChangedExpressions) return 'UPDATE';
    return 'INSERT OR UPDATE OR DELETE';
  }

  /// Converts a condition [Expression] to a trigger WHEN clause string.
  ///
  /// Standard column expressions like `"tableName"."col" = 'value'` are
  /// converted to `NEW."col" = 'value'` by replacing the table prefix.
  /// [HasChangedExpression]s already output `OLD."col" IS DISTINCT FROM
  /// NEW."col"` and are left unchanged.
  String convertExpressionToWhenClause(Expression expression) {
    var sql = expression.toString();
    // Replace table-qualified column references with NEW. prefix.
    // Pattern: "tableName"."colName" → NEW."colName"
    sql = sql.replaceAll('"$tableName".', 'NEW.');
    return sql;
  }

  /// Builds the CREATE OR REPLACE FUNCTION DDL.
  String buildFunctionSql() {
    return '''
CREATE OR REPLACE FUNCTION "$_functionName"()
RETURNS TRIGGER AS \$\$
BEGIN
  INSERT INTO "serverpod_reactive_db_call"
    ("handlerName", "sourceTable", "operation", "rowData", "createdAt")
  VALUES (
    '$handlerName',
    TG_TABLE_NAME,
    TG_OP,
    CASE WHEN TG_OP = 'DELETE' THEN row_to_json(OLD.*) ELSE row_to_json(NEW.*) END,
    NOW()
  );
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
\$\$ LANGUAGE plpgsql;''';
  }

  /// Builds the CREATE OR REPLACE TRIGGER DDL.
  String buildTriggerSql() {
    var whenClause = '';
    if (condition != null) {
      whenClause = '\nWHEN (${convertExpressionToWhenClause(condition!)})';
    }

    return '''
CREATE OR REPLACE TRIGGER "$_triggerName"
AFTER $_triggerEvents ON "$tableName"
FOR EACH ROW$whenClause
EXECUTE FUNCTION "$_functionName"();''';
  }

  /// Builds both the function and trigger DDL statements.
  String buildSql() {
    return '${buildFunctionSql()}\n\n${buildTriggerSql()}';
  }

  /// Builds a DROP statement for the trigger.
  static String buildDropTriggerSql(String triggerName, String tableName) {
    return 'DROP TRIGGER IF EXISTS "$triggerName" ON "$tableName";';
  }

  /// Builds a DROP statement for the trigger function.
  static String buildDropFunctionSql(String functionName) {
    return 'DROP FUNCTION IF EXISTS "$functionName"();';
  }
}

import '../../serverpod_database.dart';

/// Base class for trigger WHEN clause expressions.
///
/// These expressions are used to build `WHEN` clauses for database triggers.
/// They are composable using `&` (AND) and `|` (OR) operators.
///
/// Unlike regular [Expression]s which render via `toString()` for SQL WHERE
/// clauses, trigger expressions render via [toWhenClause()] for trigger
/// WHEN clauses using `OLD`/`NEW` row references.
abstract class TriggerExpression extends Expression {
  /// Creates a new [TriggerExpression].
  TriggerExpression() : super('');

  /// Returns the SQL `WHEN` clause for this expression.
  String toWhenClause();

  @override
  TriggerExpression operator &(Expression other) {
    if (other is! TriggerExpression) {
      throw ArgumentError(
        'Cannot compose TriggerExpression with ${other.runtimeType}. '
        'Use hasChanged() expressions only.',
      );
    }
    return _TriggerAndExpression(this, other);
  }

  @override
  TriggerExpression operator |(Expression other) {
    if (other is! TriggerExpression) {
      throw ArgumentError(
        'Cannot compose TriggerExpression with ${other.runtimeType}. '
        'Use hasChanged() expressions only.',
      );
    }
    return _TriggerOrExpression(this, other);
  }
}

/// An expression representing that a column's value has changed in a
/// database trigger context.
///
/// Renders to `OLD."columnName" IS DISTINCT FROM NEW."columnName"` in
/// PostgreSQL.
///
/// Compose multiple expressions using `&` (AND) and `|` (OR):
/// ```dart
/// table.name.hasChanged() & table.email.hasChanged()
/// ```
class HasChangedExpression extends TriggerExpression {
  /// The column that is being watched for changes.
  final Column column;

  /// Creates a new [HasChangedExpression] for the given [column].
  HasChangedExpression(this.column);

  @override
  String toWhenClause() {
    return 'OLD."${column.columnName}" IS DISTINCT FROM '
        'NEW."${column.columnName}"';
  }

  @override
  List<Column> get columns => [column];
}

class _TriggerAndExpression extends TriggerExpression {
  final TriggerExpression _left;
  final TriggerExpression _right;

  _TriggerAndExpression(this._left, this._right);

  @override
  String toWhenClause() {
    return '(${_left.toWhenClause()} AND ${_right.toWhenClause()})';
  }

  @override
  List<Column> get columns => [..._left.columns, ..._right.columns];
}

class _TriggerOrExpression extends TriggerExpression {
  final TriggerExpression _left;
  final TriggerExpression _right;

  _TriggerOrExpression(this._left, this._right);

  @override
  String toWhenClause() {
    return '(${_left.toWhenClause()} OR ${_right.toWhenClause()})';
  }

  @override
  List<Column> get columns => [..._left.columns, ..._right.columns];
}

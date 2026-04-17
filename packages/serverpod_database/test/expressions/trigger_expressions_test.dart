import 'package:serverpod_database/src/concepts/columns.dart';
import 'package:serverpod_database/src/concepts/table.dart';
import 'package:serverpod_database/src/concepts/trigger_expressions.dart';
import 'package:test/test.dart';

void main() {
  var testTable = Table<int?>(tableName: 'test');

  group('Given a single column', () {
    var column = ColumnString('name', testTable);

    test(
      'when hasChanged is called then toWhenClause returns correct SQL',
      () {
        var expression = column.hasChanged();

        expect(
          expression.toWhenClause(),
          'OLD."name" IS DISTINCT FROM NEW."name"',
        );
      },
    );

    test(
      'when hasChanged is called then columns contains the column',
      () {
        var expression = column.hasChanged();

        expect(expression.columns, [column]);
      },
    );
  });

  group('Given two columns', () {
    var nameColumn = ColumnString('name', testTable);
    var emailColumn = ColumnString('email', testTable);

    test(
      'when composed with AND then toWhenClause returns correct SQL',
      () {
        TriggerExpression expression =
            nameColumn.hasChanged() & emailColumn.hasChanged();

        expect(
          expression.toWhenClause(),
          '(OLD."name" IS DISTINCT FROM NEW."name" AND '
          'OLD."email" IS DISTINCT FROM NEW."email")',
        );
      },
    );

    test(
      'when composed with OR then toWhenClause returns correct SQL',
      () {
        TriggerExpression expression =
            nameColumn.hasChanged() | emailColumn.hasChanged();

        expect(
          expression.toWhenClause(),
          '(OLD."name" IS DISTINCT FROM NEW."name" OR '
          'OLD."email" IS DISTINCT FROM NEW."email")',
        );
      },
    );

    test(
      'when composed with AND then columns contains both columns',
      () {
        var expression = nameColumn.hasChanged() & emailColumn.hasChanged();

        expect(expression.columns, [nameColumn, emailColumn]);
      },
    );
  });

  group('Given three columns', () {
    var nameColumn = ColumnString('name', testTable);
    var emailColumn = ColumnString('email', testTable);
    var ageColumn = ColumnInt('age', testTable);

    test(
      'when composed with mixed AND and OR then toWhenClause nests correctly',
      () {
        TriggerExpression expression =
            (nameColumn.hasChanged() | emailColumn.hasChanged()) &
            ageColumn.hasChanged();

        expect(
          expression.toWhenClause(),
          '((OLD."name" IS DISTINCT FROM NEW."name" OR '
          'OLD."email" IS DISTINCT FROM NEW."email") AND '
          'OLD."age" IS DISTINCT FROM NEW."age")',
        );
      },
    );

    test(
      'when composed with mixed operators then columns contains all columns',
      () {
        var expression =
            (nameColumn.hasChanged() | emailColumn.hasChanged()) &
            ageColumn.hasChanged();

        expect(expression.columns, [nameColumn, emailColumn, ageColumn]);
      },
    );
  });

  group('Given different column types', () {
    test('when ColumnInt hasChanged then toWhenClause is correct', () {
      var column = ColumnInt('count', testTable);
      var expression = column.hasChanged();

      expect(
        expression.toWhenClause(),
        'OLD."count" IS DISTINCT FROM NEW."count"',
      );
    });

    test('when ColumnBool hasChanged then toWhenClause is correct', () {
      var column = ColumnBool('active', testTable);
      var expression = column.hasChanged();

      expect(
        expression.toWhenClause(),
        'OLD."active" IS DISTINCT FROM NEW."active"',
      );
    });

    test('when ColumnDateTime hasChanged then toWhenClause is correct', () {
      var column = ColumnDateTime('updatedAt', testTable);
      var expression = column.hasChanged();

      expect(
        expression.toWhenClause(),
        'OLD."updatedAt" IS DISTINCT FROM NEW."updatedAt"',
      );
    });

    test('when ColumnDouble hasChanged then toWhenClause is correct', () {
      var column = ColumnDouble('price', testTable);
      var expression = column.hasChanged();

      expect(
        expression.toWhenClause(),
        'OLD."price" IS DISTINCT FROM NEW."price"',
      );
    });
  });
}

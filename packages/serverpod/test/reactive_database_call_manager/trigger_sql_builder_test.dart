import 'package:serverpod/src/server/future_call_manager/trigger_sql_builder.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_database/src/adapters/postgres/value_encoder.dart';
import 'package:test/test.dart';

void main() {
  ValueEncoder.set(PostgresValueEncoder());

  group('Given a TriggerSqlBuilder with no condition', () {
    var builder = TriggerSqlBuilder(
      handlerName: 'notifyOnTripChange',
      tableName: 'trip',
    );

    test(
      'when building trigger SQL then trigger fires on INSERT OR UPDATE OR DELETE.',
      () {
        var sql = builder.buildTriggerSql();

        expect(sql, contains('AFTER INSERT OR UPDATE OR DELETE ON "trip"'));
      },
    );

    test('when building trigger SQL then no WHEN clause is present.', () {
      var sql = builder.buildTriggerSql();

      expect(sql, isNot(contains('WHEN')));
    });

    test(
      'when building function SQL then handler name is inserted into outbox.',
      () {
        var sql = builder.buildFunctionSql();

        expect(sql, contains("'notifyOnTripChange'"));
      },
    );

    test('when building function SQL then row data uses row_to_json.', () {
      var sql = builder.buildFunctionSql();

      expect(sql, contains('row_to_json(NEW.*)'));
      expect(sql, contains('row_to_json(OLD.*)'));
    });

    test(
      'when building trigger SQL then trigger name has correct prefix.',
      () {
        var sql = builder.buildTriggerSql();

        expect(
          sql,
          contains('"_serverpod_reactive_notifyOnTripChange"'),
        );
      },
    );

    test(
      'when building function SQL then function name has correct prefix.',
      () {
        var sql = builder.buildFunctionSql();

        expect(
          sql,
          contains('"_serverpod_reactive_notifyOnTripChange_fn"'),
        );
      },
    );
  });

  group('Given a TriggerSqlBuilder with an equals condition', () {
    var table = Table<int?>(tableName: 'trip');
    var column = ColumnString('status', table);
    var condition = column.equals('Confirmed');

    var builder = TriggerSqlBuilder(
      handlerName: 'notifyOnConfirmed',
      tableName: 'trip',
      condition: condition,
    );

    test('when building trigger SQL then WHEN clause uses NEW prefix.', () {
      var sql = builder.buildTriggerSql();

      expect(sql, contains("WHEN (NEW.\"status\" = 'Confirmed')"));
    });

    test(
      'when building trigger SQL then trigger fires on INSERT OR UPDATE OR DELETE.',
      () {
        var sql = builder.buildTriggerSql();

        expect(sql, contains('AFTER INSERT OR UPDATE OR DELETE ON "trip"'));
      },
    );
  });

  group('Given a TriggerSqlBuilder with a hasChanged condition', () {
    var table = Table<int?>(tableName: 'sensor');
    var column = ColumnDouble('sensorHeight', table);
    var condition = column.hasChanged();

    var builder = TriggerSqlBuilder(
      handlerName: 'onHeightChanged',
      tableName: 'sensor',
      condition: condition,
    );

    test('when building trigger SQL then trigger fires on UPDATE only.', () {
      var sql = builder.buildTriggerSql();

      expect(sql, contains('AFTER UPDATE ON "sensor"'));
      expect(sql, isNot(contains('INSERT')));
      expect(sql, isNot(contains('DELETE')));
    });

    test(
      'when building trigger SQL then WHEN clause has OLD IS DISTINCT FROM NEW.',
      () {
        var sql = builder.buildTriggerSql();

        expect(
          sql,
          contains(
            'WHEN (OLD."sensorHeight" IS DISTINCT FROM NEW."sensorHeight")',
          ),
        );
      },
    );
  });

  group(
    'Given a TriggerSqlBuilder with a combined hasChanged and equals condition',
    () {
      var table = Table<int?>(tableName: 'sensor');
      var heightColumn = ColumnDouble('sensorHeight', table);
      var tempColumn = ColumnDouble('sensorTemperature', table);
      var condition =
          heightColumn.hasChanged() &
          (tempColumn.hasChanged() | (tempColumn > 100.0));

      var builder = TriggerSqlBuilder(
        handlerName: 'onComplexChange',
        tableName: 'sensor',
        condition: condition,
      );

      test('when building trigger SQL then trigger fires on UPDATE only.', () {
        var sql = builder.buildTriggerSql();

        expect(sql, contains('AFTER UPDATE ON "sensor"'));
      });

      test(
        'when building trigger SQL then WHEN clause preserves expression structure.',
        () {
          var sql = builder.buildTriggerSql();

          expect(
            sql,
            contains(
              'WHEN ((OLD."sensorHeight" IS DISTINCT FROM NEW."sensorHeight" AND '
              '(OLD."sensorTemperature" IS DISTINCT FROM NEW."sensorTemperature" OR '
              'NEW."sensorTemperature" > 100.0)))',
            ),
          );
        },
      );
    },
  );

  group('Given TriggerSqlBuilder static methods', () {
    test('when building drop trigger SQL then output is correct.', () {
      var sql = TriggerSqlBuilder.buildDropTriggerSql(
        '_serverpod_reactive_myHandler',
        'my_table',
      );

      expect(
        sql,
        'DROP TRIGGER IF EXISTS "_serverpod_reactive_myHandler" ON "my_table";',
      );
    });

    test('when building drop function SQL then output is correct.', () {
      var sql = TriggerSqlBuilder.buildDropFunctionSql(
        '_serverpod_reactive_myHandler_fn',
      );

      expect(
        sql,
        'DROP FUNCTION IF EXISTS "_serverpod_reactive_myHandler_fn"();',
      );
    });
  });

  group('Given convertExpressionToWhenClause', () {
    test(
      'when converting a standard column expression then table name is replaced with NEW.',
      () {
        var table = Table<int?>(tableName: 'trip');
        var column = ColumnString('status', table);
        var condition = column.equals('Confirmed');

        var builder = TriggerSqlBuilder(
          handlerName: 'test',
          tableName: 'trip',
          condition: condition,
        );

        var result = builder.convertExpressionToWhenClause(condition);

        expect(result, "NEW.\"status\" = 'Confirmed'");
      },
    );

    test(
      'when converting a HasChangedExpression then output is unchanged.',
      () {
        var table = Table<int?>(tableName: 'sensor');
        var column = ColumnInt('value', table);
        var condition = column.hasChanged();

        var builder = TriggerSqlBuilder(
          handlerName: 'test',
          tableName: 'sensor',
          condition: condition,
        );

        var result = builder.convertExpressionToWhenClause(condition);

        expect(
          result,
          'OLD."value" IS DISTINCT FROM NEW."value"',
        );
      },
    );
  });
}

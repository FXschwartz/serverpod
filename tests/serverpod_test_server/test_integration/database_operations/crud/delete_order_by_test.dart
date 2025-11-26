import 'package:serverpod/database.dart';
import 'package:serverpod_test_server/src/generated/protocol.dart';
import 'package:serverpod_test_server/test_util/test_serverpod.dart';
import 'package:test/test.dart';

void main() async {
  var session = await IntegrationTestServer().session();

  group('Given a list of entries when deleting with orderBy', () {
    late List<SimpleData> data;

    setUp(() async {
      data = await SimpleData.db.insert(session, [
        SimpleData(num: 3),
        SimpleData(num: 1),
        SimpleData(num: 2),
      ]);
    });

    tearDown(() async {
      await SimpleData.db.deleteWhere(
        session,
        where: (_) => Constant.bool(true),
      );
    });

    test(
      'then deleted rows are returned in ascending order by default',
      () async {
        var deleteResult = await SimpleData.db.delete(
          session,
          data,
          orderBy: (t) => t.num,
        );

        expect(deleteResult, hasLength(3));
        var numbers = deleteResult.map((e) => e.num).toList();
        expect(numbers, [1, 2, 3]);
      },
    );

    test(
      'then deleted rows are returned in descending order when orderDescending is true',
      () async {
        var deleteResult = await SimpleData.db.delete(
          session,
          data,
          orderBy: (t) => t.num,
          orderDescending: true,
        );

        expect(deleteResult, hasLength(3));
        var numbers = deleteResult.map((e) => e.num).toList();
        expect(numbers, [3, 2, 1]);
      },
    );

    test(
      'then all rows are still deleted when no orderBy is specified',
      () async {
        var deleteResult = await SimpleData.db.delete(
          session,
          data,
        );

        expect(deleteResult, hasLength(3));

        // Verify all rows are deleted
        var remaining = await SimpleData.db.find(session);
        expect(remaining, isEmpty);
      },
    );

    test(
      'then deleted rows respect multi-column order when using orderByList',
      () async {
        // Clean up and insert data with multiple sortable fields
        await UniqueData.db.deleteWhere(
          session,
          where: (_) => Constant.bool(true),
        );
        var uniqueData = await UniqueData.db.insert(session, [
          UniqueData(number: 1, email: 'charlie@example.com'),
          UniqueData(number: 2, email: 'alice@example.com'),
          UniqueData(number: 1, email: 'bob@example.com'),
        ]);

        var deleteResult = await UniqueData.db.delete(
          session,
          uniqueData,
          orderByList: (t) => [
            Order(column: t.number),
            Order(column: t.email),
          ],
        );

        expect(deleteResult, hasLength(3));
        var emails = deleteResult.map((e) => e.email).toList();
        // number=1 first (bob, charlie sorted by email), then number=2 (alice)
        expect(emails, [
          'bob@example.com',
          'charlie@example.com',
          'alice@example.com',
        ]);
      },
    );
  });
}

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
      await SimpleData.db
          .deleteWhere(session, where: (_) => Constant.bool(true));
    });

    test(
      'then deleted rows are returned in ascending order by default',
      () async {
        var deleteResult = await SimpleData.db.deleteWhere(
          session,
          where: (t) => Constant.bool(true),
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
        var deleteResult = await SimpleData.db.deleteWhere(
          session,
          where: (t) => Constant.bool(true),
          orderBy: (t) => t.num,
          orderDescending: true,
        );

        expect(deleteResult, hasLength(3));
        var numbers = deleteResult.map((e) => e.num).toList();
        expect(numbers, [3, 2, 1]);
      },
    );

    test(
      'then deleted rows are returned in id order when ordering by id',
      () async {
        var deleteResult = await SimpleData.db.deleteWhere(
          session,
          where: (t) => Constant.bool(true),
          orderBy: (t) => t.id,
        );

        expect(deleteResult, hasLength(3));
        var ids = deleteResult.map((e) => e.id).toList();
        expect(ids, [data[0].id, data[1].id, data[2].id]);
      },
    );

    test(
      'then only matching rows are deleted and returned in order when using filter',
      () async {
        var deleteResult = await SimpleData.db.deleteWhere(
          session,
          where: (t) => t.num.notEquals(2),
          orderBy: (t) => t.num,
        );

        expect(deleteResult, hasLength(2));
        var numbers = deleteResult.map((e) => e.num).toList();
        expect(numbers, [1, 3]);

        // Verify the remaining row
        var remaining = await SimpleData.db.find(session);
        expect(remaining, hasLength(1));
        expect(remaining.first.num, 2);
      },
    );

    test(
      'then all matching rows are still deleted when no orderBy is specified',
      () async {
        var deleteResult = await SimpleData.db.deleteWhere(
          session,
          where: (t) => Constant.bool(true),
        );

        expect(deleteResult, hasLength(3));

        // Verify all rows are deleted
        var remaining = await SimpleData.db.find(session);
        expect(remaining, isEmpty);
      },
    );

    test(
      'then an empty list is returned when no rows match',
      () async {
        var result = await SimpleData.db.deleteWhere(
          session,
          where: (t) => t.num.equals(999),
          orderBy: (t) => t.num,
        );

        expect(result, isEmpty);
      },
    );
  });
}

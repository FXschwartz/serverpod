import 'package:serverpod/database.dart';
import 'package:serverpod_test_server/src/generated/protocol.dart';
import 'package:serverpod_test_server/test_util/test_serverpod.dart';
import 'package:test/test.dart';

void main() async {
  var session = await IntegrationTestServer().session();

  group('Given entries with multiple sortable fields when deleting with orderByList', () {
    late List<UniqueData> data;

    setUp(() async {
      data = await UniqueData.db.insert(session, [
        UniqueData(number: 1, email: 'charlie@example.com'),
        UniqueData(number: 2, email: 'alice@example.com'),
        UniqueData(number: 1, email: 'bob@example.com'),
      ]);
    });

    tearDown(() async {
      await UniqueData.db
          .deleteWhere(session, where: (_) => Constant.bool(true));
    });

    test(
      'then deleted rows are returned in multi-column order',
      () async {
        var deleteResult = await UniqueData.db.deleteWhere(
          session,
          where: (t) => Constant.bool(true),
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

    test(
      'then deleted rows respect each column direction when using mixed directions',
      () async {
        var deleteResult = await UniqueData.db.deleteWhere(
          session,
          where: (t) => Constant.bool(true),
          orderByList: (t) => [
            Order(column: t.number, orderDescending: true),
            Order(column: t.email),
          ],
        );

        expect(deleteResult, hasLength(3));
        var emails = deleteResult.map((e) => e.email).toList();
        // number=2 first (alice), then number=1 (bob, charlie sorted by email asc)
        expect(emails, [
          'alice@example.com',
          'bob@example.com',
          'charlie@example.com',
        ]);
      },
    );
  });
}

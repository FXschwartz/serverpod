import 'package:serverpod/serverpod.dart';
import 'package:serverpod_test_server/src/generated/protocol.dart';

class SimpleDataReactiveCall extends ReactiveFutureCall<SimpleData> {
  @override
  String get watchTable => 'simple_data';

  @override
  Future<void> react(
    Session session,
    List<ReactiveEvent<SimpleData>> events,
  ) async {
    for (final event in events) {
      session.log(
        'SimpleData ${event.row.num} was ${event.operation}',
      );
    }
  }
}

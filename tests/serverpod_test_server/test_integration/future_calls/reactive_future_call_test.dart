import 'dart:async';

import 'package:serverpod/protocol.dart' show ReactiveDatabaseCallEntry;
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_test_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';
import '../utils/future_call_manager_builder.dart';

class TestReactiveCall extends ReactiveFutureCall<SimpleData> {
  final Completer<List<ReactiveEvent<SimpleData>>> completer =
      Completer<List<ReactiveEvent<SimpleData>>>();

  @override
  String get watchTable => 'simple_data';

  @override
  Future<void> react(
    Session session,
    List<ReactiveEvent<SimpleData>> events,
  ) async {
    completer.complete(events);
  }
}

class CounterReactiveCall extends ReactiveFutureCall<SimpleData> {
  int callCount = 0;
  List<ReactiveEvent<SimpleData>> lastEvents = [];

  @override
  String get watchTable => 'simple_data';

  @override
  Future<void> react(
    Session session,
    List<ReactiveEvent<SimpleData>> events,
  ) async {
    callCount++;
    lastEvents = events;
  }
}

void main() async {
  withServerpod(
    'Given FutureCallManager with a registered ReactiveFutureCall',
    (sessionBuilder, _) {
      late FutureCallManager futureCallManager;
      late TestReactiveCall testReactiveCall;
      late Session session;
      var reactiveCallName = 'TestReactiveCall';

      setUp(() async {
        session = sessionBuilder.build();

        futureCallManager = FutureCallManagerBuilder.fromTestSessionBuilder(
          sessionBuilder,
        ).build();

        testReactiveCall = TestReactiveCall();
        futureCallManager.registerFutureCall(
          testReactiveCall,
          reactiveCallName,
        );
      });

      group(
        'when an outbox event is inserted and scanning runs',
        () {
          setUp(() async {
            // Simulate a trigger inserting an outbox event.
            await ReactiveDatabaseCallEntry.db.insertRow(
              session,
              ReactiveDatabaseCallEntry(
                futureCallName: reactiveCallName,
                sourceTable: 'simple_data',
                operation: 'INSERT',
                rowData: '{"num": 42}',
                createdAt: DateTime.now().toUtc(),
              ),
            );

            // Run the reactive outbox scanner to claim the event.
            // ignore: invalid_use_of_visible_for_testing_member
            await futureCallManager.scanner.scanReactiveOutbox();

            // Run the future call scanner + execution.
            await futureCallManager.runScheduledFutureCalls();
          });

          test(
            'then react is called with the correct event',
            () async {
              final events = await testReactiveCall.completer.future.timeout(
                Duration(seconds: 5),
              );

              expect(events, hasLength(1));
              expect(events.first.operation, 'INSERT');
              expect(events.first.row.num, 42);
            },
          );

          test(
            'then the outbox events are cleaned up via cascade delete',
            () async {
              await testReactiveCall.completer.future.timeout(
                Duration(seconds: 5),
              );

              final remainingOutbox = await ReactiveDatabaseCallEntry.db.find(
                session,
                where: (t) => t.futureCallName.equals(reactiveCallName),
              );

              expect(remainingOutbox, isEmpty);
            },
          );
        },
      );
    },
  );

  withServerpod(
    'Given FutureCallManager with a registered ReactiveFutureCall'
    ' and multiple outbox events',
    (sessionBuilder, _) {
      late FutureCallManager futureCallManager;
      late CounterReactiveCall counterCall;
      late Session session;
      var reactiveCallName = 'CounterReactiveCall';

      setUp(() async {
        session = sessionBuilder.build();

        futureCallManager = FutureCallManagerBuilder.fromTestSessionBuilder(
          sessionBuilder,
        ).build();

        counterCall = CounterReactiveCall();
        futureCallManager.registerFutureCall(
          counterCall,
          reactiveCallName,
        );
      });

      group(
        'when multiple outbox events exist and scanning runs',
        () {
          setUp(() async {
            // Simulate multiple trigger events.
            for (var i = 0; i < 3; i++) {
              await ReactiveDatabaseCallEntry.db.insertRow(
                session,
                ReactiveDatabaseCallEntry(
                  futureCallName: reactiveCallName,
                  sourceTable: 'simple_data',
                  operation: 'INSERT',
                  rowData: '{"num": $i}',
                  createdAt: DateTime.now().toUtc(),
                ),
              );
            }

            // ignore: invalid_use_of_visible_for_testing_member
            await futureCallManager.scanner.scanReactiveOutbox();
            await futureCallManager.runScheduledFutureCalls();
          });

          test(
            'then react is called once with all events batched',
            () async {
              expect(counterCall.callCount, 1);
              expect(counterCall.lastEvents, hasLength(3));
            },
          );
        },
      );
    },
  );
}

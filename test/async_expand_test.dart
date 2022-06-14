// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:stream_transform/stream_transform.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test('forwards errors from the convert callback', () async {
    var errors = <String>[];
    var source = Stream.fromIterable([1, 2, 3]);
    source.concurrentAsyncExpand((i) {
      // ignore: only_throw_errors
      throw 'Error: $i';
    }).listen((_) {}, onError: errors.add);
    await Future<void>(() {});
    expect(errors, ['Error: 1', 'Error: 2', 'Error: 3']);
  });

  for (var outerType in streamTypes) {
    for (var innerType in streamTypes) {
      group('concurrentAsyncExpand $outerType to $innerType', () {
        late StreamController<StreamController<String>> outerController;
        late bool outerCanceled;
        late List<String> emittedValues;
        late bool isDone;
        late List<String> errors;
        late Stream<String> transformed;
        late StreamSubscription<String> subscription;

        void listen() {
          subscription = transformed
              .listen(emittedValues.add, onError: errors.add, onDone: () {
            isDone = true;
          });
        }

        setUp(() {
          outerController = createController(outerType)
            ..onCancel = () {
              outerCanceled = true;
            };
          outerCanceled = false;
          emittedValues = [];
          errors = [];
          isDone = false;
          transformed = outerController.stream
              .concurrentAsyncExpand((controller) => controller.stream);
        });

        test('interleaves events from sub streams', () async {
          listen();
          final first = createController<String>(innerType);
          final second = createController<String>(innerType);
          outerController
            ..add(first)
            ..add(second);
          await Future<void>(() {});
          expect(emittedValues, isEmpty);
          first.add('First');
          second.add('Second');
          first.add('First again');
          await Future<void>(() {});
          expect(emittedValues, ['First', 'Second', 'First again']);
        });

        test('forwards errors from outer stream', () async {
          listen();
          outerController.addError('Error');
          await Future<void>(() {});
          expect(errors, ['Error']);
        });

        test('forwards errors from inner streams', () async {
          listen();
          final first = createController<String>(innerType);
          final second = createController<String>(innerType);
          outerController
            ..add(first)
            ..add(second);
          await Future<void>(() {});
          first.addError('Error 1');
          second.addError('Error 2');
          await Future<void>(() {});
          expect(errors, ['Error 1', 'Error 2']);
        });

        test('can continue handling events after an error in outer stream',
            () async {
          listen();
          final controller = createController<String>(innerType);
          outerController
            ..addError('Error')
            ..add(controller);
          await Future<void>(() {});
          controller.add('First');
          await Future<void>(() {});
          expect(emittedValues, ['First']);
          expect(errors, ['Error']);
        });

        if (outerType != 'broadcast') {
          test('cancels outer subscription if output canceled', () async {
            listen();
            await subscription.cancel();
            expect(outerCanceled, true);
          });
        } else {
          test('does not cancel outer subscription', () async {
            listen();
            await subscription.cancel();
            expect(outerCanceled, false);
          });
        }

        if (outerType != 'broadcast' || innerType != 'single subscription') {
          // A single subscription inner stream in a broadcast outer stream is
          // not canceled.
          test('cancels inner subscriptions if output canceled', () async {
            listen();
            var firstCanceled = false;
            var secondCanceled = false;
            final first = createController<String>(innerType)
              ..onCancel = () {
                firstCanceled = true;
              };
            final second = createController<String>(innerType)
              ..onCancel = () {
                secondCanceled = true;
              };
            outerController
              ..add(first)
              ..add(second);
            await Future<void>(() {});
            await subscription.cancel();
            expect(firstCanceled, true);
            expect(secondCanceled, true);
          });
        }

        test('stays open if any inner stream is still open', () async {
          listen();
          final controller = createController<String>(innerType);
          outerController.add(controller);
          await outerController.close();
          await Future<void>(() {});
          expect(isDone, false);
        });

        test('stays open if outer stream is still open', () async {
          listen();
          final controller = createController<String>(innerType);
          outerController.add(controller);
          await Future<void>(() {});
          await controller.close();
          await Future<void>(() {});
          expect(isDone, false);
        });

        test('closes after all inner streams and outer stream close', () async {
          listen();
          final controller = createController<String>(innerType);
          outerController.add(controller);
          await Future<void>(() {});
          await controller.close();
          await outerController.close();
          await Future<void>(() {});
          expect(isDone, true);
        });

        if (outerType == 'broadcast') {
          test('multiple listeners all get values', () async {
            listen();
            var otherValues = <String>[];
            transformed.listen(otherValues.add);
            final controller = createController<String>(innerType);
            outerController.add(controller);
            await Future<void>(() {});
            controller.add('First');
            await Future<void>(() {});
            expect(emittedValues, ['First']);
            expect(otherValues, ['First']);
          });

          test('multiple listeners get closed', () async {
            listen();
            var otherDone = false;
            transformed.listen(null, onDone: () => otherDone = true);
            final controller = createController<String>(innerType);
            outerController.add(controller);
            await Future<void>(() {});
            await controller.close();
            await outerController.close();
            await Future<void>(() {});
            expect(isDone, true);
            expect(otherDone, true);
          });

          test('can cancel and relisten', () async {
            listen();
            final first = createController<String>(innerType);
            final second = createController<String>(innerType);
            outerController
              ..add(first)
              ..add(second);
            await Future(() {});
            first.add('First');
            second.add('Second');
            await Future(() {});
            await subscription.cancel();
            first.add('Ignored');
            await Future(() {});

            subscription = transformed.listen(emittedValues.add);
            first.add('From prior stream');
            final third = createController<String>(innerType);
            outerController.add(third);
            await Future(() {});
            third.add('From new stream');
            await Future(() {});
            expect(emittedValues,
                ['First', 'Second', 'From prior stream', 'From new stream']);
          });

          test('eagerly listens to the source stream', () async {
            final first = createController<String>(innerType);
            outerController.add(first);
            first.add('Sent before listen');
            await Future<void>(() {});

            listen();
            await Future<void>(() {});
            expect(emittedValues, isEmpty);

            final second = createController<String>(innerType);
            outerController.add(second);
            await Future<void>(() {});
            first.add('First');
            second.add('Second');
            await Future<void>(() {});

            expect(emittedValues, ['First', 'Second']);
          });

          test(
              'continues to listen to the source stream while there are no '
              'listeners on the result stream', () async {
            listen();
            final first = createController<String>(innerType);
            outerController.add(first);
            await Future<void>(() {});
            first.add('First');
            await Future<void>(() {});
            await subscription.cancel();

            final second = createController<String>(innerType);
            outerController.add(second);
            await Future<void>(() {});

            first.add('First during no listener');
            second.add('Second during no listener');
            await Future<void>(() {});

            final laterEmittedValues = <String>[];
            transformed.listen(laterEmittedValues.add);

            first.add('First again');
            second.add('Second');

            final third = createController<String>(innerType);
            outerController.add(third);
            await Future<void>(() {});
            third.add('Third');
            await Future<void>(() {});

            expect(emittedValues, ['First']);
            expect(laterEmittedValues, ['First again', 'Second', 'Third']);
          });
        }
      });
    }
  }
}

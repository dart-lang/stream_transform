// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';
import 'package:stream_transform/stream_transform.dart';

import 'utils.dart';

void main() {
  for (var streamType in streamTypes) {
    group('Stream type [$streamType]', () {
      StreamController<int> values;
      List<int> emittedValues;
      bool valuesCanceled;
      bool isDone;
      Stream<int> transformed;
      StreamSubscription<int> subscription;

      group('throttle', () {
        setUp(() async {
          valuesCanceled = false;
          values = createController(streamType)
            ..onCancel = () {
              valuesCanceled = true;
            };
          emittedValues = [];
          isDone = false;
          transformed = values.stream.throttle(const Duration(milliseconds: 5));
          subscription = transformed.listen(emittedValues.add, onDone: () {
            isDone = true;
          });
        });

        test('cancels values', () async {
          await subscription.cancel();
          expect(valuesCanceled, true);
        });

        test('swallows values that come faster than duration', () async {
          values..add(1)..add(2);
          await values.close();
          await waitForTimer(5);
          expect(emittedValues, [1]);
        });

        test('outputs multiple values spaced further than duration', () async {
          values.add(1);
          await waitForTimer(5);
          values.add(2);
          await waitForTimer(5);
          expect(emittedValues, [1, 2]);
        });

        test('closes output immediately', () async {
          values.add(1);
          await waitForTimer(5);
          values.add(2);
          await values.close();
          expect(isDone, true);
        });

        if (streamType == 'broadcast') {
          test('multiple listeners all get values', () async {
            var otherValues = [];
            transformed.listen(otherValues.add);
            values.add(1);
            await Future(() {});
            expect(emittedValues, [1]);
            expect(otherValues, [1]);
          });
        }
      });

      group('throttle - trailingCall', () {
        setUp(() async {
          valuesCanceled = false;
          values = createController(streamType)
            ..onCancel = () {
              valuesCanceled = true;
            };
          emittedValues = [];
          isDone = false;
          transformed = values.stream
              .throttle(const Duration(milliseconds: 5), trailingCall: true);
          subscription = transformed.listen(emittedValues.add, onDone: () {
            isDone = true;
          });
        });

        test('cancels values', () async {
          await subscription.cancel();
          expect(valuesCanceled, true);
        });

        test('swallows values that come faster than duration', () async {
          values..add(1)..add(2);
          await values.close();
          await waitForTimer(5);
          expect(emittedValues, [1]);
        });

        test('outputs multiple values spaced further than duration', () async {
          values.add(1);
          await waitForTimer(5);
          values.add(2);
          await waitForTimer(5);
          expect(emittedValues, [1, 2]);
        });

        test('closes output immediately', () async {
          values.add(1);
          await waitForTimer(5);
          values.add(2);
          await values.close();
          expect(isDone, true);
        });

        if (streamType == 'broadcast') {
          test('multiple listeners all get values', () async {
            var otherValues = [];
            transformed.listen(otherValues.add);
            values.add(1);
            await Future(() {});
            expect(emittedValues, [1]);
            expect(otherValues, [1]);
          });
        }

        test('trailingCall is fired with latest value', () async {
          values..add(1)..add(2)..add(3);
          await waitForTimer(5);

          await values.close();
          expect(emittedValues, [1, 3]);
        });

        test('add values during trailingCall', () async {
          values..add(1)..add(2)..add(3);
          await waitForTimer(5);

          values..add(4)..add(5);
          await waitForTimer(5);

          await values.close();
          expect(emittedValues, [1, 3, 5]);
        });

        test(
            'add values during trailingCall and close stream before next trailingCall fires',
            () async {
          values..add(1)..add(2)..add(3);
          await waitForTimer(5);

          values..add(4)..add(5);
          await values.close();
          await waitForTimer(5);

          expect(emittedValues, [1, 3]);
        });
      });

      group('throttle - trailingCall with trailing', () {
        setUp(() async {
          valuesCanceled = false;
          values = createController(streamType)
            ..onCancel = () {
              valuesCanceled = true;
            };
          emittedValues = [];
          isDone = false;
          transformed = values.stream.throttle(const Duration(milliseconds: 5),
              trailingCall: true, trailing: true);
          subscription = transformed.listen(emittedValues.add, onDone: () {
            isDone = true;
          });
        });

        test('cancels values', () async {
          await subscription.cancel();
          expect(valuesCanceled, true);
        });

        test('not swallows latest value that come faster than duration',
            () async {
          values..add(1)..add(2)..add(3);
          await values.close();
          await waitForTimer(5);
          expect(emittedValues, [1, 3]);
        });

        test('outputs multiple values spaced further than duration', () async {
          values.add(1);
          await waitForTimer(5);
          values.add(2);
          await waitForTimer(5);
          expect(emittedValues, [1, 2]);
        });

        test('closes output immediately', () async {
          values..add(1)..add(2);
          await values.close();
          expect(isDone, false);
        });

        if (streamType == 'broadcast') {
          test('multiple listeners all get values', () async {
            var otherValues = [];
            transformed.listen(otherValues.add);
            values.add(1);
            await Future(() {});
            expect(emittedValues, [1]);
            expect(otherValues, [1]);
          });
        }

        test('trailingCall is fired with latest value', () async {
          values..add(1)..add(2)..add(3);
          await waitForTimer(5);

          await values.close();
          expect(emittedValues, [1, 3]);
        });

        test('add values during trailingCall', () async {
          values..add(1)..add(2)..add(3);
          await waitForTimer(5);

          values..add(4)..add(5);
          await waitForTimer(5);

          await values.close();
          expect(emittedValues, [1, 3, 5]);
        });

        test(
            'add values during trailingCall and close stream during next trailingCall fires',
            () async {
          values..add(1)..add(2)..add(3);
          await waitForTimer(5);

          values..add(4)..add(5);
          await values.close();
          await waitForTimer(5);

          expect(emittedValues, [1, 3, 5]);
        });
      });
    });
  }
}

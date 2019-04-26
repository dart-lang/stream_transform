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
      group('debounce', () {
        StreamController<int> values;
        List<int> emittedValues;
        bool valuesCanceled;
        bool isDone;
        List<String> errors;
        StreamSubscription<int> subscription;
        Stream<int> transformed;

        void setUpStreams(StreamTransformer<int, int> transformer) {
          valuesCanceled = false;
          values = createController(streamType)
            ..onCancel = () {
              valuesCanceled = true;
            };
          emittedValues = [];
          errors = [];
          isDone = false;
          transformed = values.stream.transform(transformer);
          subscription = transformed
              .listen(emittedValues.add, onError: errors.add, onDone: () {
            isDone = true;
          });
        }

        setUp(() async {
          setUpStreams(debounce(const Duration(milliseconds: 5)));
        });

        test('cancels values', () async {
          await subscription.cancel();
          expect(valuesCanceled, true);
        });

        test('swallows values that come faster than duration', () async {
          values..add(1)..add(2);
          await values.close();
          await waitForTimer(5);
          expect(emittedValues, [2]);
        });

        test('outputs multiple values spaced further than duration', () async {
          values.add(1);
          await waitForTimer(5);
          values.add(2);
          await waitForTimer(5);
          expect(emittedValues, [1, 2]);
        });

        test('waits for pending value to close', () async {
          values.add(1);
          await waitForTimer(5);
          await values.close();
          await Future(() {});
          expect(isDone, true);
        });

        test('closes output if there are no pending values', () async {
          values.add(1);
          await waitForTimer(5);
          values.add(2);
          await Future(() {});
          await values.close();
          expect(isDone, false);
          await waitForTimer(5);
          expect(isDone, true);
        });

        if (streamType == 'broadcast') {
          test('multiple listeners all get values', () async {
            var otherValues = [];
            transformed.listen(otherValues.add);
            values..add(1)..add(2);
            await waitForTimer(5);
            expect(emittedValues, [2]);
            expect(otherValues, [2]);
          });
        }
      });

      group('debounceBuffer', () {
        StreamController<int> values;
        List<List<int>> emittedValues;
        List<String> errors;
        Stream<List<int>> transformed;

        setUp(() async {
          values = createController(streamType);
          emittedValues = [];
          errors = [];
          transformed = values.stream
              .transform(debounceBuffer(const Duration(milliseconds: 5)))
                ..listen(emittedValues.add, onError: errors.add);
        });

        test('Emits all values as a list', () async {
          values..add(1)..add(2);
          await values.close();
          await waitForTimer(5);
          expect(emittedValues, [
            [1, 2]
          ]);
        });

        test('separate lists for multiple values spaced further than duration',
            () async {
          values.add(1);
          await waitForTimer(5);
          values.add(2);
          await waitForTimer(5);
          expect(emittedValues, [
            [1],
            [2]
          ]);
        });

        if (streamType == 'broadcast') {
          test('multiple listeners all get values', () async {
            var otherValues = [];
            transformed.listen(otherValues.add);
            values..add(1)..add(2);
            await waitForTimer(5);
            expect(emittedValues, [
              [1, 2]
            ]);
            expect(otherValues, [
              [1, 2]
            ]);
          });
        }
      });
    });
  }
}

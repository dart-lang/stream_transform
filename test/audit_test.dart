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
      List<String> errors;
      Stream<int> transformed;
      StreamSubscription<int> subscription;

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

      group('audit', () {
        setUp(() async {
          setUpStreams(audit(const Duration(milliseconds: 5)));
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
          await values.close();
          expect(isDone, false);
          await waitForTimer(5);
          expect(isDone, true);
        });

        test('closes output if there are no pending values', () async {
          values.add(1);
          await waitForTimer(5);
          values.add(2);
          await values.close();
          expect(isDone, false);
          await waitForTimer(5);
          expect(isDone, true);
        });

        test('does not starve output if many values come closer than duration',
            () async {
          values.add(1);
          await Future.delayed(const Duration(milliseconds: 3));
          values.add(2);
          await Future.delayed(const Duration(milliseconds: 3));
          values.add(3);
          await waitForTimer(5);
          expect(emittedValues, [2, 3]);
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
    });
  }
}

// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:stream_transform/stream_transform.dart';

import 'utils.dart';

void main() {
  for (var streamType in streamTypes) {
    group('distinctWhen on Stream type [$streamType]', () {
      StreamController<int> values;
      List<int> emittedValues;
      bool valuesCanceled;
      bool isDone;
      List<String> errors;
      Stream<int> transformed;
      StreamSubscription<int> subscription;
      DistinctWhenCondition<int> condition;

      setUp(() {
        valuesCanceled = false;
        values = createController(streamType)
          ..onCancel = () {
            valuesCanceled = true;
          };
        emittedValues = [];
        errors = [];
        isDone = false;
        condition = (int value) => value % 2 == 0;
        transformed = values.stream.transform(distinctWhen(condition));
        subscription = transformed.listen(
          emittedValues.add,
          onError: errors.add,
          onDone: () {
            isDone = true;
          },
        );
      });

      test('forwards cancellation', () async {
        await subscription.cancel();
        expect(valuesCanceled, true);
      });

      test('filters values', () async {
        values..add(1)..add(2)..add(2)..add(3)..add(3);
        await Future(() {});
        expect(emittedValues, [1, 2, 3, 3]);
      });

      test('forwards errors', () async {
        values.addError('error');
        await Future(() {});
        expect(errors, ['error']);
      });

      test('sends done if original strem ends', () async {
        await values.close();
        expect(isDone, true);
      });

      if (streamType == 'broadcast') {
        test('multiple listeners all get values', () async {
          var otherValues = [];
          transformed.listen(otherValues.add);
          values..add(1)..add(2)..add(2)..add(3)..add(3);
          await Future(() {});
          expect(emittedValues, [1, 2, 3, 3]);
          expect(otherValues, [1, 2, 3, 3]);
        });

        test('multiple listeners get done when values end', () async {
          var otherDone = false;
          transformed.listen(null, onDone: () => otherDone = true);
          await values.close();
          expect(otherDone, true);
          expect(isDone, true);
        });
      }
    });
  }
}

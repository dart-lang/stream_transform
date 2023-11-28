// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  for (var streamType in streamTypes) {
    group('Stream type [$streamType]', () {
      group('debounce - trailing', () {
        late StreamController<int> values;
        late List<int> emittedValues;
        late bool valuesCanceled;
        late bool isDone;
        late List<String> errors;
        late StreamSubscription<int> subscription;
        late Stream<int> transformed;

        setUp(() async {
          valuesCanceled = false;
          values = createController(streamType)
            ..onCancel = () {
              valuesCanceled = true;
            };
          emittedValues = [];
          errors = [];
          isDone = false;
          transformed = values.stream.debounce(const Duration(milliseconds: 5));
        });

        void listen() {
          subscription = transformed
              .listen(emittedValues.add, onError: errors.add, onDone: () {
            isDone = true;
          });
        }

        test('cancels values', () async {
          listen();
          await subscription.cancel();
          expect(valuesCanceled, true);
        });

        test('swallows values that come faster than duration', () {
          fakeAsync((async) {
            listen();
            values
              ..add(1)
              ..add(2)
              ..close();
            async.elapse(const Duration(milliseconds: 6));
            expect(emittedValues, [2]);
          });
        });

        test('outputs multiple values spaced further than duration', () {
          fakeAsync((async) {
            listen();
            values.add(1);
            async.elapse(const Duration(milliseconds: 6));
            values.add(2);
            async.elapse(const Duration(milliseconds: 6));
            expect(emittedValues, [1, 2]);
          });
        });

        test('waits for pending value to close', () {
          fakeAsync((async) {
            listen();
            values.add(1);
            async.elapse(const Duration(milliseconds: 6));
            values.close();
            async.flushMicrotasks();
            expect(isDone, true);
          });
        });

        test('closes output if there are no pending values', () {
          fakeAsync((async) {
            listen();
            values.add(1);
            async.elapse(const Duration(milliseconds: 6));
            values
              ..add(2)
              ..close();
            async.flushMicrotasks();
            expect(isDone, false);
            async.elapse(const Duration(milliseconds: 6));
            expect(isDone, true);
          });
        });

        if (streamType == 'broadcast') {
          test('multiple listeners all get values', () {
            fakeAsync((async) {
              listen();
              var otherValues = <int>[];
              transformed.listen(otherValues.add);
              values
                ..add(1)
                ..add(2);
              async.elapse(const Duration(milliseconds: 6));
              expect(emittedValues, [2]);
              expect(otherValues, [2]);
            });
          });
        }
      });

      group('debounce - leading', () {
        late StreamController<int> values;
        late List<int> emittedValues;
        late Stream<int> transformed;
        late bool isDone;

        setUp(() async {
          values = createController(streamType);
          emittedValues = [];
          isDone = false;
          transformed = values.stream.debounce(const Duration(milliseconds: 5),
              leading: true, trailing: false);
        });

        void listen() {
          transformed.listen(emittedValues.add, onDone: () {
            isDone = true;
          });
        }

        test('swallows values that come faster than duration', () async {
          listen();
          values
            ..add(1)
            ..add(2);
          await values.close();
          expect(emittedValues, [1]);
        });

        test('outputs multiple values spaced further than duration', () {
          fakeAsync((async) {
            listen();
            values.add(1);
            async.elapse(const Duration(milliseconds: 6));
            values.add(2);
            async.elapse(const Duration(milliseconds: 6));
            expect(emittedValues, [1, 2]);
          });
        });

        if (streamType == 'broadcast') {
          test('multiple listeners all get values', () {
            fakeAsync((async) {
              listen();
              var otherValues = <int>[];
              transformed.listen(otherValues.add);
              values
                ..add(1)
                ..add(2);
              async.elapse(const Duration(milliseconds: 6));
              expect(emittedValues, [1]);
              expect(otherValues, [1]);
            });
          });
        }

        test('closes output immediately if not waiting for trailing value',
            () async {
          listen();
          values.add(1);
          await values.close();
          expect(isDone, true);
        });
      });

      group('debounce - leading and trailing', () {
        late StreamController<int> values;
        late List<int> emittedValues;
        late Stream<int> transformed;

        setUp(() async {
          values = createController(streamType);
          emittedValues = [];
          transformed = values.stream.debounce(const Duration(milliseconds: 5),
              leading: true, trailing: true);
        });
        void listen() {
          transformed.listen(emittedValues.add);
        }

        test('swallows values that come faster than duration', () {
          fakeAsync((async) {
            listen();
            values
              ..add(1)
              ..add(2)
              ..add(3)
              ..close();
            async.elapse(const Duration(milliseconds: 6));
            expect(emittedValues, [1, 3]);
          });
        });

        test('outputs multiple values spaced further than duration', () {
          fakeAsync((async) {
            listen();
            values.add(1);
            async.elapse(const Duration(milliseconds: 6));
            values.add(2);
            async.elapse(const Duration(milliseconds: 6));
            expect(emittedValues, [1, 2]);
          });
        });

        if (streamType == 'broadcast') {
          test('multiple listeners all get values', () {
            fakeAsync((async) {
              listen();
              var otherValues = <int>[];
              transformed.listen(otherValues.add);
              values
                ..add(1)
                ..add(2);
              async.elapse(const Duration(milliseconds: 6));
              expect(emittedValues, [1, 2]);
              expect(otherValues, [1, 2]);
            });
          });
        }
      });

      group('debounceBuffer', () {
        late StreamController<int> values;
        late List<List<int>> emittedValues;
        late List<String> errors;
        late Stream<List<int>> transformed;

        setUp(() async {
          values = createController(streamType);
          emittedValues = [];
          errors = [];
          transformed =
              values.stream.debounceBuffer(const Duration(milliseconds: 5));
        });
        void listen() {
          transformed.listen(emittedValues.add, onError: errors.add);
        }

        test('Emits all values as a list', () {
          fakeAsync((async) {
            listen();
            values
              ..add(1)
              ..add(2)
              ..close();
            async.elapse(const Duration(milliseconds: 6));
            expect(emittedValues, [
              [1, 2]
            ]);
          });
        });

        test('separate lists for multiple values spaced further than duration',
            () {
          fakeAsync((async) {
            listen();
            values.add(1);
            async.elapse(const Duration(milliseconds: 6));
            values.add(2);
            async.elapse(const Duration(milliseconds: 6));
            expect(emittedValues, [
              [1],
              [2]
            ]);
          });
        });

        if (streamType == 'broadcast') {
          test('multiple listeners all get values', () {
            fakeAsync((async) {
              listen();
              var otherValues = <List<int>>[];
              transformed.listen(otherValues.add);
              values
                ..add(1)
                ..add(2);
              async.elapse(const Duration(milliseconds: 6));
              expect(emittedValues, [
                [1, 2]
              ]);
              expect(otherValues, [
                [1, 2]
              ]);
            });
          });
        }
      });
    });
  }
  test('allows nulls', () async {
    final values = Stream<int?>.fromIterable([null]);
    final transformed = values.debounce(const Duration(milliseconds: 1));
    expect(await transformed.toList(), [null]);
  });
}

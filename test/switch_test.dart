// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:stream_transform/stream_transform.dart';

import 'utils.dart';

void main() {
  for (var outerType in streamTypes) {
    for (var innerType in streamTypes) {
      group('Outer type: [$outerType], Inner type: [$innerType]', () {
        StreamController<int> first;
        StreamController<int> second;
        StreamController<Stream<int>> outer;

        List<int> emittedValues;
        bool firstCanceled;
        bool outerCanceled;
        bool isDone;
        List<String> errors;
        StreamSubscription<int> subscription;

        setUp(() async {
          firstCanceled = false;
          outerCanceled = false;
          outer = createController(outerType)
            ..onCancel = () {
              outerCanceled = true;
            };
          first = createController(innerType)
            ..onCancel = () {
              firstCanceled = true;
            };
          second = createController(innerType);
          emittedValues = [];
          errors = [];
          isDone = false;
          subscription = outer.stream
              .transform(switchLatest())
              .listen(emittedValues.add, onError: errors.add, onDone: () {
            isDone = true;
          });
        });

        test('forwards events', () async {
          outer.add(first.stream);
          await Future(() {});
          first..add(1)..add(2);
          await Future(() {});

          outer.add(second.stream);
          await Future(() {});
          second..add(3)..add(4);
          await Future(() {});

          expect(emittedValues, [1, 2, 3, 4]);
        });

        test('forwards errors from outer Stream', () async {
          outer.addError('error');
          await Future(() {});
          expect(errors, ['error']);
        });

        test('forwards errors from inner Stream', () async {
          outer.add(first.stream);
          await Future(() {});
          first.addError('error');
          await Future(() {});
          expect(errors, ['error']);
        });

        test('closes when final stream is done', () async {
          outer.add(first.stream);
          await Future(() {});

          outer.add(second.stream);
          await Future(() {});

          await outer.close();
          expect(isDone, false);

          await second.close();
          expect(isDone, true);
        });

        test(
            'closes when outer stream closes if latest inner stream already '
            'closed', () async {
          outer.add(first.stream);
          await Future(() {});
          await first.close();
          expect(isDone, false);

          await outer.close();
          expect(isDone, true);
        });

        test('cancels listeners on previous streams', () async {
          outer.add(first.stream);
          await Future(() {});

          outer.add(second.stream);
          await Future(() {});
          expect(firstCanceled, true);
        });

        test('cancels listener on current and outer stream on cancel',
            () async {
          outer.add(first.stream);
          await Future(() {});
          await subscription.cancel();

          await Future(() {});
          expect(outerCanceled, true);
          expect(firstCanceled, true);
        });
      });
    }
  }

  group('switchMap', () {
    test('uses map function', () async {
      var outer = StreamController<List<int>>();

      var values = [];
      outer.stream
          .transform(switchMap((l) => Stream.fromIterable(l)))
          .listen(values.add);

      outer.add([1, 2, 3]);
      await Future(() {});
      outer.add([4, 5, 6]);
      await Future(() {});
      expect(values, [1, 2, 3, 4, 5, 6]);
    });

    test('can create a broadcast stream', () async {
      var outer = StreamController.broadcast();

      var transformed = outer.stream.transform(switchMap(null));

      expect(transformed.isBroadcast, true);
    });
  });
}

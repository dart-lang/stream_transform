// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:stream_transform/src/from_handlers.dart';

void main() {
  StreamController<int> values;
  List<int> emittedValues;
  bool valuesCanceled;
  bool isDone;
  List<String> errors;
  Stream<int> transformed;
  StreamSubscription<int> subscription;

  void setUpForController(StreamController<int> controller,
      StreamTransformer<int, int> transformer) {
    valuesCanceled = false;
    values = controller
      ..onCancel = () {
        valuesCanceled = true;
      };
    emittedValues = [];
    errors = [];
    isDone = false;
    transformed = values.stream.transform(transformer);
    subscription =
        transformed.listen(emittedValues.add, onError: errors.add, onDone: () {
      isDone = true;
    });
  }

  group('default from_handlers', () {
    group('Single subscription stream', () {
      setUp(() {
        setUpForController(StreamController(), fromHandlers());
      });

      test('has correct stream type', () {
        expect(transformed.isBroadcast, false);
      });

      test('forwards values', () async {
        values..add(1)..add(2);
        await Future(() {});
        expect(emittedValues, [1, 2]);
      });

      test('forwards errors', () async {
        values.addError('error');
        await Future(() {});
        expect(errors, ['error']);
      });

      test('forwards done', () async {
        await values.close();
        expect(isDone, true);
      });

      test('forwards cancel', () async {
        await subscription.cancel();
        expect(valuesCanceled, true);
      });
    });

    group('broadcast stream with muliple listeners', () {
      List<int> emittedValues2;
      List<String> errors2;
      bool isDone2;
      StreamSubscription<int> subscription2;

      setUp(() {
        setUpForController(StreamController.broadcast(), fromHandlers());
        emittedValues2 = [];
        errors2 = [];
        isDone2 = false;
        subscription2 = transformed
            .listen(emittedValues2.add, onError: errors2.add, onDone: () {
          isDone2 = true;
        });
      });

      test('has correct stream type', () {
        expect(transformed.isBroadcast, true);
      });

      test('forwards values', () async {
        values..add(1)..add(2);
        await Future(() {});
        expect(emittedValues, [1, 2]);
        expect(emittedValues2, [1, 2]);
      });

      test('forwards errors', () async {
        values.addError('error');
        await Future(() {});
        expect(errors, ['error']);
        expect(errors2, ['error']);
      });

      test('forwards done', () async {
        await values.close();
        expect(isDone, true);
        expect(isDone2, true);
      });

      test('forwards cancel', () async {
        await subscription.cancel();
        expect(valuesCanceled, false);
        await subscription2.cancel();
        expect(valuesCanceled, true);
      });
    });
  });

  group('custom handlers', () {
    group('single subscription', () {
      setUp(() async {
        setUpForController(StreamController(),
            fromHandlers(handleData: (value, sink) {
          sink.add(value + 1);
        }));
      });
      test('uses transform from handleData', () async {
        values..add(1)..add(2);
        await Future(() {});
        expect(emittedValues, [2, 3]);
      });
    });

    group('broadcast stream with multiple listeners', () {
      int dataCallCount;
      int doneCallCount;
      int errorCallCount;

      setUp(() async {
        dataCallCount = 0;
        doneCallCount = 0;
        errorCallCount = 0;
        setUpForController(
            StreamController.broadcast(),
            fromHandlers(handleData: (value, sink) {
              dataCallCount++;
            }, handleError: (error, stackTrace, sink) {
              errorCallCount++;
              sink.addError(error, stackTrace);
            }, handleDone: (sink) {
              doneCallCount++;
            }));
        transformed.listen((_) {}, onError: (_, __) {});
      });

      test('handles data once', () async {
        values.add(1);
        await Future(() {});
        expect(dataCallCount, 1);
      });

      test('handles done once', () async {
        await values.close();
        expect(doneCallCount, 1);
      });

      test('handles errors once', () async {
        values.addError('error');
        await Future(() {});
        expect(errorCallCount, 1);
      });
    });
  });
}

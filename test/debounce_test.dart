import 'dart:async';
import 'package:test/test.dart';
import 'package:stream_transform/stream_transform.dart';

void main() {
  var streamTypes = {
    'single subscription': () => new StreamController(),
    'broadcast': () => new StreamController.broadcast()
  };
  for (var streamType in streamTypes.keys) {
    group('Stream type [$streamType]', () {
      StreamController values;
      List emittedValues;
      bool valuesCanceled;
      bool isDone;
      List errors;
      StreamSubscription subscription;

      void setUpStreams(StreamTransformer transformer) {
        valuesCanceled = false;
        values = streamTypes[streamType]()
          ..onCancel = () {
            valuesCanceled = true;
          };
        emittedValues = [];
        errors = [];
        isDone = false;
        subscription = values.stream
            .transform(transformer)
            .listen(emittedValues.add, onError: errors.add, onDone: () {
          isDone = true;
        });
      }

      group('debounce', () {
        setUp(() async {
          setUpStreams(debounce(const Duration(milliseconds: 5)));
        });

        test('cancels values', () async {
          await subscription.cancel();
          expect(valuesCanceled, true);
        });

        test('swallows values that come faster than duration', () async {
          values.add(1);
          values.add(2);
          await values.close();
          await new Future.delayed(const Duration(milliseconds: 6));
          expect(emittedValues, [2]);
        });

        test('outputs multiple values spaced further than duration', () async {
          values.add(1);
          await new Future.delayed(const Duration(milliseconds: 6));
          values.add(2);
          await new Future.delayed(const Duration(milliseconds: 6));
          expect(emittedValues, [1, 2]);
        });
      });

      group('debounceBuffer', () {
        setUp(() async {
          setUpStreams(debounceBuffer(const Duration(milliseconds: 5)));
        });

        test('cancels values', () async {
          await subscription.cancel();
          expect(valuesCanceled, true);
        });

        test('swallows values that come faster than duration', () async {
          values.add(1);
          values.add(2);
          await values.close();
          await new Future.delayed(const Duration(milliseconds: 6));
          expect(emittedValues, [
            [1, 2]
          ]);
        });

        test('outputs multiple values spaced further than duration', () async {
          values.add(1);
          await new Future.delayed(const Duration(milliseconds: 6));
          values.add(2);
          await new Future.delayed(const Duration(milliseconds: 6));
          expect(emittedValues, [
            [1],
            [2]
          ]);
        });
      });
    });
  }
}

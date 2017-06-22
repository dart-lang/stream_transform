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
      Stream transformed;
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
          values.add(1);
          values.add(2);
          await values.close();
          await new Future.delayed(const Duration(milliseconds: 10));
          expect(emittedValues, [2]);
        });

        test('outputs multiple values spaced further than duration', () async {
          values.add(1);
          await new Future.delayed(const Duration(milliseconds: 10));
          values.add(2);
          await new Future.delayed(const Duration(milliseconds: 10));
          expect(emittedValues, [1, 2]);
        });

        test('waits for pending value to close', () async {
          values.add(1);
          await new Future.delayed(const Duration(milliseconds: 10));
          await values.close();
          await new Future(() {});
          expect(isDone, true);
        });

        test('closes output if there are no pending values', () async {
          values.add(1);
          await new Future.delayed(const Duration(milliseconds: 10));
          values.add(2);
          await new Future(() {});
          await values.close();
          expect(isDone, false);
          await new Future.delayed(const Duration(milliseconds: 10));
          expect(isDone, true);
        });

        test('does not starve output if many values come closer than duration',
            () async {
          values.add(1);
          await new Future.delayed(const Duration(milliseconds: 3));
          values.add(2);
          await new Future.delayed(const Duration(milliseconds: 3));
          values.add(3);
          expect(emittedValues, [2]);
        });

        if (streamType == 'broadcast') {
          test('multiple listeners all get values', () async {
            var otherValues = [];
            transformed.listen(otherValues.add);
            values.add(1);
            values.add(2);
            await new Future.delayed(const Duration(milliseconds: 10));
            expect(emittedValues, [2]);
            expect(otherValues, [2]);
          });
        }
      });
    });
  }
}

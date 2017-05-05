import 'dart:async';

import 'package:test/test.dart';

import 'package:stream_transform/stream_transform.dart';

import 'util/matchers.dart';

void main() {
  group('merge', () {
    test('includes all values', () async {
      var first = new Stream.fromIterable([1, 2, 3]);
      var second = new Stream.fromIterable([4, 5, 6]);
      var allValues = await first.transform(merge(second)).toList();
      expect(allValues, containsAllInOrder([1, 2, 3]));
      expect(allValues, containsAllInOrder([4, 5, 6]));
      expect(allValues, hasLength(6));
    });

    test('cancels both sources', () async {
      var firstCanceled = false;
      var first = new StreamController()
        ..onCancel = () {
          firstCanceled = true;
        };
      var secondCanceled = false;
      var second = new StreamController()
        ..onCancel = () {
          secondCanceled = true;
        };
      var subscription =
          first.stream.transform(merge(second.stream)).listen((_) {});
      await subscription.cancel();
      expect(firstCanceled, true);
      expect(secondCanceled, true);
    });
  });

  group('mergeAll', () {
    test('includes all values', () async {
      var first = new Stream.fromIterable([1, 2, 3]);
      var second = new Stream.fromIterable([4, 5, 6]);
      var third = new Stream.fromIterable([7, 8, 9]);
      var allValues = await first.transform(mergeAll([second, third])).toList();
      expect(allValues, containsAllInOrder([1, 2, 3]));
      expect(allValues, containsAllInOrder([4, 5, 6]));
      expect(allValues, containsAllInOrder([7, 8, 9]));
      expect(allValues, hasLength(9));
    });

    test('handles mix of broadcast and single-subscription', () async {
      var firstCanceled = false;
      var first = new StreamController.broadcast()
        ..onCancel = () {
          firstCanceled = true;
        };
      var secondBroadcastCanceled = false;
      var secondBroadcast = new StreamController.broadcast()
        ..onCancel = () {
          secondBroadcastCanceled = true;
        };
      var secondSingleCanceled = false;
      var secondSingle = new StreamController()
        ..onCancel = () {
          secondSingleCanceled = true;
        };

      var merged = first.stream
          .transform(mergeAll([secondBroadcast.stream, secondSingle.stream]));

      var firstListenerValues = [];
      var secondListenerValues = [];

      var firstSubscription = merged.listen(firstListenerValues.add);
      var secondSubscription = merged.listen(secondListenerValues.add);

      first.add(1);
      secondBroadcast.add(2);
      secondSingle.add(3);

      await new Future(() {});
      await firstSubscription.cancel();

      expect(firstCanceled, false);
      expect(secondBroadcastCanceled, false);
      expect(secondSingleCanceled, false);

      first.add(4);
      secondBroadcast.add(5);
      secondSingle.add(6);

      await new Future(() {});
      await secondSubscription.cancel();

      await new Future(() {});
      expect(firstCanceled, true);
      expect(secondBroadcastCanceled, true);
      expect(secondSingleCanceled, true);

      expect(firstListenerValues, [1, 2, 3]);
      expect(secondListenerValues, [1, 2, 3, 4, 5, 6]);
    });
  });
}

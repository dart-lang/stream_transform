import 'dart:async';

import 'package:test/test.dart';

import 'package:stream_transform/stream_transform.dart';

void main() {
  group('Scan', () {
    test('produces intermediate values', () async {
      var source = new Stream.fromIterable([1, 2, 3, 4]);
      var sum = (int x, int y) => x + y;
      var result = await source.transform(scan(0, sum)).toList();

      expect(result, [1, 3, 6, 10]);
    });
  });
}

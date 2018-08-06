// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:test/test.dart';

import 'package:stream_transform/stream_transform.dart';

void main() {
  group('Scan', () {
    test('produces intermediate values', () async {
      var source = Stream.fromIterable([1, 2, 3, 4]);
      var sum = (int x, int y) => x + y;
      var result = await source.transform(scan(0, sum)).toList();

      expect(result, [1, 3, 6, 10]);
    });

    test('can create a broadcast stream', () async {
      var source = StreamController.broadcast();

      var transformed = source.stream.transform(scan(null, null));

      expect(transformed.isBroadcast, true);
    });
  });
}

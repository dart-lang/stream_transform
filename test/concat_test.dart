// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

import 'package:test/test.dart';

import 'package:stream_transform/stream_transform.dart';

void main() {
  group('concat', () {
    test('adds all values from both streams', () async {
      var first = new Stream.fromIterable([1, 2, 3]);
      var second = new Stream.fromIterable([4, 5, 6]);
      var all = await first.transform(concat(second)).toList();
      expect(all, [1, 2, 3, 4, 5, 6]);
    });

    test('closes first stream on cancel', () async {
      var firstStreamClosed = false;
      var first = new StreamController()
        ..onCancel = () {
          firstStreamClosed = true;
        };
      var second = new StreamController();
      var subscription =
          first.stream.transform(concat(second.stream)).listen((_) {});
      await subscription.cancel();
      expect(firstStreamClosed, true);
    });

    test('closes second stream on cancel if first stream done', () async {
      var first = new StreamController();
      var secondStreamClosed = false;
      var second = new StreamController()
        ..onCancel = () {
          secondStreamClosed = true;
        };
      var subscription =
          first.stream.transform(concat(second.stream)).listen((_) {});
      await first.close();
      await new Future(() {});
      await subscription.cancel();
      expect(secondStreamClosed, true);
    });
  });
}

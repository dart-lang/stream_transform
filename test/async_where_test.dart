// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

import 'package:test/test.dart';

import 'package:stream_transform/stream_transform.dart';

void main() {
  test('forwards only events that pass the predicate', () async {
    var values = new Stream.fromIterable([1, 2, 3, 4]);
    var filtered = values.transform(asyncWhere((e) async => e > 2));
    expect(await filtered.toList(), [3, 4]);
  });

  test('allows predicates that go through event loop', () async {
    var values = new Stream.fromIterable([1, 2, 3, 4]);
    var filtered = values.transform(asyncWhere((e) async {
      await new Future(() {});
      return e > 2;
    }));
    expect(await filtered.toList(), [3, 4]);
  });

  test('allows synchronous predicate', () async {
    var values = new Stream.fromIterable([1, 2, 3, 4]);
    var filtered = values.transform(asyncWhere((e) => e > 2));
    expect(await filtered.toList(), [3, 4]);
  });

  test('can result in empty stream', () async {
    var values = new Stream.fromIterable([1, 2, 3, 4]);
    var filtered = values.transform(asyncWhere((e) => e > 4));
    expect(await filtered.isEmpty, true);
  });
}

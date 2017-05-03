// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Starts emitting values from [next] after the original stream is complete.
///
/// If the initial stream never finishes, the [next] stream will never be
/// listened to.
StreamTransformer<T, T> concat<T>(Stream<T> next) => new _Concat<T>(next);

class _Concat<T> implements StreamTransformer<T, T> {
  final Stream _next;

  _Concat(this._next);

  @override
  Stream<T> bind(Stream<T> first) {
    var controller = new StreamController<T>();
    controller
        .addStream(first)
        .then((_) => controller.addStream(_next))
        .then((_) => controller.close());
    return controller.stream;
  }
}

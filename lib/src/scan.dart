// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

typedef S Func2<T, S>(T item, S accumulation);

/// Scan is like fold, but instead of producing a single value it yields
/// each intermediate accumulation.
StreamTransformer<T, S> scan<T, S>(Func2<T, S> map, S accumulation) =>
    new _Scan(map, accumulation);

class _Scan<T, S> implements StreamTransformer<T, S> {
  final Func2<T, S> _map;
  S _accumulation;

  _Scan(this._map, this._accumulation);

  @override
  Stream<S> bind(Stream<T> source) {
    return source.map((item) {
      _accumulation = _map(item, _accumulation);
      return _accumulation;
    });
  }
}

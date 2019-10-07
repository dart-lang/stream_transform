// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// A utility similar to [fold] which emits intermediate accumulations.
extension Scan<T> on Stream<T> {
  /// Like [fold], but instead of producing a single value it yields each
  /// intermediate accumulation.
  ///
  /// If [combine] returns a Future it will not be called again for subsequent
  /// events from the source until it completes, therefore [combine] is always
  /// called for elements in order, and the result stream always maintains the
  /// same order as the original.
  Stream<S> scan<S>(
      S initialValue, FutureOr<S> combine(S previousValue, T element)) {
    var accumulated = initialValue;
    return asyncMap((value) {
      var result = combine(accumulated, value);
      if (result is Future<S>) {
        return result.then((r) => accumulated = r);
      } else {
        return accumulated = result as S;
      }
    });
  }
}

/// Scan is like fold, but instead of producing a single value it yields
/// each intermediate accumulation.
///
/// If [combine] returns a Future it will not be called again for subsequent
/// events from the source until it completes, therefor the combine callback is
/// always called for elements in order, and the result stream always maintains
/// the same order as the original.
@Deprecated('Use the extension instead')
StreamTransformer<S, T> scan<S, T>(
        T initialValue, FutureOr<T> combine(T previousValue, S element)) =>
    StreamTransformer.fromBind((source) {
      var accumulated = initialValue;
      return source.asyncMap((value) {
        var result = combine(accumulated, value);
        if (result is Future<T>) {
          return result.then((r) => accumulated = r);
        } else {
          return accumulated = result as T;
        }
      });
    });

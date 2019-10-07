// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'followed_by.dart';

extension StartWith<T> on Stream<T> {
  /// Returns a stream which emits [initial] before any values from the original
  /// stream.
  ///
  /// If the original stream is a broadcast stream the result will be as well.
  Stream<T> startWith(T initial) =>
      startWithStream(Future.value(initial).asStream());

  /// Returns a stream which emits all values in [initial] before any values
  /// from the original stream.
  ///
  /// If the original stream is a broadcast stream the result will be as well.
  /// If the original stream is a broadcast stream it will miss any events which
  /// occur before the initial values are all emitted.
  Stream<T> startWithMany(Iterable<T> initial) =>
      startWithStream(Stream.fromIterable(initial));

  /// Returns a stream which emits all values in [initial] before any values
  /// from the original stream.
  ///
  /// If the original stream is a broadcast stream the result will be as well. If
  /// the original stream is a broadcast stream it will miss any events which
  /// occur before [initial] closes.
  Stream<T> startWithStream(Stream<T> initial) {
    if (isBroadcast && !initial.isBroadcast) {
      initial = initial.asBroadcastStream();
    }
    return initial.followedBy(this);
  }
}

/// Emits [initial] before any values from the original stream.
///
/// If the original stream is a broadcast stream the result will be as well.
@Deprecated('Use the extension instead')
StreamTransformer<T, T> startWith<T>(T initial) =>
    startWithStream<T>(Future.value(initial).asStream());

/// Emits all values in [initial] before any values from the original stream.
///
/// If the original stream is a broadcast stream the result will be as well. If
/// the original stream is a broadcast stream it will miss any events which
/// occur before the initial values are all emitted.
@Deprecated('Use the extension instead')
StreamTransformer<T, T> startWithMany<T>(Iterable<T> initial) =>
    startWithStream<T>(Stream.fromIterable(initial));

/// Emits all values in [initial] before any values from the original stream.
///
/// If the original stream is a broadcast stream the result will be as well. If
/// the original stream is a broadcast stream it will miss any events which
/// occur before [initial] closes.
@Deprecated('Use the extension instead')
StreamTransformer<T, T> startWithStream<T>(Stream<T> initial) =>
    StreamTransformer.fromBind((values) {
      if (values.isBroadcast && !initial.isBroadcast) {
        initial = initial.asBroadcastStream();
      }
      return initial.transform(followedBy(values));
    });

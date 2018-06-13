// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

import 'from_handlers.dart';

/// Like [Stream.where] but allows the [test] to return a [Future].
///
/// Events on the result stream will be emitted in the order that [test]
/// completes which may not match the order of the original stream.
///
/// If the source stream is a broadcast stream the result will be as well. When
/// used with a broadcast stream behavior also differs from [Stream.where] in
/// that the [test] function is only called once per event, rather than once
/// per listener per event.
///
/// Errors from the source stream are forwarded directly to the result stream.
/// Errors during the conversion are also forwarded to the result stream.
///
/// The result stream will not close until the source stream closes and all
/// pending [test] calls have finished.
StreamTransformer<T, T> asyncWhere<T>(FutureOr<bool> test(T element)) {
  var valuesWaiting = 0;
  var sourceDone = false;
  return fromHandlers(handleData: (element, sink) {
    valuesWaiting++;
    () async {
      try {
        if (await test(element)) sink.add(element);
      } catch (e, st) {
        sink.addError(e, st);
      }
      valuesWaiting--;
      if (valuesWaiting <= 0 && sourceDone) sink.close();
    }();
  }, handleDone: (sink) {
    sourceDone = true;
    if (valuesWaiting <= 0) sink.close();
  });
}

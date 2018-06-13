// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'from_handlers.dart';

/// Like [Stream.asyncMap] but the [convert] callback may be called for an
/// element before processing for the previous element is finished.
///
/// Events on the result stream will be emitted in the order that [convert]
/// completed which may not match the order of the original stream.
///
/// If the source stream is a broadcast stream the result will be as well. When
/// used with a broadcast stream behavior also differs from [Stream.asyncMap] in
/// that the [convert] function is only called once per event, rather than once
/// per listener per event. The [convert] callback won't be called for events
/// while a broadcast stream has no listener.
///
/// Errors from the source stream are forwarded directly to the result stream.
/// Errors during the conversion are also forwarded to the result stream.
///
/// The result stream will not close until the source stream closes and all
/// pending conversions have finished.
StreamTransformer<S, T> concurrentAsyncMap<S, T>(FutureOr<T> convert(S event)) {
  var valuesWaiting = 0;
  var sourceDone = false;
  return fromHandlers(handleData: (element, sink) {
    valuesWaiting++;
    () async {
      try {
        sink.add(await convert(element));
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

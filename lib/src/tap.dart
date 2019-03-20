// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

import 'from_handlers.dart';

/// Taps into a Stream to allow additional handling on a single-subscriber
/// stream without first wrapping as a broadcast stream.
///
/// The [onValue] callback will be called with every value from the original
/// stream before it is forwarded to listeners on the resulting stream. May be
/// null if only [onError] or [onDone] callbacks are needed.
///
/// The [onError] callback will be called with every error from the original
/// stream before it is forwarded to listeners on the resulting stream.
///
/// The [onDone] callback will be called after the original stream closes and
/// before the resulting stream is closed.
///
/// Errors from any of the callbacks are ignored.
///
/// The callbacks may not be called until the tapped stream has a listener, and
/// may not be called after the listener has canceled the subscription.
StreamTransformer<T, T> tap<T>(void Function(T) onValue,
        {void Function(Object, StackTrace) onError, void Function() onDone}) =>
    fromHandlers(handleData: (value, sink) {
      try {
        onValue?.call(value);
      } catch (_) {/*Ignore*/}
      sink.add(value);
    }, handleError: (error, stackTrace, sink) {
      try {
        onError?.call(error, stackTrace);
      } catch (_) {/*Ignore*/}
      sink.addError(error, stackTrace);
    }, handleDone: (sink) {
      try {
        onDone?.call();
      } catch (_) {/*Ignore*/}
      sink.close();
    });

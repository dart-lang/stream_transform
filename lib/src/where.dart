// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'from_handlers.dart';

/// Utilities to filter events.
extension Where<T> on Stream<T> {
  /// Returns a stream which emits only the events which have type [S].
  ///
  /// If the source stream is a broadcast stream the result will be as well.
  ///
  /// Errors from the source stream are forwarded directly to the result stream.
  ///
  /// [S] should be a subtype of the stream's generic type, otherwise nothing of
  /// type [S] could possibly be emitted, however there is no static or runtime
  /// checking that this is the case.
  Stream<S> whereType<S>() => transform(_WhereType<S>());

  /// Like [where] but allows the [test] to return a [Future].
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
  /// Errors from [test] are also forwarded to the result stream.
  ///
  /// The result stream will not close until the source stream closes and all
  /// pending [test] calls have finished.
  Stream<T> asyncWhere(FutureOr<bool> test(T element)) {
    var valuesWaiting = 0;
    var sourceDone = false;
    return transform(fromHandlers(handleData: (element, sink) {
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
    }));
  }
}

/// Emits only the events which have type [R].
///
/// If the source stream is a broadcast stream the result will be as well.
///
/// Errors from the source stream are forwarded directly to the result stream.
///
/// The static type of the returned transformer takes `Null` so that it can
/// satisfy the subtype requirements for the `stream.transform()` argument on
/// any source stream. The argument to `bind` has been broadened to take
/// `Stream<Object>` since it will never be passed a `Stream<Null>` at runtime.
/// This is safe to use on any source stream.
///
/// [R] should be a subtype of the stream's generic type, otherwise nothing of
/// type [R] could possibly be emitted, however there is no static or runtime
/// checking that this is the case.
@Deprecated('Use the extension instead')
StreamTransformer<Null, R> whereType<R>() => _WhereType<R>();

class _WhereType<R> extends StreamTransformerBase<Null, R> {
  @override
  Stream<R> bind(Stream<Object> source) {
    var controller = source.isBroadcast
        ? StreamController<R>.broadcast(sync: true)
        : StreamController<R>(sync: true);

    StreamSubscription<Object> subscription;
    controller.onListen = () {
      assert(subscription == null);
      subscription = source.listen(
          (value) {
            if (value is R) controller.add(value);
          },
          onError: controller.addError,
          onDone: () {
            subscription = null;
            controller.close();
          });
      if (!source.isBroadcast) {
        controller
          ..onPause = subscription.pause
          ..onResume = subscription.resume;
      }
      controller.onCancel = () {
        subscription?.cancel();
        subscription = null;
      };
    };
    return controller.stream;
  }
}

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
@Deprecated('Use the extension instead')
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

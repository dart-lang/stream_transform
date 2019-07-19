// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Like [new StreamTransformer.fromHandlers] but the handlers are called once
/// per event rather than once per listener for broadcast streams.
StreamTransformer<S, T> fromHandlers<S, T>(
        {void Function(S, EventSink<T>) handleData,
        void Function(Object, StackTrace, EventSink<T>) handleError,
        void Function(EventSink<T>) handleDone}) =>
    _StreamTransformer(
        handleData: handleData,
        handleError: handleError,
        handleDone: handleDone);

class _StreamTransformer<S, T> extends StreamTransformerBase<S, T> {
  final void Function(S, EventSink<T>) _handleData;
  final void Function(EventSink<T>) _handleDone;
  final void Function(Object, StackTrace, EventSink<T>) _handleError;

  _StreamTransformer(
      {void Function(S, EventSink<T>) handleData,
      void Function(Object, StackTrace, EventSink<T>) handleError,
      void Function(EventSink<T>) handleDone})
      : _handleData = handleData ?? _defaultHandleData,
        _handleError = handleError ?? _defaultHandleError,
        _handleDone = handleDone ?? _defaultHandleDone;

  static void _defaultHandleData<S, T>(S value, EventSink<T> sink) {
    sink.add(value as T);
  }

  static void _defaultHandleError<T>(
      Object error, StackTrace stackTrace, EventSink<T> sink) {
    sink.addError(error, stackTrace);
  }

  static void _defaultHandleDone<T>(EventSink<T> sink) {
    sink.close();
  }

  @override
  Stream<T> bind(Stream<S> values) {
    var controller = values.isBroadcast
        ? StreamController<T>.broadcast(sync: true)
        : StreamController<T>(sync: true);

    StreamSubscription<S> subscription;
    controller.onListen = () {
      assert(subscription == null);
      var valuesDone = false;
      subscription = values.listen((value) => _handleData(value, controller),
          onError: (error, StackTrace stackTrace) {
        _handleError(error, stackTrace, controller);
      }, onDone: () {
        valuesDone = true;
        _handleDone(controller);
      });
      if (!values.isBroadcast) {
        controller
          ..onPause = subscription.pause
          ..onResume = subscription.resume;
      }
      controller.onCancel = () {
        var toCancel = subscription;
        subscription = null;
        if (!valuesDone) return toCancel.cancel();
        return null;
      };
    };
    return controller.stream;
  }
}

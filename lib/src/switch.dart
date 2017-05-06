// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

/// Maps events to a Stream and emits values from the most recently created
/// Stream.
///
/// When the source emits a value it will be converted to a [Stream] using [map]
/// and the output will switch to emitting events from that result.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of the types of the streams produced by [map].
StreamTransformer<S, T> switchMap<S, T>(Stream<T> map(S event)) =>
    new StreamTransformer((stream, cancelOnError) => stream
        .map(map)
        .transform(switchLatest())
        .listen(null, cancelOnError: cancelOnError));

/// Emits values from the most recently emitted Stream.
///
/// When the source emits a stream the output will switch to emitting events
/// from that stream.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of the types of streams emitted.
StreamTransformer<Stream<T>, T> switchLatest<T>() =>
    const _SwitchTransformer<T>();

class _SwitchTransformer<T> implements StreamTransformer<Stream<T>, T> {
  const _SwitchTransformer();

  @override
  Stream<T> bind(Stream<Stream<T>> outer) {
    StreamController<T> controller;
    if (outer.isBroadcast) {
      controller = new StreamController<T>.broadcast();
    } else {
      controller = new StreamController<T>();
    }
    StreamSubscription<T> innerSubscription;
    StreamSubscription<Stream<T>> outerSubscription;
    controller.onListen = () {
      var outerStreamDone = false;
      var innerStreamDone = false;
      outerSubscription = outer.listen((innerStream) {
        innerSubscription?.cancel();
        innerSubscription = innerStream.listen(controller.add);
        innerSubscription.onDone(() {
          innerStreamDone = true;
          if (outerStreamDone) {
            controller.close();
          }
        });
        innerSubscription.onError(controller.addError);
      });
      outerSubscription.onDone(() {
        outerStreamDone = true;
        if (innerStreamDone) {
          controller.close();
        }
      });
      outerSubscription.onError(controller.addError);
    };

    cancelSubscriptions() => Future.wait([
          innerSubscription?.cancel() ?? new Future.value(),
          outerSubscription?.cancel() ?? new Future.value()
        ]);

    if (!outer.isBroadcast) {
      controller.onPause = () {
        innerSubscription?.pause();
        outerSubscription?.pause();
      };
      controller.onResume = () {
        innerSubscription?.resume();
        outerSubscription?.resume();
      };
      controller.onCancel = () => cancelSubscriptions();
    } else {
      controller.onCancel = () {
        if (controller.hasListener) return new Future.value();
        return cancelSubscriptions();
      };
    }
    return controller.stream;
  }
}

// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

import 'chain_transformers.dart';
import 'map.dart';

/// Maps events to a Stream and emits values from the most recently created
/// Stream.
///
/// When the source emits a value it will be converted to a [Stream] using [map]
/// and the output will switch to emitting events from that result.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of the types of the streams produced by [map].
StreamTransformer<S, T> switchMap<S, T>(Stream<T> convert(S event)) =>
    chainTransformers(map(convert), switchLatest());

/// Emits values from the most recently emitted Stream.
///
/// When the source emits a stream the output will switch to emitting events
/// from that stream.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of the types of streams emitted.
StreamTransformer<Stream<T>, T> switchLatest<T>() => _SwitchTransformer<T>();

class _SwitchTransformer<T> extends StreamTransformerBase<Stream<T>, T> {
  const _SwitchTransformer();

  @override
  Stream<T> bind(Stream<Stream<T>> outer) {
    var controller = outer.isBroadcast
        ? StreamController<T>.broadcast(sync: true)
        : StreamController<T>(sync: true);

    StreamSubscription<Stream<T>> outerSubscription;

    controller.onListen = () {
      assert(outerSubscription == null);

      StreamSubscription<T> innerSubscription;
      var outerStreamDone = false;

      outerSubscription = outer.listen(
          (innerStream) {
            innerSubscription?.cancel();
            innerSubscription = innerStream.listen(controller.add,
                onError: controller.addError, onDone: () {
              innerSubscription = null;
              if (outerStreamDone) controller.close();
            });
          },
          onError: controller.addError,
          onDone: () {
            outerStreamDone = true;
            if (innerSubscription == null) controller.close();
          });
      if (!outer.isBroadcast) {
        controller
          ..onPause = () {
            innerSubscription?.pause();
            outerSubscription.pause();
          }
          ..onResume = () {
            innerSubscription?.resume();
            outerSubscription.resume();
          };
      }
      controller.onCancel = () {
        var toCancel = <StreamSubscription<void>>[];
        if (!outerStreamDone) toCancel.add(outerSubscription);
        if (innerSubscription != null) {
          toCancel.add(innerSubscription);
        }
        outerSubscription = null;
        innerSubscription = null;
        if (toCancel.isEmpty) return null;
        return Future.wait(toCancel.map((s) => s.cancel()));
      };
    };
    return controller.stream;
  }
}

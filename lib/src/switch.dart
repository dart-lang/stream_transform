// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// A utility to take events from the most recent sub stream returned by a
/// callback.
extension Switch<T> on Stream<T> {
  /// Maps events to a Stream and emits values from the most recently created
  /// Stream.
  ///
  /// When the source emits a value it will be converted to a [Stream] using
  /// [convert] and the output will switch to emitting events from that result.
  ///
  /// If the source stream is a broadcast stream, the result stream will be as
  /// well, regardless of the types of the streams produced by [convert].
  Stream<S> switchMap<S>(Stream<S> convert(T event)) {
    return map(convert).switchLatest();
  }
}

/// A utility to take events from the most recent sub stream.
extension SwitchLatest<T> on Stream<Stream<T>> {
  /// Emits values from the most recently emitted Stream.
  ///
  /// When the source emits a stream the output will switch to emitting events
  /// from that stream.
  ///
  /// If the source stream is a broadcast stream, the result stream will be as
  /// well, regardless of the types of streams emitted.
  Stream<T> switchLatest() => transform(_SwitchTransformer<T>());
}

/// Maps events to a Stream and emits values from the most recently created
/// Stream.
///
/// When the source emits a value it will be converted to a [Stream] using
/// [convert] and the output will switch to emitting events from that result.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of the types of the streams produced by [convert].
@Deprecated('Use the extension instead')
StreamTransformer<S, T> switchMap<S, T>(Stream<T> convert(S event)) =>
    StreamTransformer.fromBind(
        (source) => source.map(convert).transform(switchLatest()));

/// Emits values from the most recently emitted Stream.
///
/// When the source emits a stream the output will switch to emitting events
/// from that stream.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of the types of streams emitted.
@Deprecated('Use the extension instead')
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

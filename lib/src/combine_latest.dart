// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Combine the latest value from the source stream with the latest value from
/// [combineWith] using [combine].
///
/// No event will be emitted from the result stream until both the source stream
/// and [combineWith] have each emitted at least one event. The result stream
/// will not close until both the source stream and [combineWith] have closed.
/// Errors throw by [combine], along with any errors on the source stream or
/// [combineWith], are forwarded to the result stream.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of [combineWith]'s type. If a single subscription stream is
/// merged into a broadcast stream it may never be canceled.
StreamTransformer<S, R> combineLatest<S, T, R>(
        Stream<T> combineWith, FutureOr<R> Function(S, T) combine) =>
    _CombineLatest(combineWith, combine);

class _CombineLatest<S, T, R> extends StreamTransformerBase<S, R> {
  final Stream<T> _other;
  final FutureOr<R> Function(S, T) _combine;

  _CombineLatest(this._other, this._combine);

  @override
  Stream<R> bind(Stream<S> source) {
    final controller = source.isBroadcast
        ? StreamController<R>.broadcast(sync: true)
        : StreamController<R>(sync: true);

    final other = (source.isBroadcast && !_other.isBroadcast)
        ? _other.asBroadcastStream()
        : _other;

    StreamSubscription sourceSubscription;
    StreamSubscription otherSubscription;

    var sourceDone = false;
    var otherDone = false;

    S latestSource;
    T latestOther;

    var sourceStarted = false;
    var otherStarted = false;

    void emitCombined() {
      if (!sourceStarted || !otherStarted) return;
      FutureOr<R> result;
      try {
        result = _combine(latestSource, latestOther);
      } catch (e, s) {
        controller.addError(e, s);
        return;
      }
      if (result is Future<R>) {
        result
            .then(controller.add, onError: controller.addError)
            .whenComplete(() {
          sourceSubscription.resume();
          otherSubscription.resume();
        });
      } else {
        controller.add(result as R);
      }
    }

    controller.onListen = () {
      if (sourceSubscription != null) return;
      sourceSubscription = source.listen(
          (s) {
            sourceStarted = true;
            latestSource = s;
            emitCombined();
          },
          onError: controller.addError,
          onDone: () {
            sourceDone = true;
            if (otherDone) controller.close();
          });
      otherSubscription = other.listen(
          (o) {
            otherStarted = true;
            latestOther = o;
            emitCombined();
          },
          onError: controller.addError,
          onDone: () {
            otherDone = true;
            if (sourceDone) controller.close();
          });
      if (!source.isBroadcast) {
        controller
          ..onPause = () {
            sourceSubscription.pause();
            otherSubscription.pause();
          }
          ..onResume = () {
            sourceSubscription.resume();
            otherSubscription.resume();
          };
      }
      controller.onCancel = () async {
        var cancelSource = sourceSubscription.cancel();
        var cancelOther = otherSubscription.cancel();
        sourceSubscription = null;
        otherSubscription = null;

        await cancelSource;
        await cancelOther;
      };
    };
    return controller.stream;
  }
}

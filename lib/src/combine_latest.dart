// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Combine the latest value from the source stream with the latest value from
/// [other] using [combine].
///
/// No event will be emitted from the result stream until both the source stream
/// and [other] have each emitted at least one event. Once both streams have
/// emitted at least one event, the result stream will emit any time either
/// input stream emits.
///
/// For example:
///     source.transform(combineLatest(other, (a, b) => a + b));
///
///   source:
///     1--2-----4
///   other:
///     ------3---
///   result:
///     ------5--7
///
/// The result stream will not close until both the source stream and [other]
/// have closed.
///
/// Errors thrown by [combine], along with any errors on the source stream or
/// [other], are forwarded to the result stream.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of [other]'s type. If a single subscription stream is
/// combined with a broadcast stream it may never be canceled.
StreamTransformer<S, R> combineLatest<S, T, R>(
        Stream<T> other, FutureOr<R> Function(S, T) combine) =>
    _CombineLatest(other, combine);

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

    StreamSubscription<S> sourceSubscription;
    StreamSubscription<T> otherSubscription;

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
        sourceSubscription.pause();
        otherSubscription.pause();
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
      assert(sourceSubscription == null);
      sourceSubscription = source.listen(
          (s) {
            sourceStarted = true;
            latestSource = s;
            emitCombined();
          },
          onError: controller.addError,
          onDone: () {
            sourceDone = true;
            if (otherDone) {
              controller.close();
            } else if (!sourceStarted) {
              // Nothing can ever be emitted
              otherSubscription.cancel();
              controller.close();
            }
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
            if (sourceDone) {
              controller.close();
            } else if (!otherStarted) {
              // Nothing can ever be emitted
              sourceSubscription.cancel();
              controller.close();
            }
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
      controller.onCancel = () {
        var cancelSource = sourceSubscription.cancel();
        var cancelOther = otherSubscription.cancel();
        sourceSubscription = null;
        otherSubscription = null;
        return Future.wait([cancelSource, cancelOther]);
      };
    };
    return controller.stream;
  }
}

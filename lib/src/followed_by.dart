// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

extension FollowedBy<T> on Stream<T> {
  /// Returns a stream which emits values and errors from [next] after the
  /// original stream is complete.
  ///
  /// If the source stream never finishes, the [next] stream will never be
  /// listened to.
  ///
  /// If the source stream is a broadcast stream, the result will be as well.
  /// If a single-subscription follows a broadcast stream it may be listened
  /// to and never canceled since there may be broadcast listeners added later.
  ///
  /// If a broadcast stream follows any other stream it will miss any events or
  /// errors which occur before the first stream is done. If a broadcast stream
  /// follows a single-subscription stream, pausing the stream while it is
  /// listening to the second stream will cause events to be dropped rather than
  /// buffered.
  Stream<T> followedBy(Stream<T> next) => transform(_FollowedBy(next));
}

/// Starts emitting values from [next] after the original stream is complete.
///
/// If the initial stream never finishes, the [next] stream will never be
/// listened to.
///
/// If a single-subscription follows the a broadcast stream it may be listened
/// to and never canceled.
///
/// If a broadcast stream follows any other stream it will miss any events which
/// occur before the first stream is done. If a broadcast stream follows a
/// single-subscription stream, pausing the stream while it is listening to the
/// second stream will cause events to be dropped rather than buffered.
@Deprecated('Use the extension instead')
StreamTransformer<T, T> followedBy<T>(Stream<T> next) => _FollowedBy<T>(next);

class _FollowedBy<T> extends StreamTransformerBase<T, T> {
  final Stream<T> _next;

  _FollowedBy(this._next);

  @override
  Stream<T> bind(Stream<T> first) {
    var controller = first.isBroadcast
        ? StreamController<T>.broadcast(sync: true)
        : StreamController<T>(sync: true);

    var next = first.isBroadcast && !_next.isBroadcast
        ? _next.asBroadcastStream()
        : _next;

    StreamSubscription<T> subscription;
    var currentStream = first;
    var firstDone = false;
    var secondDone = false;

    Function currentDoneHandler;

    listen() {
      subscription = currentStream.listen(controller.add,
          onError: controller.addError, onDone: () => currentDoneHandler());
    }

    onSecondDone() {
      secondDone = true;
      controller.close();
    }

    onFirstDone() {
      firstDone = true;
      currentStream = next;
      currentDoneHandler = onSecondDone;
      listen();
    }

    currentDoneHandler = onFirstDone;

    controller.onListen = () {
      assert(subscription == null);
      listen();
      if (!first.isBroadcast) {
        controller
          ..onPause = () {
            if (!firstDone || !next.isBroadcast) return subscription.pause();
            subscription.cancel();
            subscription = null;
          }
          ..onResume = () {
            if (!firstDone || !next.isBroadcast) return subscription.resume();
            listen();
          };
      }
      controller.onCancel = () {
        if (secondDone) return null;
        var toCancel = subscription;
        subscription = null;
        return toCancel.cancel();
      };
    };
    return controller.stream;
  }
}

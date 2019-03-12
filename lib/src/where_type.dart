// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

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

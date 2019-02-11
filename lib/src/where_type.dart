// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Emits only the events which have type [R].
///
/// If the source stream is a broadcast stream the result will be as well.
///
/// Errors from the source stream are forwarded directly to the result stream.
StreamTransformer<Null, R> whereType<R>() => _WhereType<R>();

class _WhereType<R> extends StreamTransformerBase<Null, R> {
  @override
  Stream<R> bind(Stream<Object> values) {
    var controller = values.isBroadcast
        ? StreamController<R>.broadcast(sync: true)
        : StreamController<R>(sync: true);

    StreamSubscription<Object> subscription;
    controller.onListen = () {
      if (subscription != null) return;
      var valuesDone = false;
      subscription = values.listen(
          (value) {
            if (value is R) controller.add(value);
          },
          onError: controller.addError,
          onDone: () {
            valuesDone = true;
            controller.close();
          });
      if (!values.isBroadcast) {
        controller.onPause = subscription.pause;
        controller.onResume = subscription.resume;
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

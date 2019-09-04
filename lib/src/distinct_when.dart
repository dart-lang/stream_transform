// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

typedef DistinctWhenCondition<T> = bool Function(T value);

/// Emits values from the stream and applies `distinct` when the `condition` evaluates to `true`.
StreamTransformer<T, T> distinctWhen<T>(DistinctWhenCondition<T> condition) =>
    _DistinctWhen(condition);

class _DistinctWhen<T> extends StreamTransformerBase<T, T> {
  final DistinctWhenCondition<T> _condition;
  T _previous;

  _DistinctWhen(this._condition);

  @override
  Stream<T> bind(Stream<T> values) {
    var controller = values.isBroadcast
        ? StreamController<T>.broadcast(sync: true)
        : StreamController<T>(sync: true);

    StreamSubscription<T> subscription;
    var isDone = false;

    controller.onListen = () {
      if (isDone) return;
      subscription = values.listen(
        (data) {
          if (data != _previous || _condition(data) == false) {
            controller.add(data);
          }
          _previous = data;
        },
        onError: controller.addError,
        onDone: () {
          if (isDone) return;
          isDone = true;
          controller.close();
        },
      );
      if (!values.isBroadcast) {
        controller
          ..onPause = subscription.pause
          ..onResume = subscription.resume;
      }
      controller.onCancel = () {
        if (isDone) return null;
        var toCancel = subscription;
        subscription = null;
        return toCancel.cancel();
      };
    };
    return controller.stream;
  }
}

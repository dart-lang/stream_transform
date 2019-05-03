// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// A StreamTransformer which aggregates values and emits when it sees a value
/// on [_trigger].
///
/// If there are no pending values when [_trigger] emits the first value on the
/// source Stream will immediately flow through. Otherwise, the pending values
/// and released when [_trigger] emits.
///
/// Errors from the source stream or the trigger are immediately forwarded to
/// the output.
class AggregateSample<S, T> extends StreamTransformerBase<S, T> {
  final Stream<void> _trigger;
  final T Function(S, T) _aggregate;

  AggregateSample(this._trigger, this._aggregate);

  @override
  Stream<T> bind(Stream<S> values) {
    var controller = values.isBroadcast
        ? StreamController<T>.broadcast(sync: true)
        : StreamController<T>(sync: true);

    T currentResults;
    var waitingForTrigger = true;
    var isTriggerDone = false;
    var isValueDone = false;
    StreamSubscription<S> valueSub;
    StreamSubscription<void> triggerSub;

    emit() {
      controller.add(currentResults);
      currentResults = null;
      waitingForTrigger = true;
    }

    onValue(S value) {
      currentResults = _aggregate(value, currentResults);

      if (!waitingForTrigger) emit();

      if (isTriggerDone) {
        valueSub.cancel();
        controller.close();
      }
    }

    onValuesDone() {
      isValueDone = true;
      if (currentResults == null) {
        triggerSub?.cancel();
        controller.close();
      }
    }

    onTrigger(_) {
      waitingForTrigger = false;

      if (currentResults != null) emit();

      if (isValueDone) {
        triggerSub.cancel();
        controller.close();
      }
    }

    onTriggerDone() {
      isTriggerDone = true;
      if (waitingForTrigger) {
        valueSub?.cancel();
        controller.close();
      }
    }

    controller.onListen = () {
      assert(valueSub == null);
      valueSub = values.listen(onValue,
          onError: controller.addError, onDone: onValuesDone);
      if (triggerSub != null) {
        if (triggerSub.isPaused) triggerSub.resume();
      } else {
        triggerSub = _trigger.listen(onTrigger,
            onError: controller.addError, onDone: onTriggerDone);
      }
      if (!values.isBroadcast) {
        controller
          ..onPause = () {
            valueSub?.pause();
            triggerSub?.pause();
          }
          ..onResume = () {
            valueSub?.resume();
            triggerSub?.resume();
          };
      }
      controller.onCancel = () {
        var toCancel = <StreamSubscription<void>>[];
        if (!isValueDone) toCancel.add(valueSub);
        valueSub = null;
        if (_trigger.isBroadcast || !values.isBroadcast) {
          if (!isTriggerDone) toCancel.add(triggerSub);
          triggerSub = null;
        } else {
          triggerSub.pause();
        }
        if (toCancel.isEmpty) return null;
        return Future.wait(toCancel.map((s) => s.cancel()));
      };
    };
    return controller.stream;
  }
}

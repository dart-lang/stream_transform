// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

import 'from_handlers.dart';

extension Audit<T> on Stream<T> {
  /// Returns a Stream which only emits once per [duration], at the end of the
  /// period.
  ///
  /// If the source stream is a broadcast stream, the result will be as well.
  /// Errors are forwarded immediately.
  ///
  /// If there is no pending event when the source stream closes the output
  /// stream will close immediately. If there is a pending event the output
  /// stream will wait to emit it before closing.
  ///
  /// Differs from `throttle` in that it always emits the most recently received
  /// event rather than the first in the period. The events that are emitted are
  /// always delayed by some amount. If the event that started the period is the
  /// one that is emitted it will be delayed by [duration]. If a later event
  /// comes in within the period it's delay will be shorter by the difference in
  /// arrival times.
  ///
  /// Differs from `debounce` in that a value will always be emitted after
  /// [duration], the output will not be starved by values coming in repeatedly
  /// within [duration].
  ///
  /// For example:
  ///
  ///     source.audit(Duration(seconds: 5));
  ///
  ///     source: a------b--c----d--|
  ///     output: -----a------c--------d|
  Stream<T> audit(Duration duration) {
    Timer timer;
    var shouldClose = false;
    T recentData;

    return transform(fromHandlers(handleData: (T data, EventSink<T> sink) {
      recentData = data;
      timer ??= Timer(duration, () {
        sink.add(recentData);
        timer = null;
        if (shouldClose) {
          sink.close();
        }
      });
    }, handleDone: (EventSink<T> sink) {
      if (timer != null) {
        shouldClose = true;
      } else {
        sink.close();
      }
    }));
  }
}

/// Creates a StreamTransformer which only emits once per [duration], at the
/// end of the period.
///
/// Always introduces a delay of at most [duration].
///
/// Differs from `throttle` in that it always emits the most recently received
/// event rather than the first in the period.
///
/// Differs from `debounce` in that a value will always be emitted after
/// [duration], the output will not be starved by values coming in repeatedly
/// within [duration].
@Deprecated('Use the extension instead')
StreamTransformer<T, T> audit<T>(Duration duration) {
  Timer timer;
  var shouldClose = false;
  T recentData;

  return fromHandlers(handleData: (T data, EventSink<T> sink) {
    recentData = data;
    timer ??= Timer(duration, () {
      sink.add(recentData);
      timer = null;
      if (shouldClose) {
        sink.close();
      }
    });
  }, handleDone: (EventSink<T> sink) {
    if (timer != null) {
      shouldClose = true;
    } else {
      sink.close();
    }
  });
}

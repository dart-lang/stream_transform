// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

/// Creates a StreamTransformer which only emits once per [duration], at the
/// end of the period.
///
/// Like `throttle`, except it always emits the most recently received event in
/// a period.  Always introduces a delay of at most [duration].
StreamTransformer<T, T> audit<T>(Duration duration) {
  Timer timer;
  bool shouldClose = false;
  T recentData;

  return new StreamTransformer.fromHandlers(
      handleData: (T data, EventSink<T> sink) {
    recentData = data;
    timer ??= new Timer(duration, () {
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

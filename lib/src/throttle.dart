// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

import 'from_handlers.dart';

extension Throttle<T> on Stream<T> {
  /// Returns a stream which only emits once per [duration], at the beginning of
  /// the period.
  ///
  /// Events emitted by the source stream within [duration] following an emitted
  /// event will be discarded. Errors are always forwarded immediately.
  Stream<T> throttle(Duration duration) {
    Timer timer;

    return transform(fromHandlers(handleData: (data, sink) {
      if (timer == null) {
        sink.add(data);
        timer = Timer(duration, () {
          timer = null;
        });
      }
    }));
  }
}

/// Creates a StreamTransformer which only emits once per [duration], at the
/// beginning of the period.
@Deprecated('Use the extension instead')
StreamTransformer<T, T> throttle<T>(Duration duration) {
  Timer timer;

  return fromHandlers(handleData: (data, sink) {
    if (timer == null) {
      sink.add(data);
      timer = Timer(duration, () {
        timer = null;
      });
    }
  });
}

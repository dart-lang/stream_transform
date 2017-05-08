// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

/// Like [Stream.where] but allows the [test] to return a [Future].
StreamTransformer<T, T> asyncWhere<T>(FutureOr<bool> test(T element)) {
  var valueWaiting = false;
  var sourceDone = false;
  return new StreamTransformer<T, T>.fromHandlers(
      handleData: (element, sink) async {
    valueWaiting = true;
    if (await test(element)) sink.add(element);
    valueWaiting = false;
    if (sourceDone) sink.close();
  }, handleDone: (sink) {
    sourceDone = true;
    if (!valueWaiting) sink.close();
  });
}

// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Emits values from the source stream and [other] in any order as they arrive.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of the type of stream [other] is.
StreamTransformer<T, T> merge<T>(Stream<T> other) => new _Merge<T>([other]);

/// Emits values from the source stream and all streams in [others] in any order
/// as they arrive.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of the types of streams in [others].
StreamTransformer<T, T> mergeAll<T>(List<Stream<T>> others) =>
    new _Merge<T>(others);

class _Merge<T> implements StreamTransformer<T, T> {
  final List<Stream<T>> _others;

  _Merge(this._others);

  @override
  Stream<T> bind(Stream<T> first) {
    StreamController<T> controller;
    if (first.isBroadcast) {
      controller = new StreamController<T>.broadcast();
    } else {
      controller = new StreamController<T>();
    }
    List<StreamSubscription> subscriptions;
    List<Stream<T>> allStreams = [first]..addAll(_others);
    var activeStreamCount = 0;

    controller.onListen = () {
      if (subscriptions != null) return;
      subscriptions = allStreams.map((stream) {
        activeStreamCount++;
        return stream.listen(controller.add, onError: controller.addError,
            onDone: () {
          if (--activeStreamCount <= 0) controller.close();
        });
      }).toList();
    };

    // Forward methods from listener
    if (!first.isBroadcast) {
      controller.onPause = () {
        for (var subscription in subscriptions) {
          subscription.pause();
        }
      };
      controller.onResume = () {
        for (var subscription in subscriptions) {
          subscription.resume();
        }
      };
      controller.onCancel =
          () => Future.wait(subscriptions.map((s) => s.cancel()));
    } else {
      controller.onCancel = () {
        if (controller?.hasListener ?? false) return new Future.value(null);
        return Future.wait(subscriptions.map((s) => s.cancel()));
      };
    }
    return controller.stream;
  }
}

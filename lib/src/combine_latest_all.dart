// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Combine the latest value emitted from the source stream with the latest
/// values emitted from [others].
///
/// [combineLatestAll] subscribes to the source stream and [others] and when
/// any one of the streams emits, the result stream will emit a [List<T>] of
/// the latest values emitted from all streams.
///
/// The result stream will not emit until all source streams emit at least
/// once. If a source stream emits multiple values before another starts
/// emitting, all but the last value will be lost.
///
/// The result stream will not close until all source streams have closed. When
/// a source stream closes, the result stream will continue to emit the last
/// value from the closed stream when the other source streams emit until the
/// result stream has closed. If a source stream closes without emitting any
/// value, the result stream will close as well.
///
/// Errors thrown by any source stream will be forwarded to the result stream.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of the types of [others]. If a single subscription stream
/// is combined with a broadcast source stream, it may never be canceled.
///
/// ## Example
///
/// (Suppose first, second, and third are Stream<String>)
/// final combined = first
///     .transform(combineLatestAll([second, third]))
///     .map((data) => data.join());
///
/// first:    a----b------------------c--------d---|
/// second:   --1---------2-----------------|
/// third:    -------&----------%---|
/// combined: -------b1&--b2&---b2%---c2%------d2%-|
///
StreamTransformer<T, List<T>> combineLatestAll<T>(Iterable<Stream<T>> others) =>
    _CombineLatestAll<T>(others);

class _CombineLatestAll<T> extends StreamTransformerBase<T, List<T>> {
  final Iterable<Stream<T>> _others;

  _CombineLatestAll(this._others);

  @override
  Stream<List<T>> bind(Stream<T> source) {
    final controller = source.isBroadcast
        ? StreamController<List<T>>.broadcast(sync: true)
        : StreamController<List<T>>(sync: true);

    var allStreams = [source]..addAll(_others);
    if (source.isBroadcast) {
      allStreams = allStreams
          .map((s) => s.isBroadcast ? s : s.asBroadcastStream())
          .toList();
    }

    List<StreamSubscription<T>> subscriptions;

    controller.onListen = () {
      assert(subscriptions == null);

      final latestData = List<T>(allStreams.length);
      final hasEmitted = <int>{};
      void handleData(int index, T data) {
        latestData[index] = data;
        hasEmitted.add(index);
        if (hasEmitted.length == allStreams.length) {
          controller.add(List.from(latestData));
        }
      }

      var activeStreamCount = 0;
      subscriptions = allStreams.map((stream) {
        final index = activeStreamCount;
        activeStreamCount++;
        return stream.listen((data) => handleData(index, data),
            onError: controller.addError, onDone: () {
          if (--activeStreamCount <= 0 || !hasEmitted.contains(index)) {
            controller.close();
          }
        });
      }).toList();
      if (!source.isBroadcast) {
        controller
          ..onPause = () {
            for (var subscription in subscriptions) {
              subscription.pause();
            }
          }
          ..onResume = () {
            for (var subscription in subscriptions) {
              subscription.resume();
            }
          };
      }
      controller.onCancel = () {
        final toCancel = subscriptions;
        subscriptions = null;
        if (activeStreamCount <= 0) return null;
        return Future.wait(toCancel.map((s) => s.cancel()));
      };
    };
    return controller.stream;
  }
}

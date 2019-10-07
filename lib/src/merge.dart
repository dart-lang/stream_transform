// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Utilities to interleave events from multiple streams.
extension Merge<T> on Stream<T> {
  /// Returns a stream which emits values and errors from the source stream and
  /// [other] in any order as they arrive.
  ///
  /// The result stream will not close until both the source stream and [other]
  /// have closed.
  ///
  /// For example:
  ///
  ///    final result = source.merge(other);
  ///
  ///    source:  1--2-----3--|
  ///    other:   ------4-------5--|
  ///    result:  1--2--4--3----5--|
  ///
  /// If the source stream is a broadcast stream, the result stream will be as
  /// well, regardless of [other]'s type. If a single subscription stream is
  /// merged into a broadcast stream it may never be canceled since there may be
  /// broadcast listeners added later.
  ///
  /// If a broadcast stream is merged into a single-subscription stream any
  /// events emitted by [other] before the result stream has a subscriber will
  /// be discarded.
  Stream<T> merge(Stream<T> other) => transform(_Merge([other]));

  /// Returns a stream which emits values and errors from the source stream and
  /// any stream in [others] in any order as they arrive.
  ///
  /// The result stream will not close until the source stream and all streams
  /// in [others] have closed.
  ///
  /// For example:
  ///
  ///    final result = first.mergeAll([second, third]);
  ///
  ///    first:   1--2--------3--|
  ///    second:  ---------4-------5--|
  ///    third:   ------6---------------7--|
  ///    result:  1--2--6--4--3----5----7--|
  ///
  /// If the source stream is a broadcast stream, the result stream will be as
  /// well, regardless the types of streams in [others]. If a single
  /// subscription stream is merged into a broadcast stream it may never be
  /// canceled since there may be broadcast listeners added later.
  ///
  /// If a broadcast stream is merged into a single-subscription stream any
  /// events emitted by that stream before the result stream has a subscriber
  /// will be discarded.
  Stream<T> mergeAll(Iterable<Stream<T>> others) => transform(_Merge(others));
}

/// Emits values from the source stream and [other] in any order as they arrive.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of [other]'s type. If a single subscription stream is
/// merged into a broadcast stream it may never be canceled.
@Deprecated('Use the extension instead')
StreamTransformer<T, T> merge<T>(Stream<T> other) => _Merge<T>([other]);

/// Emits values from the source stream and all streams in [others] in any order
/// as they arrive.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of the types of streams in [others]. If single
/// subscription streams are merged into a broadcast stream they may never be
/// canceled.
@Deprecated('Use the extension instead')
StreamTransformer<T, T> mergeAll<T>(Iterable<Stream<T>> others) =>
    _Merge<T>(others);

class _Merge<T> extends StreamTransformerBase<T, T> {
  final Iterable<Stream<T>> _others;

  _Merge(this._others);

  @override
  Stream<T> bind(Stream<T> first) {
    var controller = first.isBroadcast
        ? StreamController<T>.broadcast(sync: true)
        : StreamController<T>(sync: true);

    var allStreams = [first]..addAll(_others);
    if (first.isBroadcast) {
      allStreams = allStreams
          .map((s) => s.isBroadcast ? s : s.asBroadcastStream())
          .toList();
    }

    List<StreamSubscription<T>> subscriptions;

    controller.onListen = () {
      assert(subscriptions == null);
      var activeStreamCount = 0;
      subscriptions = allStreams.map((stream) {
        activeStreamCount++;
        return stream.listen(controller.add, onError: controller.addError,
            onDone: () {
          if (--activeStreamCount <= 0) controller.close();
        });
      }).toList();
      if (!first.isBroadcast) {
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
        var toCancel = subscriptions;
        subscriptions = null;
        if (activeStreamCount <= 0) return null;
        return Future.wait(toCancel.map((s) => s.cancel()));
      };
    };
    return controller.stream;
  }
}

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

  /// Like [asyncExpand] but the [convert] callback may be called for an element
  /// before the Stream emitted by the previous element has closed.
  ///
  /// Events on the result stream will be emitted in the order they are emitted
  /// by the sub streams, which may not match the order of the original stream.
  ///
  /// Errors from [convert], the source stream, or any of the sub streams are
  /// forwarded to the result stream.
  ///
  /// The result stream will not close until the source stream closes and all
  /// sub streams have closed.
  ///
  /// If the source stream is a broadcast stream the result will be as well,
  /// regardless of the types of streams created by [convert]. In this case,
  /// some care should be taken:
  /// -  If [convert] returns a single subscription stream it may be listened to
  /// and never canceled.
  /// -  For any period of time where there are no listeners on the result
  /// stream, any sub streams from previously emitted events will be ignored,
  /// regardless of whether they emit further events after a listener is added
  /// back.
  Stream<S> concurrentAsyncExpand<S>(Stream<S> Function(T) convert) =>
      map(convert).transform(_MergeExpanded());
}

class _Merge<T> extends StreamTransformerBase<T, T> {
  final Iterable<Stream<T>> _others;

  _Merge(this._others);

  @override
  Stream<T> bind(Stream<T> first) {
    final controller = first.isBroadcast
        ? StreamController<T>.broadcast(sync: true)
        : StreamController<T>(sync: true);

    final allStreams = [
      first,
      for (final other in _others)
        !first.isBroadcast || other.isBroadcast
            ? other
            : other.asBroadcastStream(),
    ];

    controller.onListen = () {
      final subscriptions = <StreamSubscription<T>>[];
      for (final stream in allStreams) {
        final subscription =
            stream.listen(controller.add, onError: controller.addError);
        subscription.onDone(() {
          subscriptions.remove(subscription);
          if (subscriptions.isEmpty) controller.close();
        });
        subscriptions.add(subscription);
      }
      if (!first.isBroadcast) {
        controller
          ..onPause = () {
            for (final subscription in subscriptions) {
              subscription.pause();
            }
          }
          ..onResume = () {
            for (final subscription in subscriptions) {
              subscription.resume();
            }
          };
      }
      controller.onCancel = () {
        var cancels = subscriptions
            .map((s) => s.cancel())
            .where((f) => f != null)
            .toList();
        if (cancels.isEmpty) return null;
        return Future.wait(cancels).then((_) => null);
      };
    };
    return controller.stream;
  }
}

class _MergeExpanded<T> extends StreamTransformerBase<Stream<T>, T> {
  @override
  Stream<T> bind(Stream<Stream<T>> streams) {
    final controller = streams.isBroadcast
        ? StreamController<T>.broadcast(sync: true)
        : StreamController<T>(sync: true);

    controller.onListen = () {
      final subscriptions = <StreamSubscription<dynamic>>[];
      final outerSubscription = streams.listen((inner) {
        if (streams.isBroadcast && !inner.isBroadcast) {
          inner = inner.asBroadcastStream();
        }
        final subscription =
            inner.listen(controller.add, onError: controller.addError);
        subscription.onDone(() {
          subscriptions.remove(subscription);
          if (subscriptions.isEmpty) controller.close();
        });
        subscriptions.add(subscription);
      }, onError: controller.addError);
      outerSubscription.onDone(() {
        subscriptions.remove(outerSubscription);
        if (subscriptions.isEmpty) controller.close();
      });
      subscriptions.add(outerSubscription);
      if (!streams.isBroadcast) {
        controller
          ..onPause = () {
            for (final subscription in subscriptions) {
              subscription.pause();
            }
          }
          ..onResume = () {
            for (final subscription in subscriptions) {
              subscription.resume();
            }
          };
      }
      controller.onCancel = () {
        var cancels = subscriptions
            .map((s) => s.cancel())
            .where((f) => f != null)
            .toList();
        if (cancels.isEmpty) return null;
        return Future.wait(cancels).then((_) => null);
      };
    };
    return controller.stream;
  }
}

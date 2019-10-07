// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Utilities to combine events from multiple streams through a callback or into
/// a list.
extension CombineLatest<T> on Stream<T> {
  /// Returns a stream which combines the latest value from the source stream
  /// with the latest value from [other] using [combine].
  ///
  /// No event will be emitted until both the source stream and [other] have
  /// each emitted at least one event. If either the source stream or [other]
  /// emit multiple events before the other emits the first event, all but the
  /// last value will be discarded. Once both streams have emitted at least
  /// once, the result stream will emit any time either input stream emits.
  ///
  /// The result stream will not close until both the source stream and [other]
  /// have closed.
  ///
  /// For example:
  ///
  ///     source.combineLatest(other, (a, b) => a + b);
  ///
  ///     source: --1--2--------4--|
  ///     other:  -------3--|
  ///     result: -------5------7--|
  ///
  /// Errors thrown by [combine], along with any errors on the source stream or
  /// [other], are forwarded to the result stream.
  ///
  /// If the source stream is a broadcast stream, the result stream will be as
  /// well, regardless of [other]'s type. If a single subscription stream is
  /// combined with a broadcast stream it may never be canceled.
  Stream<S> combineLatest<T2, S>(
          Stream<T2> other, FutureOr<S> Function(T, T2) combine) =>
      transform(_CombineLatest(other, combine));

  /// Combine the latest value emitted from the source stream with the latest
  /// values emitted from [others].
  ///
  /// [combineLatestAll] subscribes to the source stream and [others] and when
  /// any one of the streams emits, the result stream will emit a [List<T>] of
  /// the latest values emitted from all streams.
  ///
  /// No event will be emitted until all source streams emit at least once. If a
  /// source stream emits multiple values before another starts emitting, all
  /// but the last value will be discarded. Once all source streams have emitted
  /// at least once, the result stream will emit any time any source stream
  /// emits.
  ///
  /// The result stream will not close until all source streams have closed. When
  /// a source stream closes, the result stream will continue to emit the last
  /// value from the closed stream when the other source streams emit until the
  /// result stream has closed. If a source stream closes without emitting any
  /// value, the result stream will close as well.
  ///
  /// For example:
  ///
  ///     final combined = first
  ///         .combineLatestAll([second, third])
  ///         .map((data) => data.join());
  ///
  ///     first:    a----b------------------c--------d---|
  ///     second:   --1---------2-----------------|
  ///     third:    -------&----------%---|
  ///     combined: -------b1&--b2&---b2%---c2%------d2%-|
  ///
  /// Errors thrown by any source stream will be forwarded to the result stream.
  ///
  /// If the source stream is a broadcast stream, the result stream will be as
  /// well, regardless of the types of [others]. If a single subscription stream
  /// is combined with a broadcast source stream, it may never be canceled.
  Stream<List<T>> combineLatestAll(Iterable<Stream<T>> others) =>
      transform(_CombineLatestAll<T>(others));
}

/// Combine the latest value from the source stream with the latest value from
/// [other] using [combine].
///
/// No event will be emitted from the result stream until both the source stream
/// and [other] have each emitted at least one event. Once both streams have
/// emitted at least one event, the result stream will emit any time either
/// input stream emits.
///
/// For example:
///     source.transform(combineLatest(other, (a, b) => a + b));
///
///   source:
///     1--2-----4
///   other:
///     ------3---
///   result:
///     ------5--7
///
/// The result stream will not close until both the source stream and [other]
/// have closed.
///
/// Errors thrown by [combine], along with any errors on the source stream or
/// [other], are forwarded to the result stream.
///
/// If the source stream is a broadcast stream, the result stream will be as
/// well, regardless of [other]'s type. If a single subscription stream is
/// combined with a broadcast stream it may never be canceled.
@Deprecated('Use the extension instead')
StreamTransformer<S, R> combineLatest<S, T, R>(
        Stream<T> other, FutureOr<R> Function(S, T) combine) =>
    _CombineLatest(other, combine);

class _CombineLatest<S, T, R> extends StreamTransformerBase<S, R> {
  final Stream<T> _other;
  final FutureOr<R> Function(S, T) _combine;

  _CombineLatest(this._other, this._combine);

  @override
  Stream<R> bind(Stream<S> source) {
    final controller = source.isBroadcast
        ? StreamController<R>.broadcast(sync: true)
        : StreamController<R>(sync: true);

    final other = (source.isBroadcast && !_other.isBroadcast)
        ? _other.asBroadcastStream()
        : _other;

    StreamSubscription<S> sourceSubscription;
    StreamSubscription<T> otherSubscription;

    var sourceDone = false;
    var otherDone = false;

    S latestSource;
    T latestOther;

    var sourceStarted = false;
    var otherStarted = false;

    void emitCombined() {
      if (!sourceStarted || !otherStarted) return;
      FutureOr<R> result;
      try {
        result = _combine(latestSource, latestOther);
      } catch (e, s) {
        controller.addError(e, s);
        return;
      }
      if (result is Future<R>) {
        sourceSubscription.pause();
        otherSubscription.pause();
        result
            .then(controller.add, onError: controller.addError)
            .whenComplete(() {
          sourceSubscription.resume();
          otherSubscription.resume();
        });
      } else {
        controller.add(result as R);
      }
    }

    controller.onListen = () {
      assert(sourceSubscription == null);
      sourceSubscription = source.listen(
          (s) {
            sourceStarted = true;
            latestSource = s;
            emitCombined();
          },
          onError: controller.addError,
          onDone: () {
            sourceDone = true;
            if (otherDone) {
              controller.close();
            } else if (!sourceStarted) {
              // Nothing can ever be emitted
              otherSubscription.cancel();
              controller.close();
            }
          });
      otherSubscription = other.listen(
          (o) {
            otherStarted = true;
            latestOther = o;
            emitCombined();
          },
          onError: controller.addError,
          onDone: () {
            otherDone = true;
            if (sourceDone) {
              controller.close();
            } else if (!otherStarted) {
              // Nothing can ever be emitted
              sourceSubscription.cancel();
              controller.close();
            }
          });
      if (!source.isBroadcast) {
        controller
          ..onPause = () {
            sourceSubscription.pause();
            otherSubscription.pause();
          }
          ..onResume = () {
            sourceSubscription.resume();
            otherSubscription.resume();
          };
      }
      controller.onCancel = () {
        var cancelSource = sourceSubscription.cancel();
        var cancelOther = otherSubscription.cancel();
        sourceSubscription = null;
        otherSubscription = null;
        return Future.wait([cancelSource, cancelOther]);
      };
    };
    return controller.stream;
  }
}

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
@Deprecated('Use the extension instead')
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

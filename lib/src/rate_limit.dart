// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'aggregate_sample.dart';
import 'from_handlers.dart';

/// Utilities to rate limit events.
///
/// - [debounce] - emit the the _first_ or _last_ event of a series of closely
///   spaced events.
/// - [debounceBuffer] - emit _all_ events at the _end_ of a series of closely
///   spaced events.
/// - [throttle] - emit the _first_ event at the _beginning_ of the period.
/// - [audit] - emit the _last_ event at the _end_ of the period.
/// - [buffer] - emit _all_ events on a _trigger_.
extension RateLimit<T> on Stream<T> {
  /// Returns a Stream which suppresses events with less inter-event spacing
  /// than [duration].
  ///
  /// Events which are emitted with less than [duration] elapsed between them
  /// are considered to be part of the same "series". If [leading] is `true`,
  /// the first event of this series is emitted immediately. If [trailing] is
  /// `true` the last event of this series is emitted with a delay of at least
  /// [duration]. By default only trailing events are emitted, both arguments
  /// must be specified with `leading: true, trailing: false` to emit only
  /// leading events.
  ///
  /// If the source stream is a broadcast stream, the result will be as well.
  /// Errors are forwarded immediately.
  ///
  /// If there is a trailing event waiting during the debounce period when the
  /// source stream closes the returned stream will wait to emit it following
  /// the debounce period before closing. If there is no pending debounced event
  /// when the source stream closes the returned stream will close immediately.
  ///
  /// For example:
  ///
  ///     source.debounce(Duration(seconds: 1));
  ///
  ///     source: 1-2-3---4---5-6-|
  ///     result: ------3---4-----6|
  ///
  ///     source.debounce(Duration(seconds: 1), leading: true, trailing: false);
  ///
  ///     source: 1-2-3---4---5-6-|
  ///     result: 1-------4---5---|
  ///
  ///     source.debounce(Duration(seconds: 1), leading: true);
  ///
  ///     source: 1-2-3---4---5-6-|
  ///     result: 1-----3-4---5---6|
  ///
  /// To collect values emitted during the debounce period see [debounceBuffer].
  Stream<T> debounce(Duration duration,
          {bool leading = false, bool trailing = true}) =>
      _debounceAggregate(duration, _dropPrevious,
          leading: leading, trailing: trailing);

  /// Returns a Stream which collects values until the source stream does not
  /// emit for [duration] then emits the collected values.
  ///
  /// Values will always be delayed by at least [duration], and values which
  /// come within this time will be aggregated into the same list.
  ///
  /// If the source stream is a broadcast stream, the result will be as well.
  /// Errors are forwarded immediately.
  ///
  /// If there are events waiting during the debounce period when the source
  /// stream closes the returned stream will wait to emit them following the
  /// debounce period before closing. If there are no pending debounced events
  /// when the source stream closes the returned stream will close immediately.
  ///
  /// To keep only the most recent event during the debounce period see
  /// [debounce].
  Stream<List<T>> debounceBuffer(Duration duration) =>
      _debounceAggregate(duration, _collect, leading: false, trailing: true);

  /// Returns a stream which only emits once per [duration], at the beginning of
  /// the period.
  ///
  /// No events will ever be emitted within [duration] of another event on the
  /// result stream.
  /// If the source stream is a broadcast stream, the result will be as well.
  /// Errors are forwarded immediately.
  ///
  /// If [trailing] is `false`, source events emitted during the [duration]
  /// period following a result event are discarded. The result stream will not
  /// emit an event until the source stream emits an event following the
  /// throttled period. If the source stream is consistently emitting events
  /// with less than [duration] between events, the time between events on the
  /// result stream may still be more than [duration]. The result stream will
  /// close immediately when the source stream closes.
  ///
  /// If [trailing] is `true`, the latest source event emitted during the
  /// [duration] period following an result event is held and emitted following
  /// the period. If the source stream is consistently emitting events with less
  /// than [duration] between events, the time between events on the result
  /// stream will be [duration]. If the source stream closes the result stream
  /// will wait to emit a pending event before closing.
  ///
  /// For example:
  ///
  ///     source.throtte(Duration(seconds: 6));
  ///
  ///     source: 1-2-3---4-5-6---7-8-|
  ///     result: 1-------4-------7---|
  ///
  ///     source.throttle(Duration(seconds: 6), trailing: true);
  ///
  ///     source: 1-2-3---4-5----6--|
  ///     result: 1-----3-----5-----6|
  ///
  ///     source.throttle(Duration(seconds: 6), trailing: true);
  ///
  ///     source: 1-2-----------3|
  ///     result: 1-----2-------3|
  Stream<T> throttle(Duration duration, {bool trailing = false}) =>
      trailing ? _throttleTrailing(duration) : _throttle(duration);

  Stream<T> _throttle(Duration duration) {
    Timer? timer;

    return transformByHandlers(onData: (data, sink) {
      if (timer == null) {
        sink.add(data);
        timer = Timer(duration, () {
          timer = null;
        });
      }
    });
  }

  Stream<T> _throttleTrailing(Duration duration) {
    Timer? timer;
    T? pending;
    var hasPending = false;
    var isDone = false;

    return transformByHandlers(onData: (data, sink) {
      void onTimer() {
        if (hasPending) {
          sink.add(pending as T);
          if (isDone) {
            sink.close();
          } else {
            timer = Timer(duration, onTimer);
            hasPending = false;
            pending = null;
          }
        } else {
          timer = null;
        }
      }

      if (timer == null) {
        sink.add(data);
        timer = Timer(duration, onTimer);
      } else {
        hasPending = true;
        pending = data;
      }
    }, onDone: (sink) {
      isDone = true;
      if (hasPending) return; // Will be closed by timer.
      sink.close();
      timer?.cancel();
      timer = null;
    });
  }

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
    Timer? timer;
    var shouldClose = false;
    T recentData;

    return transformByHandlers(onData: (data, sink) {
      recentData = data;
      timer ??= Timer(duration, () {
        sink.add(recentData);
        timer = null;
        if (shouldClose) {
          sink.close();
        }
      });
    }, onDone: (sink) {
      if (timer != null) {
        shouldClose = true;
      } else {
        sink.close();
      }
    });
  }

  /// Buffers the values emitted on this stream and emits them when [trigger]
  /// emits an event.
  ///
  /// If [longPoll] is `false`, if there are no buffered values when [trigger]
  /// emits an empty list is immediately emitted.
  ///
  /// If [longPoll] is `true`, and there are no buffered values when [trigger]
  /// emits one or more events, then the *next* value from this stream is
  /// immediately emitted on the returned stream as a single element list.
  /// Subsequent events on [trigger] while there have been no events on this
  /// stream are ignored.
  ///
  /// The result stream will close as soon as there is a guarantee it will not
  /// emit any more events. There will not be any more events emitted if:
  /// - [trigger] is closed and there is no waiting long poll.
  /// - Or, the source stream is closed and previously buffered events have been
  /// delivered.
  ///
  /// If the source stream is a broadcast stream, the result will be as well.
  /// Errors from the source stream or the trigger are immediately forwarded to
  /// the output.
  ///
  /// See also:
  /// - [sample] which use a [trigger] stream in the same way, but keeps only
  /// the most recent source event.
  Stream<List<T>> buffer(Stream<void> trigger, {bool longPoll = true}) =>
      aggregateSample(
          trigger: trigger,
          aggregate: _collect,
          longPoll: longPoll,
          onEmpty: _empty);

  /// Creates a stream which emits the most recent new value from the source
  /// stream when it sees a value on [trigger].
  ///
  /// If [longPoll] is `false`, then an event on [trigger] when there is no
  /// pending source event will be ignored.
  /// If [longPoll] is `true` (the default), then an event on [trigger] when
  /// there is no pending source event will cause the next source event
  /// to immediately flow to the result stream.
  ///
  /// If [longPoll] is `false`, if there is no pending source event when
  /// [trigger] emits, then the trigger event will be ignored.
  ///
  /// If [longPoll] is `true`, and there are no buffered values when [trigger]
  /// emits one or more events, then the *next* value from this stream is
  /// immediately emitted on the returned stream as a single element list.
  /// Subsequent events on [trigger] while there have been no events on this
  /// stream are ignored.
  ///
  /// The result stream will close as soon as there is a guarantee it will not
  /// emit any more events. There will not be any more events emitted if:
  /// - [trigger] is closed and there is no waiting long poll.
  /// - Or, the source stream is closed and any pending source event has been
  /// delivered.
  ///
  /// If the source stream is a broadcast stream, the result will be as well.
  /// Errors from the source stream or the trigger are immediately forwarded to
  /// the output.
  ///
  /// See also:
  /// - [buffer] which use [trigger] stream in the same way, but keeps a list of
  /// pending source events.
  Stream<T> sample(Stream<void> trigger, {bool longPoll = true}) =>
      aggregateSample(
          trigger: trigger,
          aggregate: _dropPrevious,
          longPoll: longPoll,
          onEmpty: _ignore);

  /// Aggregates values until the source stream does not emit for [duration],
  /// then emits the aggregated values.
  Stream<S> _debounceAggregate<S>(
      Duration duration, S Function(T element, S? soFar) collect,
      {required bool leading, required bool trailing}) {
    Timer? timer;
    S? soFar;
    var hasPending = false;
    var shouldClose = false;
    var emittedLatestAsLeading = false;

    return transformByHandlers(onData: (value, sink) {
      void emit() {
        sink.add(soFar as S);
        soFar = null;
        hasPending = false;
      }

      timer?.cancel();
      soFar = collect(value, soFar);
      hasPending = true;
      if (timer == null && leading) {
        emittedLatestAsLeading = true;
        emit();
      } else {
        emittedLatestAsLeading = false;
      }
      timer = Timer(duration, () {
        if (trailing && !emittedLatestAsLeading) emit();
        if (shouldClose) sink.close();
        timer = null;
      });
    }, onDone: (EventSink<S> sink) {
      if (hasPending && trailing) {
        shouldClose = true;
      } else {
        timer?.cancel();
        sink.close();
      }
    });
  }
}

T _dropPrevious<T>(T element, _) => element;
List<T> _collect<T>(T event, List<T>? soFar) => (soFar ?? <T>[])..add(event);
void _empty<T>(Sink<List<T>> sink) => sink.add([]);
void _ignore<T>(Sink<T> sink) {}

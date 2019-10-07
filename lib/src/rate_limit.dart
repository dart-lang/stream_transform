// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'aggregate_sample.dart';
import 'from_handlers.dart';

/// Utilities to rate limit events.
///
/// - [debounce] - emit the _first_ event at the _end_ of the period.
/// - [debounceBuffer] - emit _all_ events at the _end_ of the period.
/// - [throttle] - emit the _first_ event at the _beginning_ of the period.
/// - [audit] - emit the _last_ event at the _end_ of the period.
/// - [buffer] - emit _all_ events on a _trigger_.
extension RateLimit<T> on Stream<T> {
  /// Returns a Stream which only emits when the source stream does not emit for
  /// [duration].
  ///
  /// Values will always be delayed by at least [duration], and values which
  /// come within this time will replace the old values, only the most
  /// recent value will be emitted.
  ///
  /// If the source stream is a broadcast stream, the result will be as well.
  /// Errors are forwarded immediately.
  ///
  /// If there is an event waiting during the debounce period when the source
  /// stream closes the returned stream will wait to emit it following the
  /// debounce period before closing. If there is no pending debounced event
  /// when the source stream closes the returned stream will close immediately.
  ///
  /// To collect values emitted during the debounce period see [debounceBuffer].
  Stream<T> debounce(Duration duration) =>
      transform(_debounceAggregate(duration, _dropPrevious));

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
  /// To keep only the most recent event during the debounce perios see
  /// [debounce].
  Stream<List<T>> debounceBuffer(Duration duration) =>
      transform(_debounceAggregate(duration, _collectToList));

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

  /// Returns a Stream  which collects values and emits when it sees a value on
  /// [trigger].
  ///
  /// If there are no pending values when [trigger] emits, the next value on the
  /// source Stream will immediately flow through. Otherwise, the pending values
  /// are released when [trigger] emits.
  ///
  /// If the source stream is a broadcast stream, the result will be as well.
  /// Errors from the source stream or the trigger are immediately forwarded to
  /// the output.
  Stream<List<T>> buffer(Stream<void> trigger) =>
      transform(AggregateSample<T, List<T>>(trigger, _collect));
}

/// Creates a StreamTransformer which only emits when the source stream does not
/// emit for [duration].
///
/// Source values will always be delayed by at least [duration], and values
/// which come within this time will replace the old values, only the most
/// recent value will be emitted.
@Deprecated('Use the extension instead')
StreamTransformer<T, T> debounce<T>(Duration duration) =>
    _debounceAggregate(duration, _dropPrevious);

/// Creates a StreamTransformer which collects values until the source stream
/// does not emit for [duration] then emits the collected values.
///
/// This differs from [debounce] in that values are aggregated instead of
/// skipped.
@Deprecated('Use the extension instead')
StreamTransformer<T, List<T>> debounceBuffer<T>(Duration duration) =>
    _debounceAggregate(duration, _collectToList);

List<T> _collectToList<T>(T element, List<T> soFar) {
  soFar ??= <T>[];
  soFar.add(element);
  return soFar;
}

T _dropPrevious<T>(T element, _) => element;

/// Creates a StreamTransformer which aggregates values until the source stream
/// does not emit for [duration], then emits the aggregated values.
StreamTransformer<T, R> _debounceAggregate<T, R>(
    Duration duration, R collect(T element, R soFar)) {
  Timer timer;
  R soFar;
  var shouldClose = false;
  return fromHandlers(handleData: (T value, EventSink<R> sink) {
    timer?.cancel();
    timer = Timer(duration, () {
      sink.add(soFar);
      if (shouldClose) {
        sink.close();
      }
      soFar = null;
      timer = null;
    });
    soFar = collect(value, soFar);
  }, handleDone: (EventSink<R> sink) {
    if (soFar != null) {
      shouldClose = true;
    } else {
      sink.close();
    }
  });
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

/// Creates a [StreamTransformer] which collects values and emits when it sees a
/// value on [trigger].
///
/// If there are no pending values when [trigger] emits, the next value on the
/// source Stream will immediately flow through. Otherwise, the pending values
/// are released when [trigger] emits.
///
/// Errors from the source stream or the trigger are immediately forwarded to
/// the output.
@Deprecated('Use the extension instead')
StreamTransformer<T, List<T>> buffer<T>(Stream<void> trigger) =>
    AggregateSample<T, List<T>>(trigger, _collect);

List<T> _collect<T>(T event, List<T> soFar) => (soFar ?? <T>[])..add(event);

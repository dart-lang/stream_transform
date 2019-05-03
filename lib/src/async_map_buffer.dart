// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'aggregate_sample.dart';
import 'buffer.dart';
import 'chain_transformers.dart';
import 'from_handlers.dart';

/// Like [Stream.asyncMap] but events are buffered until previous events have
/// been processed by [convert].
///
/// If the source stream is a broadcast stream the result will be as well. When
/// used with a broadcast stream behavior also differs from [Stream.asyncMap] in
/// that the [convert] function is only called once per event, rather than once
/// per listener per event.
///
/// The first event from the source stream is always passed to [convert] as a
/// List with a single element. After that events are buffered until the
/// previous Future returned from [convert] has fired.
///
/// Errors from the source stream are forwarded directly to the result stream.
/// Errors during the conversion are also forwarded to the result stream and are
/// considered completing work so the next values are let through.
///
/// The result stream will not close until the source stream closes and all
/// pending conversions have finished.
StreamTransformer<S, T> asyncMapBuffer<S, T>(
    Future<T> Function(List<S>) convert) {
  var workFinished = StreamController<void>()
    // Let the first event through.
    ..add(null);
  return chainTransformers(
      buffer(workFinished.stream), _asyncMapThen(convert, workFinished.add));
}

/// Like [Stream.asyncMap] but events are discarded while work is happening in
/// [convert].
///
/// If the source stream is a broadcast stream the result will be as well. When
/// used with a broadcast stream behavior also differs from [Stream.asyncMap] in
/// that the [convert] function is only called once per event, rather than once
/// per listener per event.
///
/// If no work is happening when an event is emitted it will be immediately
/// passed to [convert]. If there is ongoing work when an event is emitted it
/// will be held until the work is finished. New events emitted will replace a
/// pending event.
///
/// Errors from the source stream are forwarded directly to the result stream.
/// Errors during the conversion are also forwarded to the result stream and are
/// considered completing work so the next values are let through.
///
/// The result stream will not close until the source stream closes and all
/// pending conversions have finished.
StreamTransformer<S, T> asyncMapSample<S, T>(Future<T> Function(S) convert) {
  var workFinished = StreamController<void>()
    // Let the first event through.
    ..add(null);
  return chainTransformers(AggregateSample(workFinished.stream, _dropPrevious),
      _asyncMapThen(convert, workFinished.add));
}

T _dropPrevious<T>(T event, _) => event;

/// Like [Stream.asyncMap] but the [convert] is only called once per event,
/// rather than once per listener, and [then] is called after completing the
/// work.
StreamTransformer<S, T> _asyncMapThen<S, T>(
    Future<T> convert(S event), void Function(void) then) {
  Future<void> pendingEvent;
  return fromHandlers(handleData: (event, sink) {
    pendingEvent =
        convert(event).then(sink.add).catchError(sink.addError).then(then);
  }, handleDone: (sink) {
    if (pendingEvent != null) {
      pendingEvent.then((_) => sink.close());
    } else {
      sink.close();
    }
  });
}

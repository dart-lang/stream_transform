// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';

/// Cycle the event loop to ensure timers are started, then wait for a delay
/// longer than [milliseconds] to allow for the timer to fire.
Future<void> waitForTimer(int milliseconds) =>
    Future(() {/* ensure Timer is started*/})
        .then((_) => Future.delayed(Duration(milliseconds: milliseconds + 1)));

StreamController<T> createController<T>(String streamType) {
  switch (streamType) {
    case 'single subscription':
      return StreamController<T>();
    case 'broadcast':
      return StreamController<T>.broadcast();
    default:
      throw ArgumentError.value(
          streamType, 'streamType', 'Must be one of $streamTypes');
  }
}

const streamTypes = ['single subscription', 'broadcast'];

class NullOnCancelStream<T> extends StreamView<T> {
  final Stream<T> _stream;

  NullOnCancelStream(this._stream) : super(_stream);

  @override
  StreamSubscription<T> listen(void Function(T) onData,
          {Function onError, void Function() onDone, bool cancelOnError}) =>
      _NullOnCancelSubscription(_stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError));
}

class _NullOnCancelSubscription<T> extends DelegatingStreamSubscription<T> {
  final StreamSubscription<T> _subscription;
  _NullOnCancelSubscription(this._subscription) : super(_subscription);

  @override
  Future<void> cancel() {
    _subscription.cancel();
    return null;
  }
}

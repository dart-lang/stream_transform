// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'aggregate_sample.dart';

/// Creates a [StreamTransformer] which collects values and emits when it sees a
/// value on [trigger].
///
/// If there are no pending values when [trigger] emits, the next value on the
/// source Stream will immediately flow through. Otherwise, the pending values
/// are released when [trigger] emits.
///
/// Errors from the source stream or the trigger are immediately forwarded to
/// the output.
StreamTransformer<T, List<T>> buffer<T>(Stream<void> trigger) =>
    AggregateSample<T, List<T>>(trigger, _collect);

List<T> _collect<T>(T event, List<T> soFar) => (soFar ?? <T>[])..add(event);

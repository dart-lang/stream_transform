// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'bind.dart';

/// Models a [Stream.map] callback as a [StreamTransformer].
///
/// This is most useful to pass to functions that take a [StreamTransformer]
/// other than [Stream.transform]. For inline uses [Stream.map] should be
/// preferred.
///
/// For example:
///
/// ```
/// final sinkMapper = new StreamSinkTransformer.fromStreamTransformer(
///     forMap((v) => '$v'));
/// ```
StreamTransformer<S, T> forMap<S, T>(T map(S event)) =>
    fromBind((stream) => stream.map(map));

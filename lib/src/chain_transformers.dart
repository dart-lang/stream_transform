// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'bind.dart';

/// Combines two transformers into one.
///
/// This is most useful to keep a reference to the combination and use it in
/// multiple places or give it a descriptive name. For inline uses the directly
/// chained calls to `.transform` should be preferred.
///
/// For example:
///
/// ```
/// /// values.transform(splitDecoded) is identical to
/// /// values.transform(utf8.decoder).transform(const LineSplitter())
/// final splitDecoded = chainTransformers(utf8.decoder, const LineSplitter());
/// ```
StreamTransformer<S, T> chainTransformers<S, I, T>(
        StreamTransformer<S, I> first, StreamTransformer<I, T> second) =>
    fromBind((values) => values.transform(first).transform(second));

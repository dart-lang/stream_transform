// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

import 'followed_by.dart';

@Deprecated('Use followedBy instead')
StreamTransformer<T, T> concat<T>(Stream<T> next) => followedBy<T>(next);

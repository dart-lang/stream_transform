// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'switch.dart';

/// Alternatives to [asyncExpand].
///
/// The built in [asyncExpand] will not overlap the inner streams and every
/// event will be sent to the callback individually.
///
/// - [concurrentAsyncExpand] allow overlap and merges inner streams without
///   ordering guarantees.
extension AsyncExpand<T> on Stream<T> {
  /// Like [asyncExpand] but the [convert] callback may be called for an element
  /// before the [Stream] emitted by the previous element has closed.
  ///
  /// Events on the result stream will be emitted in the order they are emitted
  /// by the sub streams, which may not match the order of this stream.
  ///
  /// Errors from [convert], the source stream, or any of the sub streams are
  /// forwarded to the result stream.
  ///
  /// The result stream will not close until the source stream closes and all
  /// sub streams have closed.
  ///
  /// If the source stream is a broadcast stream, the result will be as well,
  /// regardless of the types of streams created by [convert]. In this case,
  /// some care should be taken:
  /// -  The source stream will be immediately listened to, regardless of
  /// whether the result stream ever gets a listener, and this subscription will
  /// never be canceled, even if all subscriptions on the result stream are
  /// canceled.
  /// -  If [convert] returns a single subscription stream while the result
  /// stream has no listener it will be immediately listened to, and may be
  /// drained without any events reaching a listener on the result stream. Only
  /// events emitted by the inner stream _after_ a listen starts on the result
  /// stream will be forwarded.
  /// -  If [convert] returns a single subscription stream it will be listened
  /// to and never canceled, even if all subscriptions on the result stream are
  /// canceled.
  ///
  /// See also:
  /// - [switchMap], which cancels subscriptions to the previous sub stream
  /// instead of concurrently emitting events from all sub streams.
  Stream<S> concurrentAsyncExpand<S>(Stream<S> Function(T) convert) {
    final controller = isBroadcast
        ? StreamController<S>.broadcast(sync: true)
        : StreamController<S>(sync: true);

    StreamSubscription<Stream<S>>? outerSubscription;
    var hasActiveListener = !isBroadcast;
    final subscriptions =
        LinkedHashMap<Stream<S>, StreamSubscription<S>?>.identity();
    void listen(Stream<S> stream) {
      if (!hasActiveListener && stream.isBroadcast) {
        // onListen will start the subscription when the result gets a listener
        subscriptions[stream] = null;
      } else {
        // immediately listen to single subscription streams even when there is
        // no listener on the result stream. Adding to the controller will have
        // no effect while the result has no listener.
        subscriptions[stream] =
            stream.listen(controller.add, onError: controller.addError)
              ..onDone(() {
                subscriptions.remove(stream);
                if (outerSubscription == null && subscriptions.isEmpty) {
                  controller.close();
                }
              });
      }
    }

    StreamSubscription<Stream<S>> listenOuter() {
      assert(outerSubscription == null);
      return outerSubscription =
          map(convert).listen(listen, onError: controller.addError, onDone: () {
        outerSubscription = null;
        if (subscriptions.isEmpty) controller.close();
      });
    }

    if (isBroadcast) listenOuter();

    controller.onListen = () {
      assert(isBroadcast || subscriptions.isEmpty);
      hasActiveListener = true;
      for (final stream in subscriptions.keys) {
        if (stream.isBroadcast) {
          listen(stream);
        }
      }
      if (!isBroadcast) {
        final subscription = listenOuter();
        controller
          ..onPause = () {
            subscription.pause();
            for (final subscription in subscriptions.values) {
              subscription?.pause();
            }
          }
          ..onResume = () {
            subscription.resume();
            for (final subscription in subscriptions.values) {
              subscription?.resume();
            }
          };
      }
      controller.onCancel = () {
        hasActiveListener = false;
        final cancels = {
          // Don't cancel outer stream for broadcast streams because it would
          // make which substreams exist depend on whether a listener existed
          // when the event was emitted.
          if (!isBroadcast && outerSubscription != null)
            outerSubscription!.cancel(),
          for (var entry in subscriptions.entries)
            if ((!isBroadcast || entry.key.isBroadcast) && entry.value != null)
              entry.value!.cancel()
        }
          // Handle opt-out nulls
          ..removeWhere((Object? f) => f == null);
        if (cancels.isEmpty) return null;
        return Future.wait(cancels).then((_) => null);
      };
    };
    return controller.stream;
  }
}

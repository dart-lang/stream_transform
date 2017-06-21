import 'dart:async';

typedef void HandleData<S, T>(S value, EventSink<T> sink);
typedef void HandleDone<T>(EventSink<T> sink);

/// Like [new StreamTransformer.fromHandlers] but the handlers are called once
/// per event rather than once per listener for broadcast streams.
StreamTransformer<S, T> fromHandlers<S, T>(
        {HandleData<S, T> handleData, HandleDone<T> handleDone}) =>
    new _StreamTransformer(handleData: handleData, handleDone: handleDone);

class _StreamTransformer<S, T> implements StreamTransformer<S, T> {
  final HandleData<S, T> _handleData;
  final HandleDone<T> _handleDone;

  _StreamTransformer({HandleData<S, T> handleData, HandleDone<T> handleDone})
      : _handleData = handleData ?? _defaultHandleData,
        _handleDone = handleDone ?? _defaultHandleDone;

  static _defaultHandleData<S, T>(S value, EventSink<T> sink) {
    sink.add(value as T);
  }

  static _defaultHandleDone<T>(EventSink<T> sink) {
    sink.close();
  }

  @override
  Stream<T> bind(Stream<S> values) {
    StreamController<T> controller;
    if (values.isBroadcast) {
      controller = new StreamController<T>.broadcast();
    } else {
      controller = new StreamController<T>();
    }
    StreamSubscription<S> subscription;
    controller.onListen = () {
      if (subscription != null) {
        return;
      }
      subscription = values.listen((value) => _handleData(value, controller),
          onError: controller.addError, onDone: () {
        _handleDone(controller);
      });
    };
    if (!values.isBroadcast) {
      controller.onPause = () => subscription?.pause();
      controller.onResume = () => subscription?.resume();
    }
    controller.onCancel = () {
      if (controller.hasListener || subscription == null) {
        return new Future.value();
      }
      var toCancel = subscription;
      subscription = null;
      return toCancel.cancel();
    };
    return controller.stream;
  }
}

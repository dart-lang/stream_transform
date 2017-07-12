import 'dart:async';

/// Matches [StreamTransformer.bind].
typedef Stream<T> Bind<S, T>(Stream<S> values);

/// Creates a [StreamTransformer] which overrides [StreamTransformer.bind] to
/// [bindFn].
StreamTransformer<S, T> fromBind<S, T>(Bind<S, T> bindFn) =>
    new _StreamTransformer(bindFn);

class _StreamTransformer<S, T> implements StreamTransformer<S, T> {
  final Bind<S, T> _bind;

  _StreamTransformer(this._bind);

  @override
  Stream<T> bind(Stream<S> values) => _bind(values);
}

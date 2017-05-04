import 'package:test/test.dart';

/// Matches [Iterable]s which contain an element matching every value in
/// [expected] in the same order, but may contain additional values interleaved
/// throughout.
Matcher containsAllInOrder(Iterable expected) =>
    new _ContainsAllInOrder(expected);

class _ContainsAllInOrder implements Matcher {
  final Iterable _expected;

  _ContainsAllInOrder(this._expected);

  String _test(item, Map matchState) {
    if (item is! Iterable) return 'not iterable';
    var matchers = _expected.map(wrapMatcher).toList();
    var matcherIndex = 0;
    for (var value in item) {
      if (matchers[matcherIndex].matches(value, matchState)) matcherIndex++;
      if (matcherIndex == matchers.length) return null;
    }
    return new StringDescription()
        .add('did not find a value matching ')
        .addDescriptionOf(matchers[matcherIndex])
        .add(' following expected prior values')
        .toString();
  }

  @override
  bool matches(item, Map matchState) => _test(item, matchState) == null;

  @override
  Description describe(Description description) => description
      .add('contains in order(')
      .addDescriptionOf(_expected)
      .add(')');

  @override
  Description describeMismatch(item, Description mismatchDescription,
          Map matchState, bool verbose) =>
      mismatchDescription.add(_test(item, matchState));
}

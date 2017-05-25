# What problem does this package solve?

The aim of `package:stream_transform` is to:
- Reduce duplication of commonly (re)implemented utilities.
- Cover edge cases (stream closing, broadcast vs single-subscription) with
  consistent quality.
- Provide building blocks rather than specialized APIs.

# What should be included?

This package implements similar concepts to some found in `Rx` libraries, but
without limiting implementation to 100% semantic compatibility. Rx has a very
large surface area - to keep focus we should have a high bar for inclusion:

- Only concepts that can be implemented with a `StreamTransformer`
- Only concepts that have empirical demand in Dart. "`Observable` has this" may
  not be enough to warrant an implementation here, but "this would be useful in
  `package:foo`" is.
- Concepts that are trivially implemented by composing existing concepts in this
  package, or on `Stream` usually should not be reimplemented for the sake of a
  familiar name. For example `ignoreElements` would most often be accomplished
  with an empty listener and an `onDone` handler.

# What should the API look like?

The public surface area for the package should be almost entirely top-level
methods which return a `StreamTransformer`. We should avoid public `typedef`s
and prefer instead to define function signatures in the argument lists.
Exceptions may be necessary for some APIs - if this package needed to implement
`groupBy` it might need a class definition for the result.

We should limit concepts to the most commonly useful variant rather than add
multiple implementations or add optional configuration arguments. If there are
multiple commonly used similar concepts we should prefer multiple
implementations over configuration arguments.

When a concept is similar to something which exist in the Dart SDK we should use
similar naming and argument ordering.

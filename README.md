Utility methods to create `StreamTransfomer` instances to manipulate Streams.

# asyncMapBuffer

Like `asyncMap` but events are buffered in a List until previous events have
been processed rather than being called for each element individually.

# asyncMapSample

Like `asyncMap` but events are discarded, keeping only the latest, until
previous events have been processed rather than being called for every element.

# asyncWhere

Like `where` but allows an asynchronous predicate.

# audit

Audit waits for a period of time after receiving a value and then only emits
the most recent value.

# buffer

Collects values from a source stream until a `trigger` stream fires and the
collected values are emitted.

# combineLatest

Combine the most recent event from two streams through a callback and emit the
result.

# combineLatestAll

Combines the latest events emitted from multiple source streams and yields a
list of the values.

# debounce, debounceBuffer

Prevents a source stream from emitting too frequently by dropping or collecting
values that occur within a given duration.

# concurrentAsyncMap

Like `asyncMap` but the convert callback can be called with subsequent values
before it has finished for previous values.

# followedBy

Appends the values of a stream after another stream finishes.

# merge, mergeAll

Interleaves events from multiple streams into a single stream.

# scan

Scan is like fold, but instead of producing a single value it yields each
intermediate accumulation.

# startWith, startWithMany, startWithStream

Prepend a value, an iterable, or a stream to the beginning of another stream.

# switchMap, switchLatest

Flatten a Stream of Streams into a Stream which forwards values from the most
recent Stream

# takeUntil

Let values through until a Future fires.

# tap

Taps into a single-subscriber stream to react to values as they pass, without
being a real subscriber.

# throttle

Blocks events for a duration after an event is successfully emitted.

# whereType

Like `Iterable.whereType` for a stream.

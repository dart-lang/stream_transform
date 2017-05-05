Contains utility methods to create `StreamTransfomer` instances to manipulate
Streams.

# buffer

Collects values from a source stream until a `trigger` stream fires and the
collected values are emitted.

# concat

Appends the values of a stream after another stream finishes.

# debounce, debounceBuffer

Prevents a source stream from emitting too frequently by dropping or collecting
values that occur within a given duration.

# merge, mergeAll

Interleaves events from multiple streams into a single stream.

## 0.0.3

- Add `tap`: React to values as they pass without being a subscriber on a stream
- Add `switchMap` and `switchLatest`: Flatten a Stream of Streams into a Stream
  which forwards values from the most recent Stream

## 0.0.2

- Add `concat`: Appends streams in series
- Add `merge` and `mergeAll`: Interleaves streams

## 0.0.1

- Initial release with the following utilities:
  - `buffer`: Collects events in a `List` until a `trigger` stream fires.
  - `debounce`, `debounceBuffer`: Collect or drop events which occur closer in
    time than a given duration.

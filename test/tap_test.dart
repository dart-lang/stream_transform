import 'package:test/test.dart';
import 'dart:async';

import 'package:stream_transform/stream_transform.dart';

void main() {
  test('calls function for values', () async {
    var valuesSeen = [];
    var stream = new Stream.fromIterable([1, 2, 3]);
    await stream.transform(tap(valuesSeen.add)).last;
    expect(valuesSeen, [1, 2, 3]);
  });

  test('forwards values', () async {
    var stream = new Stream.fromIterable([1, 2, 3]);
    var values = await stream.transform(tap((_) {})).toList();
    expect(values, [1, 2, 3]);
  });

  test('calls function for errors', () async {
    var error;
    var source = new StreamController();
    source.stream
        .transform(tap((_) {}, onError: (e, st) {
          error = e;
        }))
        .listen((_) {}, onError: (_) {});
    source.addError('error');
    await new Future(() {});
    expect(error, 'error');
  });

  test('forwards errors', () async {
    var error;
    var source = new StreamController();
    source.stream.transform(tap((_) {}, onError: (e, st) {})).listen((_) {},
        onError: (e) {
      error = e;
    });
    source.addError('error');
    await new Future(() {});
    expect(error, 'error');
  });

  test('calls function on done', () async {
    var doneCalled = false;
    var source = new StreamController();
    source.stream
        .transform((tap((_) {}, onDone: () {
          doneCalled = true;
        })))
        .listen((_) {});
    await source.close();
    expect(doneCalled, true);
  });
}

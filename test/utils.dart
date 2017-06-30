import 'dart:async';

/// Cycle the event loop to ensure timers are started, then wait for a delay
/// longer than [milliseconds] to allow for the timer to fire.
Future waitForTimer(int milliseconds) =>
    new Future(() {/* ensure Timer is started*/}).then((_) =>
        new Future.delayed(new Duration(milliseconds: milliseconds + 1)));

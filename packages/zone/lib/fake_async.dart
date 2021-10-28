
import 'dart:async';
import 'dart:collection';
import 'package:clock/clock.dart';
import 'package:collection/collection.dart';


typedef Task = void Function();

class FakeAsync {

  FakeAsync({ DateTime? initialTime }) {
    final _initialTime = initialTime ?? clock.now();
    _clock = Clock(() => _initialTime.add(passed));
  }

  late final Clock _clock;

  Duration _passed = Duration.zero;
  Duration get passed => _passed;
  void _setPassed(Duration passed) {
    if (passed > _passed) _passed = passed;
  }

  Duration? _target;

  final Queue<Task> _microtasks = Queue();

  final Set<FakeTimer> _timers = {};

  List<FakeTimer> get timers => _timers.toList(growable: false);

  List<String> get timerDebugStrings =>
    timers.map((timer) => timer.debugString).toList(growable: false);

  int get periodicTimerCount =>
    _timers.where((timer) => timer.isPeriodic).length;

  int get nonPeriodicTimerCount =>
    _timers.where((timer) => !timer.isPeriodic).length;

  int get microtaskCount => _microtasks.length;

  void advance(Duration duration) {
    if (duration.inMicroseconds < 0) {
      throw ArgumentError.value(duration, 'duration', 'may not be negative');
    }
    if (_target != null) {
      throw StateError('Cannot advance if previous advance is not completed.');
    }

    final target = _passed + duration;
    _target = target;
    _flowTo(target);
    _setPassed(target);
    _target = null;
  }

  void _flowTo(Duration target) {
    _flushMicrotasks();
    while (true) {
      final nextTimer = minBy(_timers, (FakeTimer timer) => timer._nextCall);
      if (nextTimer == null || nextTimer._nextCall > target) break;
      _setPassed(nextTimer._nextCall);
      nextTimer._fire();
      _flushMicrotasks();
    }
  }

  void _flushMicrotasks() {
    while (_microtasks.isNotEmpty) {
      _microtasks.removeFirst().call();
    }
  }

  T run<T>(T Function(FakeAsync) callback) =>
    runZoned(
      () => withClock(_clock, () => callback(this)),
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) => 
          _createTimer(duration, callback, false),
        createPeriodicTimer: (self, parent, zone, duration, callback) => 
          _createTimer(duration, callback, true),
        scheduleMicrotask: (self, parent, zone, microtask) => 
          _microtasks.add(microtask),
      )
    );
  
  Timer _createTimer(Duration duration, Function callback, bool isPeriodic) {
    final timer = FakeTimer._(duration, callback, isPeriodic, this);
    _timers.add(timer);
    return timer;
  }
}


class FakeTimer implements Timer {

  FakeTimer._(Duration duration, this._callback, this.isPeriodic, this._async)
    : duration = duration < Duration.zero ? Duration.zero : duration {
      _nextCall = _async._passed + this.duration;
    }

  final Duration duration;

  final Function _callback;

  final bool isPeriodic;

  final FakeAsync _async;

  late Duration _nextCall;

  final creationStackTrace = StackTrace.current;

  String get debugString =>
    'Timer (duration: $duration, periodic: $isPeriodic), created: \n'
    '$creationStackTrace';

  @override
  int get tick => throw UnimplementedError('tick');

  @override
  bool get isActive => _async._timers.contains(this);
  
  @override
  void cancel() => _async._timers.remove(this);

  void _fire() {
    assert(isActive);
    if (isPeriodic) {
      _callback(this);
      _nextCall += duration;
    } else {
      cancel();
      _callback();
    }
  }
}
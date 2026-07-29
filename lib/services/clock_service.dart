abstract class ClockService {
  DateTime get now;
}

class SystemClock implements ClockService {
  const SystemClock();

  @override
  DateTime get now => DateTime.now().toUtc();
}

class TestClock implements ClockService {
  DateTime _current;

  TestClock(DateTime initial) : _current = initial.toUtc();

  @override
  DateTime get now => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }

  void setTime(DateTime time) {
    _current = time.toUtc();
  }
}

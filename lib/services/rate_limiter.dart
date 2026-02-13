class RateLimiter {
  final int maxPerMinute;
  final int maxPerHour;

  final List<DateTime> _requests = [];

  RateLimiter({
    this.maxPerMinute = 6,
    this.maxPerHour = 60,
  });

  void check() {
    final now = DateTime.now();
    _requests.removeWhere((t) => now.difference(t).inHours >= 1);

    final minuteWindow = _requests
        .where((t) => now.difference(t).inMinutes < 1)
        .toList();
    if (minuteWindow.length >= maxPerMinute) {
      final oldest = minuteWindow.first;
      final wait = 60 - now.difference(oldest).inSeconds;
      throw StateError('Rate limit reached. Try again in ${wait}s.');
    }

    if (_requests.length >= maxPerHour) {
      final oldest = _requests.first;
      final wait = 3600 - now.difference(oldest).inSeconds;
      throw StateError('Hourly limit reached. Try again in ${wait}s.');
    }

    _requests.add(now);
  }
}

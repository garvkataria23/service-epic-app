import 'dart:async';
import 'package:flutter/foundation.dart';

/// Debounces rapid user input (such as smart search typing) to avoid
/// unnecessary recomputations or API calls.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 220)});

  final Duration delay;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

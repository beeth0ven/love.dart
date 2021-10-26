
import 'dart:async';

// import 'package:fake_async/fake_async.dart';

void main() {
  runZoned(() async {
    print('start ${DateTime.now()}');
    await Future<void>.delayed(Duration(seconds: 10));
    print('end ${DateTime.now()}');
  }, zoneSpecification: ZoneSpecification(
    createTimer: (self, parent, zone, duration, f) {
      return Zone.root.createTimer(Duration(seconds: 3), f);
    },
  ));
}
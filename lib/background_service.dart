import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/widgets.dart';

@pragma('vm:entry-point')
void backgroundServiceStart(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 10), (timer) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "ImpactNode Active",
        content: "Monitoring for crashes",
      );
    }
  });
}

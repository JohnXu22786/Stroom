import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

const _serviceName = 'com.johntsui.stroom.background_service';
const _serviceTitle = 'Stroom';
const _serviceContent = '后台任务运行中…';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: _serviceName,
      initialNotificationTitle: _serviceTitle,
      initialNotificationContent: _serviceContent,
      foregroundServiceNotificationId: 4521,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  Timer? _timer;
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((_) {
      _timer?.cancel();
      service.stopSelf();
    });
  }

  _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: _serviceTitle,
        content: _serviceContent,
      );
    }
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

Future<void> startBackgroundService() async {
  final service = FlutterBackgroundService();
  if (!await service.isRunning()) {
    await service.startService();
  }
}

Future<void> stopBackgroundService() async {
  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    service.invoke('stopService');
  }
}

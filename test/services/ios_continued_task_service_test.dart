import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/services/ios_continued_task_service.dart';

/// 记录 iOS 常驻任务通道的调用。
final channelCalls = <MethodCall>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channelCalls.clear();
    IosContinuedTaskService.debugForceSupported = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.johntsui.stroom/ios_continued_task'),
      (MethodCall call) async {
        channelCalls.add(call);
        return null;
      },
    );
  });

  tearDown(() {
    IosContinuedTaskService.debugForceSupported = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.johntsui.stroom/ios_continued_task'),
      null,
    );
  });

  group('IosContinuedTaskService', () {
    test('isSupported is false on non-iOS platforms by default', () {
      // 测试机为 Windows/macOS 主机，Platform.isIOS 为 false。
      expect(IosContinuedTaskService.instance.isSupported, isFalse);
    });

    test('debugForceSupported enables the bridge for tests', () {
      IosContinuedTaskService.debugForceSupported = true;
      expect(IosContinuedTaskService.instance.isSupported, isTrue);
    });

    test('no channel calls are made when not supported', () async {
      final service = IosContinuedTaskService.instance;
      await service.submit();
      await service.updateProgress(50);
      await service.complete();
      expect(channelCalls, isEmpty);
    });

    test('submit sends the title argument', () async {
      IosContinuedTaskService.debugForceSupported = true;
      await IosContinuedTaskService.instance.submit(title: '任务运行中');
      expect(channelCalls.length, 1);
      expect(channelCalls.first.method, 'submit');
      expect(channelCalls.first.arguments, {'title': '任务运行中'});
    });

    test('updateProgress sends the percent argument', () async {
      IosContinuedTaskService.debugForceSupported = true;
      await IosContinuedTaskService.instance.updateProgress(66);
      expect(channelCalls.length, 1);
      expect(channelCalls.first.method, 'updateProgress');
      expect(channelCalls.first.arguments, {'percent': 66});
    });

    test('complete sends the complete method', () async {
      IosContinuedTaskService.debugForceSupported = true;
      await IosContinuedTaskService.instance.complete();
      expect(channelCalls.length, 1);
      expect(channelCalls.first.method, 'complete');
    });
  });
}

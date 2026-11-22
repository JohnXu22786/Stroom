# flutter\_background\_service\_android

The Android implementation of [`flutter_background_service`][1].

## Usage

This package is [endorsed][2], which means you can simply use `flutter_background_service`
normally. This package will be automatically included in your app when you do.

[1]: https://pub.dev/packages/flutter_background_service
[2]: https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin

## Stroom local patch

This package is based on the published `flutter_background_service_android`
6.3.1 source from
<https://pub.dev/packages/flutter_background_service_android/versions/6.3.1>.
Stroom pins this copy through a path dependency override. The only source change
is in `BackgroundService.runService()`: it no longer acquires a permanent
`PARTIAL_WAKE_LOCK` while running the foreground service. Stroom's background
callback is idle unless it receives an actual task, so this lock unnecessarily
keeps the CPU awake. The separate boot receiver behavior is unchanged. Keep
this package aligned with the upstream version declared in `pubspec.yaml` and
re-apply/review this patch when upgrading.

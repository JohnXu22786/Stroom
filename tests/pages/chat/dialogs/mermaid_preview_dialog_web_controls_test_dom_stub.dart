import 'package:flutter/widgets.dart';

List<String> controlLabels() => const [];

String? controlTitle() => null;

void constrainControlsViewportForTest(double width) {}

bool titleStaysBetweenControls() => false;

String? titleMotionState() => null;

String? titleTransform() => null;

bool titleLeadingCharacterIsVisible() => false;

double? titleLeadingCharacterCenterX() => null;

String controlsSnapshot() => '<web controls are only available in a browser>';

bool previewIframeReceivesPointer() => false;

String pointerHitTargetDescription(String action) =>
    'Cannot hit-test "$action" outside a browser';

bool controlReceivesPointer(String action) => false;

void clickControl(String action) {}

Widget fakeWebViewLayer() => const SizedBox.expand();

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/startup/startup_visual_style.dart';

void main() {
  test('launch default is Mint Glass', () {
    expect(
      StartupVisualStyle.launchDefault,
      StartupVisualStyle.mintGlass,
    );
  });

  test('launch style sampling can select every named palette', () {
    final sampledStyles = {
      for (var seed = 0; seed < 64; seed++)
        StartupVisualStyle.random(random: math.Random(seed)),
    };

    expect(sampledStyles, containsAll(StartupVisualStyle.values));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_plants/theme/app_theme.dart';

void main() {
  testWidgets('AppColors constants are defined', (WidgetTester tester) async {
    // Verify key theme constants are accessible without platform channels.
    expect(AppColors.darkOlive, isA<Color>());
    expect(AppColors.cream, isA<Color>());
    expect(AppColors.forest, isA<Color>());
    expect(AppColors.tan, isA<Color>());
  });
}

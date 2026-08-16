import 'package:flutter_test/flutter_test.dart';

import 'package:raasta/core/theme/app_colors.dart';

void main() {
  test('RAASTA teal brand is defined', () {
    expect(AppColors.teal.toARGB32(), isNonZero);
  });
}

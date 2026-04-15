import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:sarak/main.dart';

void main() {
  test('SarakApp widget class is constructible', () {
    const app = SarakApp();
    expect(app, isA<Widget>());
  });
}

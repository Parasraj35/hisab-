import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hisab/main.dart';

void main() {
  testWidgets('HisabApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HisabApp()));
    // Splash holds an indeterminate spinner while session restore runs (it
    // never "settles"), so advance a bounded amount of virtual time instead
    // of pumpAndSettle — enough for any startup timer/debounce to resolve.
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

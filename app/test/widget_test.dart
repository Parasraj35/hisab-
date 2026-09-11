import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hisab/main.dart';

void main() {
  // The real app runs on sqflite's platform-channel implementation, which
  // has no native Android/iOS host to talk to inside a plain `flutter
  // test` run. The FFI implementation (backed by a real, in-memory-capable
  // SQLite) stands in for it here — this only affects the test binary, not
  // the shipped app.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('HisabApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HisabApp()));
    // Splash holds an indeterminate spinner while session restore runs (it
    // never "settles"), so advance a bounded amount of virtual time instead
    // of pumpAndSettle — enough for any startup timer/debounce to resolve.
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

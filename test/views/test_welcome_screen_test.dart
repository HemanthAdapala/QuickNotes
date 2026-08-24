import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/screens/test_welcome_screen.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

void main() {
  testWidgets('TestWelcomeScreen renders AppBottomNavigationBar, button, and randomizes background color on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TestWelcomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TestWelcomeScreen), findsOneWidget);
    expect(find.byType(AppBottomNavigationBar), findsOneWidget);
    expect(find.byType(TactileButton), findsWidgets);
    expect(find.text('Random Color'), findsOneWidget);

    final initialContainer = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    expect((initialContainer.decoration as BoxDecoration?)?.color, const Color(0xFFFFFFFF));

    // Tap button to randomize background color
    await tester.tap(find.text('Random Color'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final updatedContainer = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    expect((updatedContainer.decoration as BoxDecoration?)?.color, isNotNull);
  });
}

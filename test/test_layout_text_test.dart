import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Layout test text', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 402.0),
                        child: Column(
                          key: const Key('inner_column'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              key: const Key('red_box'),
                              width: double.infinity,
                              height: 100,
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    
    final innerColumnFinder = find.byKey(const Key('inner_column'));
    final redBoxFinder = find.byKey(const Key('red_box'));
    
    final innerColumnRect = tester.getRect(innerColumnFinder);
    final redBoxRect = tester.getRect(redBoxFinder);
    
    print('Inner Column Rect: ' + innerColumnRect.toString());
    print('Red Box Rect: ' + redBoxRect.toString());
  });
}

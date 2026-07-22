import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:quick_notes/views/widgets/rich_text_controller.dart';

void main() {
  test('test range controller logic', () {
    print("Initializing RichTextEditingController...");
    final parent = RichTextEditingController();
    parent.setMarkdown('Hello\n![](assets/pic.png)\nWorld');

    print("Creating child controllers...");
    final c0 = RangeTextEditingController(parent: parent, segmentIndex: 0, startOffset: 0, endOffset: 5);
    final c1 = RangeTextEditingController(parent: parent, segmentIndex: 1, startOffset: 7, endOffset: 12);

    print("Registering child listeners...");
    c0.addListener(() {
      print("c0 notified! value=${c0.value}");
    });
    c1.addListener(() {
      print("c1 notified! value=${c1.value}");
    });

    print("Simulating focus sync from parent selection to 8...");
    parent.selection = const TextSelection.collapsed(offset: 8);

    print("Simulating child 1 selection change to 0 (which translates to parent 7)...");
    c1.selection = const TextSelection.collapsed(offset: 0);

    print("All simulations done!");
  });
}

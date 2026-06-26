import 'package:flutter/material.dart';

import 'lib/constants/rich_text_formatting_assets.dart';
import 'lib/widgets/rich_text_formatting_pill.dart';

class RichTextFormattingPillUsageExample extends StatelessWidget {
  const RichTextFormattingPillUsageExample({
    super.key,
    required this.pageController,
    required this.child,
  });

  final PageController pageController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RichTextFormattingPillContainer(
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous tools',
            onPressed: () => pageController.previousPage(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            ),
            icon: const RichTextFormattingPillIcon(
              assetName: RichTextFormattingAssets.previousPage,
              semanticLabel: 'Previous tools',
            ),
          ),
          Expanded(child: child),
          IconButton(
            tooltip: 'Next tools',
            onPressed: () => pageController.nextPage(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            ),
            icon: const RichTextFormattingPillIcon(
              assetName: RichTextFormattingAssets.nextPage,
              semanticLabel: 'Next tools',
            ),
          ),
        ],
      ),
    );
  }
}

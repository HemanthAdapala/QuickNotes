import 'dart:ui';
import 'package:flutter/material.dart' hide BoxDecoration, BoxShadow;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';

class LiquidGlassDock extends StatelessWidget {
  const LiquidGlassDock({super.key, this.useRawLayout = false});

  final bool useRawLayout;

  @override
  Widget build(BuildContext context) {
    if (useRawLayout) {
      return SizedBox(
        width: 264,
        height: 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDockIcon(Icons.phone_iphone_rounded, Colors.green.shade600),
            _buildDockIcon(Icons.chat_bubble_rounded, Colors.blue.shade600),
            _buildDockIcon(Icons.explore_rounded, Colors.orange.shade600),
            _buildDockIcon(Icons.music_note_rounded, Colors.pink.shade600),
          ],
        ),
      );
    }

    return SizedBox(
      width: 264,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Fill + Drop Shadow Layer
          Container(
            width: 264,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: const Color(0x54999999), // #999999 at 33% opacity
              boxShadow: const [
                // Drop Shadow #1
                BoxShadow(
                  offset: Offset(1.25, 0),
                  blurRadius: 0,
                  spreadRadius: -0.75,
                  color: Color(0xFFD0D0D0),
                ),
                // Drop Shadow #2
                BoxShadow(
                  offset: Offset(-1.25, 0),
                  blurRadius: 0,
                  spreadRadius: -0.75,
                  color: Color(0xFFD0D0D0),
                ),
                // Drop Shadow #3
                BoxShadow(
                  offset: Offset(0, 0),
                  blurRadius: 0,
                  spreadRadius: 0.5,
                  color: Color(0xFFCCCCCC),
                ),
                // Drop Shadow #4
                BoxShadow(
                  offset: Offset(0, 8),
                  blurRadius: 15,
                  spreadRadius: 0,
                  color: Color(0x05000000), // #000000 at 2% opacity
                ),
              ],
            ),
          ),

          // 2. Base White Pill & Glass Layer
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0), // Frost: 3
              child: Container(
                width: 264,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.white.withValues(
                      alpha:
                          0.25), // Translucent white base to allow blur & depth visibility
                  boxShadow: [
                    // Inner Shadow #1
                    BoxShadow(
                      offset: const Offset(0, 1.25),
                      blurRadius: 0.25,
                      spreadRadius: 0,
                      color: const Color(0xFF282828).withValues(alpha: 0.35),
                      inset: true,
                    ),
                    // Inner Shadow #2
                    BoxShadow(
                      offset: const Offset(0, -1.25),
                      blurRadius: 0.25,
                      spreadRadius: 0,
                      color: const Color(0xFF282828).withValues(alpha: 0.35),
                      inset: true,
                    ),
                    // Inner Shadow #3
                    BoxShadow(
                      offset: const Offset(0, 40),
                      blurRadius: 10,
                      spreadRadius: -40,
                      color: const Color(0xFF282828).withValues(alpha: 0.25),
                      inset: true,
                    ),
                    // Inner Shadow #4
                    BoxShadow(
                      offset: const Offset(0, -40),
                      blurRadius: 10,
                      spreadRadius: -40,
                      color: const Color(0xFF282828).withValues(alpha: 0.25),
                      inset: true,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDockIcon(
                        Icons.phone_iphone_rounded, Colors.green.shade600),
                    _buildDockIcon(
                        Icons.chat_bubble_rounded, Colors.blue.shade600),
                    _buildDockIcon(
                        Icons.explore_rounded, Colors.orange.shade600),
                    _buildDockIcon(
                        Icons.music_note_rounded, Colors.pink.shade600),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockIcon(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 20,
          color: color,
        ),
      ),
    );
  }
}

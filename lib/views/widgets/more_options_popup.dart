import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class MoreOptionsPopup extends StatelessWidget {
  final VoidCallback? onDeleteData;
  final VoidCallback? onRefresh;

  const MoreOptionsPopup({
    super.key,
    this.onDeleteData,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 192,
      height: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Delete Data Option
          GestureDetector(
            onTap: onDeleteData,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 192,
              height: 50,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 192,
                      height: 50,
                      decoration: const ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: BorderSide(width: 0.20, color: Color(0x33000000)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 17,
                    child: SvgPicture.asset(
                      'assets/icons/trash.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                    ),
                  ),
                  Positioned(
                    left: 39,
                    top: 10,
                    child: SizedBox(
                      width: 122,
                      height: 30,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Delete Data',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Refresh Option
          GestureDetector(
            onTap: onRefresh,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 192,
              height: 50,
              child: Stack(
                children: [
                  Positioned(
                    left: 14,
                    top: 17,
                    child: SvgPicture.asset(
                      'assets/icons/refresh.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                    ),
                  ),
                  Positioned(
                    left: 39,
                    top: 10,
                    child: SizedBox(
                      width: 122,
                      height: 30,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Refresh',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

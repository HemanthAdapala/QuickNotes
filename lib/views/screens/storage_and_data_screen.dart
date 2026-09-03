import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/storage_service.dart';
import '../widgets/app_header_bar.dart';
import '../widgets/grouped_list_container.dart';
import '../widgets/blurred_bottom_sheet.dart';

class StorageAndDataScreen extends StatefulWidget {
  const StorageAndDataScreen({Key? key}) : super(key: key);

  @override
  State<StorageAndDataScreen> createState() => _StorageAndDataScreenState();
}

class _StorageAndDataScreenState extends State<StorageAndDataScreen> {
  bool _isLoading = true;
  int _dbSize = 0;
  int _cacheSize = 0;

  @override
  void initState() {
    super.initState();
    _loadStorageData();
  }

  Future<void> _loadStorageData() async {
    setState(() => _isLoading = true);
    
    final db = await StorageService.getDatabaseSize();
    final cache = await StorageService.getCacheSize();
    
    setState(() {
      _dbSize = db;
      _cacheSize = cache;
      _isLoading = false;
    });
  }

  Future<void> _compactDatabase() async {
    HapticFeedback.heavyImpact();
    setState(() => _isLoading = true);
    await StorageService.compactDatabase();
    await _loadStorageData();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Database compacted successfully")),
      );
    }
  }

  Future<void> _clearCache() async {
    HapticFeedback.heavyImpact();
    setState(() => _isLoading = true);
    await StorageService.clearCache();
    await _loadStorageData();
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offline cache cleared")),
      );
    }
  }

  void _confirmAction({
    required String title,
    required String message,
    required String confirmText,
    required bool isDestructive,
    required VoidCallback onConfirm,
  }) {
    HapticFeedback.lightImpact();
    showBlurredBottomSheet(
      context: context,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: const Color(0xFF333333),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.inter(
                color: const Color(0xFF666666),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF2F2F7),
                      foregroundColor: const Color(0xFF333333),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDestructive ? const Color(0xFFFF3B30) : const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryTextColor = Color(0xFF333333);
    const backgroundColor = Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // App Header Bar (Liquid Glass)
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0),
              child: AppHeaderBar(
                leftHeroTag: 'hero_storage_back',
                rightHeroTag: 'hero_storage_empty',
                leftWidth: 44.0,
                rightWidth: 44.0,
                rightChild: null,
                onLeftTap: () {
                  Navigator.pop(context);
                },
                leftChild: SvgPicture.asset(
                  'assets/icons/angle_left.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
                ),
                titleWidget: Text(
                  "Storage & Data",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: primaryTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.43,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24.0),

            // Content Area (White Rounded Sheet)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Align(
                       alignment: Alignment.topCenter,
                       child: ConstrainedBox(
                         constraints: const BoxConstraints(maxWidth: 402.0),
                         child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 100.0 + MediaQuery.paddingOf(context).bottom),
                        children: [
                          // Storage Visualizer
                          _buildStorageVisualizer(),
                          
                          const SizedBox(height: 32.0),

                          // Section 1: Local Database
                          GroupedListContainer(
                            children: [
                              GroupedTile.keyValue(
                                iconPath: 'assets/icons/file.svg',
                                title: 'Local Database',
                                value: StorageService.formatBytes(_dbSize),
                                onTap: null,
                              ),
                              GroupedTile.action(
                                iconPath: 'assets/icons/settings-sliders.svg',
                                title: 'Compact Database',
                                isDestructive: false,
                                onTap: () => _confirmAction(
                                  title: 'Compact Database',
                                  message: 'This will optimize the database and reclaim unused space. Your data will not be lost.',
                                  confirmText: 'Compact',
                                  isDestructive: false,
                                  onConfirm: _compactDatabase,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16.0),

                          // Section 2: Offline Cache
                          GroupedListContainer(
                            children: [
                              GroupedTile.keyValue(
                                iconPath: 'assets/icons/folder.svg',
                                title: 'Offline Cache',
                                value: StorageService.formatBytes(_cacheSize),
                                onTap: null,
                              ),
                              GroupedTile.action(
                                iconPath: 'assets/icons/trash.svg',
                                title: 'Clear Cache',
                                isDestructive: true,
                                onTap: () => _confirmAction(
                                  title: 'Clear Cache',
                                  message: 'This will clear temporary files and cached data. Your notes and tasks will remain safe.',
                                  confirmText: 'Clear Cache',
                                  isDestructive: true,
                                  onConfirm: _clearCache,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                       ),
                     ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageVisualizer() {
    final total = _dbSize + _cacheSize;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Total App Usage",
            style: GoogleFonts.inter(
              color: const Color(0xFF8E8E93),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            StorageService.formatBytes(total),
            style: GoogleFonts.inter(
              color: const Color(0xFF1C1C1E),
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 20),
          // Visual Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                if (_dbSize > 0)
                  Expanded(
                    flex: _dbSize,
                    child: Container(
                      height: 12,
                      color: const Color(0xFF007AFF), // iOS Blue
                    ),
                  ),
                if (_cacheSize > 0)
                  Expanded(
                    flex: _cacheSize,
                    child: Container(
                      height: 12,
                      color: const Color(0xFFFF9500), // iOS Orange
                    ),
                  ),
                if (total == 0)
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 12,
                      color: const Color(0xFFE5E5EA), // Empty gray
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildLegendItem("Database", const Color(0xFF007AFF)),
              const SizedBox(width: 24),
              _buildLegendItem("Cache", const Color(0xFFFF9500)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF333333),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

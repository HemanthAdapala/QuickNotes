import 'package:flutter/material.dart';
import 'account/account_profile_screen.dart';

/// ProfileScreen — Re-exports and wraps [AccountProfileScreen] as the single canonical
/// profile screen for Quick Notes across all entrypoints (Settings, Account, Home, Auth).
class ProfileScreen extends StatelessWidget {
  final bool isSetupFlow;

  const ProfileScreen({super.key, this.isSetupFlow = false});

  @override
  Widget build(BuildContext context) {
    return AccountProfileScreen(isSetupFlow: isSetupFlow);
  }
}

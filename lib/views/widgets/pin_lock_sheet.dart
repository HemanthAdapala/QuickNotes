import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/notes_provider.dart';
import '../../services/vault_service.dart';

class PinLockSheet extends StatefulWidget {
  final ValueChanged<String> onPinSubmitted;
  final String title;

  const PinLockSheet({
    super.key,
    required this.onPinSubmitted,
    this.title = "Enter PIN to Unlock Note",
  });

  @override
  State<PinLockSheet> createState() => _PinLockSheetState();
}

class _PinLockSheetState extends State<PinLockSheet> {
  String _enteredPin = "";
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    final available = await VaultService.instance.isBiometricAvailable;
    final enabled = await VaultService.instance.isBiometricsEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available && enabled;
      });
    }
    if (available && enabled) {
      _triggerBiometrics();
    }
  }

  Future<void> _triggerBiometrics() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final success = await provider.unlockVaultBiometrically();
    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });
      
      // Auto-submit when 4 digits are entered
      if (_enteredPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          widget.onPinSubmitted(_enteredPin);
          Navigator.pop(context);
        });
      }
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: EdgeInsets.only(
        top: 24.0,
        left: 24.0,
        right: 24.0,
        bottom: 24.0 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          // Lock Icon
          Icon(
            Icons.lock_person_rounded,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          
          // Title
          Text(
            widget.title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Default PIN is 1234. Setup biometrics in settings.",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          
          // PIN Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _enteredPin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          
          // Keypad Grid
          SizedBox(
            width: size.width * 0.75,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildKey("1"),
                    _buildKey("2"),
                    _buildKey("3"),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildKey("4"),
                    _buildKey("5"),
                    _buildKey("6"),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildKey("7"),
                    _buildKey("8"),
                    _buildKey("9"),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Fingerprint or Clear button on bottom-left
                    _biometricAvailable
                        ? _buildIconButton(
                            Icons.fingerprint_rounded,
                            _triggerBiometrics,
                            tooltip: "Unlock with Biometrics",
                            iconColor: theme.colorScheme.primary,
                          )
                        : _buildIconButton(
                            Icons.clear_rounded,
                            () {
                              setState(() {
                                _enteredPin = "";
                              });
                            },
                            tooltip: "Clear",
                          ),
                    _buildKey("0"),
                    // Backspace button on bottom-right
                    _buildIconButton(
                      Icons.backspace_outlined,
                      _onDeletePressed,
                      tooltip: "Delete",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String value) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _onDigitPressed(value),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
          shape: BoxShape.circle,
        ),
        child: Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon,
    VoidCallback onTap, {
    required String tooltip,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 24,
          color: iconColor ?? theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../themes/quick_notes_theme.dart';
import '../../services/vault_service.dart';
import '../../providers/notes_provider.dart';
import '../widgets/app_header_bar.dart';

enum LockPurpose { appUnlock, vaultUnlock, noteUnlock }

class PasscodeLockScreen extends StatefulWidget {
  final LockPurpose purpose;
  final VoidCallback onSuccess;
  final VoidCallback? onCancel;

  const PasscodeLockScreen({
    super.key,
    required this.purpose,
    required this.onSuccess,
    this.onCancel,
  });

  @override
  State<PasscodeLockScreen> createState() => _PasscodeLockScreenState();
}

class _PasscodeLockScreenState extends State<PasscodeLockScreen> {
  String _enteredPin = "";
  bool _isError = false;
  bool _bioAvailable = false;
  final _vaultService = VaultService.instance;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await _vaultService.isBiometricAvailable;
    final enabled = await _vaultService.isBiometricsEnabled();
    if (available && enabled && widget.purpose != LockPurpose.noteUnlock) {
      setState(() {
        _bioAvailable = true;
      });
      _triggerBiometrics();
    }
  }

  Future<void> _triggerBiometrics() async {
    final success = await _vaultService.authenticateBiometrically();
    if (success) {
      try {
        final provider = Provider.of<NotesProvider>(context, listen: false);
        await provider.unlockVaultBiometrically();
      } catch (e) {
        debugPrint("NotesProvider not found in context: $e");
      }
      _handleSuccess();
    }
  }

  void _handleSuccess() {
    HapticFeedback.heavyImpact();
    widget.onSuccess();
  }

  void _onKeyPress(String digit) {
    if (_enteredPin.length >= 4) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isError = false;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isError = false;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _verifyPin() async {
    final isValid = await _vaultService.verifyPin(_enteredPin);
    if (isValid) {
      try {
        final provider = Provider.of<NotesProvider>(context, listen: false);
        await provider.unlockVault(_enteredPin);
      } catch (e) {
        debugPrint("NotesProvider not found in context: $e");
      }
      _handleSuccess();
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _isError = true;
        _enteredPin = "";
      });
    }
  }

  String _getInstructionText() {
    switch (widget.purpose) {
      case LockPurpose.appUnlock:
        return "ENTER PASSCODE TO UNLOCK QUICKNOTES";
      case LockPurpose.vaultUnlock:
        return "ENTER PIN TO DECRYPT SECURE VAULT";
      case LockPurpose.noteUnlock:
        return "ENTER PIN TO DECRYPT SECURE NOTE";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCancelable =
        widget.purpose != LockPurpose.appUnlock && widget.onCancel != null;

    return Scaffold(
      backgroundColor: QuickNotesTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0),
              child: AppHeaderBar(
                leftHeroTag: 'hero_passcode_cancel',
                rightHeroTag: 'hero_passcode_empty',
                leftWidth: 44.0,
                rightWidth: 44.0,
                rightChild: null,
                leftChild: isCancelable
                    ? const Icon(Icons.close_rounded,
                        color: QuickNotesTheme.textPrimary)
                    : null,
                onLeftTap: isCancelable
                    ? () {
                        HapticFeedback.lightImpact();
                        widget.onCancel?.call();
                      }
                    : null,
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    const Spacer(),

              // Lock Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: QuickNotesTheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isError ? Colors.red : QuickNotesTheme.border,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _isError ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: _isError ? Colors.red : QuickNotesTheme.accent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 32),

              // Title Instruction
              Text(
                _getInstructionText(),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _isError ? Colors.red : QuickNotesTheme.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Digit Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color:
                          filled ? QuickNotesTheme.accent : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: filled
                            ? QuickNotesTheme.accent
                            : QuickNotesTheme.border,
                        width: 2.0,
                      ),
                    ),
                  );
                }),
              ),
              const Spacer(),

              // Keypad Numbers
              Column(
                children: [
                  _buildKeypadRow(["1", "2", "3"]),
                  const SizedBox(height: 16),
                  _buildKeypadRow(["4", "5", "6"]),
                  const SizedBox(height: 16),
                  _buildKeypadRow(["7", "8", "9"]),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Biometrics / Clear Button
                      _buildSpecialButton(
                        _bioAvailable ? Icons.fingerprint_rounded : null,
                        _bioAvailable ? _triggerBiometrics : null,
                      ),
                      _buildKeypadButton("0"),
                      _buildSpecialButton(
                        Icons.backspace_outlined,
                        _onBackspace,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeypadButton(d)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return _KeypadButton(
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: QuickNotesTheme.textPrimary,
        ),
      ),
      onPressed: () => _onKeyPress(digit),
    );
  }

  Widget _buildSpecialButton(IconData? icon, VoidCallback? onPressed) {
    if (icon == null) {
      return const SizedBox(width: 72, height: 72);
    }
    return _KeypadButton(
      onPressed: onPressed,
      child: Icon(
        icon,
        color: QuickNotesTheme.textPrimary,
        size: 24,
      ),
    );
  }
}

// Keypad Button helper with micro scale animation
class _KeypadButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const _KeypadButton({
    required this.child,
    required this.onPressed,
  });

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() {
      _scale = 0.9;
    });
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() {
      _scale = 1.0;
    });
    widget.onPressed!();
  }

  void _onTapCancel() {
    if (widget.onPressed == null) return;
    setState(() {
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Transform.scale(
        scale: _scale,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: QuickNotesTheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: QuickNotesTheme.border, width: 1.5),
          ),
          child: Center(
            child: widget.child,
          ),
        ),
      ),
    );
  }
}


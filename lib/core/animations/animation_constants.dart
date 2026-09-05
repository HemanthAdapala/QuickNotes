import 'package:flutter/animation.dart';
import '../motion/motion_constants.dart';

/// Legacy animation constants boundary for Quick Notes.
///
/// **DEPRECATION NOTICE**: These constants are legacy tokens slated for retirement
/// during future screen migration phases.
///
/// New components and features MUST use canonical tokens from [QuickNotesMotion]
/// (lib/core/motion/motion_constants.dart) instead.
///
/// Existing consumers (e.g. NoteCard, FolderManagementScreen) are preserved
/// for backward compatibility until their respective screen migration phases.
@Deprecated('Use QuickNotesMotion from lib/core/motion/motion_constants.dart instead.')
const Duration kDurationFast = Duration(milliseconds: 150);

@Deprecated('Use QuickNotesMotion from lib/core/motion/motion_constants.dart instead.')
const Duration kDurationNormal = Duration(milliseconds: 250);

@Deprecated('Use QuickNotesMotion from lib/core/motion/motion_constants.dart instead.')
const Duration kDurationSlow = Duration(milliseconds: 350);

@Deprecated('Use QuickNotesMotion.kMotionPage instead.')
const Duration kDurationPage = Duration(milliseconds: 400);

@Deprecated('Use QuickNotesMotion.kMotionMicro instead.')
const Duration kDurationCardPress = Duration(milliseconds: 100);

@Deprecated('Use QuickNotesMotion.kMotionRelease instead.')
const Duration kDurationCardRelease = Duration(milliseconds: 150);

@Deprecated('Use QuickNotesMotion curves instead.')
const Curve kCurveDefault = Curves.easeInOut;

@Deprecated('Use QuickNotesMotion curves instead.')
const Curve kCurveEnter = Curves.easeOut;

@Deprecated('Use QuickNotesMotion curves instead.')
const Curve kCurveExit = Curves.easeIn;

@Deprecated('Use QuickNotesMotion.kMotionAppleEase or kMotionEaseInOutCubic instead.')
const Curve kCurvePage = Curves.easeInOutCubic;

@Deprecated('Use QuickNotesMotion.kMotionSpring instead.')
const Curve kCurveSpring = Curves.elasticOut; // Use sparingly


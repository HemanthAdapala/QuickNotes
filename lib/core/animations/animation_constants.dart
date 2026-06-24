import 'package:flutter/animation.dart';

const Duration kDurationFast = Duration(milliseconds: 150);
const Duration kDurationNormal = Duration(milliseconds: 250);
const Duration kDurationSlow = Duration(milliseconds: 350);
const Duration kDurationPage = Duration(milliseconds: 400);

const Duration kDurationCardPress = Duration(milliseconds: 100);
const Duration kDurationCardRelease = Duration(milliseconds: 150);

const Curve kCurveDefault = Curves.easeInOut;
const Curve kCurveEnter = Curves.easeOut;
const Curve kCurveExit = Curves.easeIn;
const Curve kCurvePage = Curves.easeInOutCubic;
const Curve kCurveSpring = Curves.elasticOut; // Use sparingly

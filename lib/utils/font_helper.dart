import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FontHelper {
  static TextStyle poppins({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
      );
    } catch (e) {
      // Fallback to system font if Google Fonts fails
      return TextStyle(
        fontFamily: 'Roboto', // System font fallback
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
      );
    }
  }

  static TextStyle poppinsMedium({
    double? fontSize,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: color,
        height: height,
        decoration: decoration,
      );
    } catch (e) {
      // Fallback to system font if Google Fonts fails
      return TextStyle(
        fontFamily: 'Roboto',
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: color,
        height: height,
        decoration: decoration,
      );
    }
  }

  static TextStyle poppinsSemiBold({
    double? fontSize,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
        height: height,
        decoration: decoration,
      );
    } catch (e) {
      // Fallback to system font if Google Fonts fails
      return TextStyle(
        fontFamily: 'Roboto',
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
        height: height,
        decoration: decoration,
      );
    }
  }

  static TextStyle poppinsBold({
    double? fontSize,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    try {
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
        height: height,
        decoration: decoration,
      );
    } catch (e) {
      // Fallback to system font if Google Fonts fails
      return TextStyle(
        fontFamily: 'Roboto',
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
        height: height,
        decoration: decoration,
      );
    }
  }
}

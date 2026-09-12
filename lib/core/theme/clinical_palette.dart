import 'package:flutter/material.dart';

/// Clinical presentation palette.
///
/// Design rules (project-wide):
///  * ONE accent — teal. Everything interactive or "measured" is teal.
///  * Semantic hues only: amber = caution, coral = urgent/fault, cyan = oxygen,
///    violet = derived/experimental estimate.
///  * 4/8-pt spacing grid. Hairline borders instead of heavy shadows.
///  * Gradients only on CTAs and gauges.
///  * Every numeric readout uses tabular figures and carries its unit.
///
/// These are intentionally NOT the brand greens in [AppTheme]. Surfaces and
/// typography stay with the app theme; this palette is the data-viz and
/// status layer so a number's colour is a coding channel, not decoration.
class ClinicalPalette {
  const ClinicalPalette._();

  /// The single accent: measured data, primary interaction, live link.
  static const Color teal = Color(0xFF0D9488);
  static const Color tealBright = Color(0xFF2DD4BF);

  /// Caution — "recheck", stale data, attention band.
  static const Color amber = Color(0xFFD97706);

  /// Urgent — error, fault, red band, out-of-range.
  static const Color coral = Color(0xFFE11D48);

  /// Oxygenation (SpO₂ / PPG pleth channel).
  static const Color cyan = Color(0xFF0891B2);

  /// Derived or experimental values (glucose / BP estimates).
  static const Color violet = Color(0xFF7C3AED);

  // ── Cardiac accent ──
  // The burnt-orange from the reference cardiac UI: live heart rate, ECG strip
  // traces, recording dials, and vital-sign hero numerals. Deliberately not the
  // same hue as [coral] (which is a rose-red status indicator for urgent/fault).
  // This is a warm orange that reads as "heartbeat" and pairs naturally with the
  // brand greens.

  /// Cardiac accent — heartbeat orange for light surfaces.
  static const Color cardiacCoral = Color(0xFFE8531E);

  /// A brighter variant for dark mode where the base would look muddy.
  static const Color cardiacCoralBright = Color(0xFFFF6B3D);

  /// Light-mode container tint for cardiac-coral badges and cards.
  static const Color cardiacCoralContainer = Color(0xFFFFF0EB);

  /// Dark-mode container tint for cardiac-coral badges and cards.
  static const Color cardiacCoralContainerDark = Color(0xFF3D1A0A);

  /// Returns the cardiac coral appropriate for the current brightness.
  static Color cardiacAccent(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? cardiacCoralBright
        : cardiacCoral;
  }

  /// Returns the cardiac coral container for the current brightness.
  static Color cardiacContainer(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? cardiacCoralContainerDark
        : cardiacCoralContainer;
  }

  /// The one ink source for this brightness.
  static Color _ink(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE7EEF8)
        : const Color(0xFF0F1B2D);
  }

  /// Hairline border colour for the current brightness.
  static Color hairline(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _ink(context).withValues(alpha: dark ? 0.14 : 0.10);
  }

  /// Muted label ink.
  static Color muted(BuildContext context) =>
      _ink(context).withValues(alpha: 0.60);

  /// Faint ink for disabled / "no data" states.
  static Color faint(BuildContext context) =>
      _ink(context).withValues(alpha: 0.33);
}

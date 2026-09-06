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

  /// Hairline border colour for the current brightness.
  static Color hairline(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFE7EEF8) : const Color(0xFF0F1B2D);
    return ink.withValues(alpha: dark ? 0.14 : 0.10);
  }

  /// Muted label ink.
  static Color muted(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFE7EEF8) : const Color(0xFF0F1B2D);
    return ink.withValues(alpha: 0.60);
  }

  /// Faint ink for disabled / "no data" states.
  static Color faint(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFE7EEF8) : const Color(0xFF0F1B2D);
    return ink.withValues(alpha: 0.33);
  }
}

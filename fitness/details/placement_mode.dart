enum WearablePlacement {
  forearmWrist(
      'Forearm / Wrist', 'Upper Body & Arms', 'Arm tilt & curl rotation'),
  chestStrap('Chest Strap', 'Cardio & Core', 'Pectoral ECG & vertical impact'),
  thighAnkle('Thigh / Ankle', 'Lower Body & Legs', 'Knee angle & squat depth');

  final String label;
  final String category;
  final String description;

  const WearablePlacement(this.label, this.category, this.description);
}

class PlacementTransformer {
  /// Transforms raw sensor vectors according to how the user is wearing the sensor
  static TransformedMotion transform(
    double ax,
    double ay,
    double az,
    double gx,
    double gy,
    double gz,
    WearablePlacement placement,
  ) {
    switch (placement) {
      case WearablePlacement.thighAnkle:
        // On thigh: Z-axis is parallel to femur, X/Y capture hip flex
        return TransformedMotion(
          primaryAccel: az,
          secondaryAccel: ay,
          primaryGyro: gx.abs(),
          jointAngle: (az.clamp(-1.0, 1.0) * 90.0).abs(),
        );
      case WearablePlacement.chestStrap:
        // On chest: Y-axis is vertical posture spine, Z is forward chest lean
        return TransformedMotion(
          primaryAccel: ay,
          secondaryAccel: az,
          primaryGyro: gy.abs(),
          jointAngle: (ax.clamp(-1.0, 1.0) * 90.0).abs(),
        );
      case WearablePlacement.forearmWrist:
        // Standard forearm placement
        return TransformedMotion(
          primaryAccel: az,
          secondaryAccel: ax,
          primaryGyro: gy.abs(),
          jointAngle: (ay.clamp(-1.0, 1.0) * 90.0).abs(),
        );
    }
  }
}

class TransformedMotion {
  final double primaryAccel;
  final double secondaryAccel;
  final double primaryGyro;
  final double jointAngle;

  const TransformedMotion({
    required this.primaryAccel,
    required this.secondaryAccel,
    required this.primaryGyro,
    required this.jointAngle,
  });
}

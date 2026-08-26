import 'package:geolocator/geolocator.dart';

/// A single coarse position, or nothing.
///
/// Deliberately the narrowest possible surface: the app tags a screening with a
/// rough location so the worker's own coverage map means something, and it never
/// needs a stream, a heading or metre-level accuracy. Everything here is
/// best-effort — a screening must never fail to save because the GPS was cold.
class LocationFix {
  final double latitude;
  final double longitude;

  const LocationFix(this.latitude, this.longitude);
}

class LocationService {
  /// How long a location tag is allowed to hold up saving a screening. A worker
  /// standing in a doorway is not waiting thirty seconds for a satellite.
  static const Duration timeout = Duration(seconds: 6);

  /// Returns null rather than throwing, in every failure mode: consent refused,
  /// OS permission denied, service off, cold fix, or no sensor.
  ///
  /// [consented] is passed in rather than read here so the consent check lives
  /// with the settings that own it, and so this class stays testable.
  Future<LocationFix?> currentFix({required bool consented}) async {
    if (!consented) return null;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Last known first: it is instant, and for a village-level coverage map a
      // fix from a few minutes ago is indistinguishable from a fresh one.
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) {
        return LocationFix(cached.latitude, cached.longitude);
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: timeout,
      );
      return LocationFix(position.latitude, position.longitude);
    } catch (_) {
      // Includes the timeout, a missing platform implementation, and the test
      // host where there is no location plugin at all.
      return null;
    }
  }
}

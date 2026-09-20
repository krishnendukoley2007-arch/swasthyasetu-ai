import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  /// Requests all permissions required for Bluetooth Low Energy scanning and connection
  static Future<bool> requestBluetoothPermissions() async {
    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? true;
      final connectGranted =
          statuses[Permission.bluetoothConnect]?.isGranted ?? true;

      return scanGranted && connectGranted;
    } catch (e) {
      debugPrint(
          '[PermissionService] Error requesting Bluetooth permissions: ');
      return false;
    }
  }

  /// Checks if necessary Bluetooth permissions are already granted
  static Future<bool> hasBluetoothPermissions() async {
    try {
      final scanStatus = await Permission.bluetoothScan.status;
      final connectStatus = await Permission.bluetoothConnect.status;

      // On Android 11 and below, bluetoothScan/connect are automatically granted or not applicable
      return scanStatus.isGranted && connectStatus.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Opens the Android system App Info / Settings screen
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}

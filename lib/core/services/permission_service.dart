import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

class PermissionService {
  static Future<PermissionStatus> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status;
  }

  static Future<PermissionStatus> requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
    return statuses[Permission.bluetoothConnect] ?? PermissionStatus.denied;
  }

  static Future<PermissionStatus> requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status;
  }

  static Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  static Future<bool> isPermissionPermanentlyDenied(Permission permission) async {
    final status = await permission.status;
    return status.isPermanentlyDenied;
  }

  static void showPermissionDeniedDialog({
    required BuildContext context,
    required String title,
    required String message,
    required Permission permission,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PermissionDeniedDialog(
        title: title,
        message: message,
        permission: permission,
        onRetry: onRetry,
      ),
    );
  }

  static void showPermissionSnackBar({
    required BuildContext context,
    required String message,
    required Permission permission,
    VoidCallback? onOpenSettings,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: onOpenSettings != null
            ? SnackBarAction(
                label: 'Open Settings',
                onPressed: onOpenSettings,
              )
            : null,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static Future<void> openAppSettings() async {
    // The package's top-level function has the same name as this method, so an
    // unprefixed call would recurse into ourselves forever and crash.
    await permission_handler.openAppSettings();
  }
}

class _PermissionDeniedDialog extends StatelessWidget {
  final String title;
  final String message;
  final Permission permission;
  final VoidCallback? onRetry;

  const _PermissionDeniedDialog({
    required this.title,
    required this.message,
    required this.permission,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {

    return AlertDialog(
      title: Text(title),
      content: Text(message),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await PermissionService.openAppSettings();
          },
          child: const Text('Open Settings'),
        ),
        if (onRetry != null)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry!();
            },
            child: const Text('Retry'),
          ),
      ],
    );
  }
}

class PermissionGate extends StatefulWidget {
  final List<Permission> permissions;
  final Widget child;
  final Widget? fallback;
  final String? rationaleTitle;
  final String? rationaleMessage;

  const PermissionGate({
    super.key,
    required this.permissions,
    required this.child,
    this.fallback,
    this.rationaleTitle,
    this.rationaleMessage,
  });

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _allGranted = false;
  bool _isChecking = true;
  String? _deniedPermissionName;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    for (final permission in widget.permissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        _deniedPermissionName = _getPermissionName(permission);
        break;
      }
    }

    final allGranted = await Future.wait(
      widget.permissions.map((p) => p.isGranted),
    ).then((results) => results.every((r) => r));

    if (mounted) {
      setState(() {
        _allGranted = allGranted;
        _isChecking = false;
      });
    }
  }

  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'Camera';
      case Permission.bluetooth:
      case Permission.bluetoothConnect:
      case Permission.bluetoothScan:
        return 'Bluetooth';
      case Permission.location:
      case Permission.locationWhenInUse:
      case Permission.locationAlways:
        return 'Location';
      case Permission.storage:
        return 'Storage';
      default:
        return 'Permission';
    }
  }

  Future<void> _requestPermissions() async {
    for (final permission in widget.permissions) {
      final status = await permission.request();
      if (!status.isGranted) {
        _deniedPermissionName = _getPermissionName(permission);
        if (status.isPermanentlyDenied) {
          if (mounted) {
            PermissionService.showPermissionDeniedDialog(
              context: context,
              title: '$_deniedPermissionName Permission Required',
              message:
                  'This feature requires ${_deniedPermissionName!.toLowerCase()} access. Please enable it in app settings.',
              permission: permission,
              onRetry: _requestPermissions,
            );
          }
        } else {
          if (mounted) {
            PermissionService.showPermissionSnackBar(
              context: context,
              message:
                  '$_deniedPermissionName permission is required for this feature.',
              permission: permission,
              onOpenSettings: () => PermissionService.openAppSettings(),
            );
          }
        }
        return;
      }
    }

    if (mounted) {
      setState(() => _allGranted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allGranted) {
      return widget.child;
    }

    return widget.fallback ??
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  '${_deniedPermissionName ?? 'Permission'} Required',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.rationaleMessage ??
                      'This feature requires ${_deniedPermissionName?.toLowerCase() ?? 'permission'} access to work properly.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _requestPermissions,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Grant Permission'),
                ),
              ],
            ),
          ),
        );
  }
}
# iOS Setup TODO

## iOS Build Not Currently Configured

This Flutter app currently does not have an iOS build configuration. When iOS support is added, the following must be configured in `ios/Runner/Info.plist`:

### Required Camera Permission
```xml
<key>NSCameraUsageDescription</key>
<string>SwasthyaSetu AI needs camera access to capture clinical images and document patient conditions during screenings.</string>
```

### Additional Permissions Likely Needed
```xml
<!-- Bluetooth permissions for device connectivity -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>SwasthyaSetu AI uses Bluetooth to connect to medical devices for vital sign monitoring.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>SwasthyaSetu AI uses Bluetooth to connect to medical devices for vital sign monitoring.</string>

<!-- Location permissions for BLE scanning -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>SwasthyaSetu AI needs location access to discover nearby Bluetooth medical devices.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>SwasthyaSetu AI needs location access to discover nearby Bluetooth medical devices even when in background.</string>

<!-- Photo library for saving screening images -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>SwasthyaSetu AI needs photo library access to save clinical images captured during screenings.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>SwasthyaSetu AI needs photo library access to save clinical images captured during screenings.</string>

<!-- Microphone if audio recording is needed -->
<key>NSMicrophoneUsageDescription</key>
<string>SwasthyaSetu AI may need microphone access for audio documentation during screenings.</string>
```

### iOS Build Setup Steps
1. Run `flutter create --platforms=ios .` in the app directory
2. Configure signing & capabilities in Xcode
3. Add the above Info.plist entries
4. Test on physical iOS device (BLE requires device testing)
5. Configure App Store Connect for distribution

### Minimum iOS Version
Set minimum iOS version to 13.0+ in `ios/Podfile`:
```ruby
platform :ios, '13.0'
```
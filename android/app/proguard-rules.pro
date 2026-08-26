# ProGuard rules for SwasthyaSetu AI

# Flutter/Dart specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep all generated plugin registrants
-keep class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }

# Keep all generated models (freezed, json_serializable)
-keep class **.* {
    <fields>;
    <methods>;
}

# Keep Dio and related network classes
-keep class dio.** { *; }
-keep class retrofit2.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# Keep flutter_blue_plus
-keep class com.polidea.multiplatformbleadapter.** { *; }
-keep class com.polidea.multiplatformbleadapter.bluetooth.** { *; }
-keep class com.polidea.rxandroidble2.** { *; }

# Keep drift/database
-keep class drift.** { *; }
-keep class sqlite3.** { *; }

# Keep riverpod
-keep class com.google.devtools.build.android.desugar.runtime.** { *; }

# Keep animations
-keep class flutter_animate.** { *; }

# Keep go_router
-keep class go_router.** { *; }

# Keep connectivity_plus
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Optimize for release
-dontwarn io.flutter.**
-dontwarn io.flutter.embedding.**
-dontwarn com.baseflow.permissionhandler.**
-dontwarn dio.**
-dontwarn retrofit2.**
-dontwarn okhttp3.**
-dontwarn okio.**
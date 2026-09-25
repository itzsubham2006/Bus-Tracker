# Flutter/Google Maps ProGuard Rules
# Keep Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Google Maps
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.maps.** { *; }
-dontwarn com.google.android.gms.**

# Keep Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Keep Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep Kotlin metadata (needed by some plugins)
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# General Android
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Flutter deferred components (Play Core is optional)
-dontwarn com.google.android.play.core.**

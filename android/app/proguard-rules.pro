# Gson TypeToken — preserve generic signatures so flutter_local_notifications works
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }

# flutter_local_notifications uses Gson TypeToken via reflection for scheduled notifications
-keep class com.dextrous.flutterlocalnotifications.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (referenced by Flutter deferred components — not used in this app)
-dontwarn com.google.android.play.core.**

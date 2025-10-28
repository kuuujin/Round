# Flutter rules are inserted by the Flutter tool base.
# We add our own rules here.

# Dio & OkHttp rules
-dontwarn okio.**
-dontwarn retrofit2.**
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-keep class retrofit2.** { *; }
-keep interface retrofit2.** { *; }
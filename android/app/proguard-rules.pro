# This file didn't exist before 2026-10-08 - android/app/build.gradle's
# release buildType has referenced it for ProGuard/R8 rules from the start,
# but nothing ever created it, so every release build failed outright
# (debug builds don't run R8, so this was never exercised until the first
# release build attempt after the API 36 toolchain upgrade).
#
# Most plugins ship their own consumer-rules.pro bundled in their AAR,
# which AGP merges automatically regardless of this file's content - these
# rules cover the libraries most likely to hit reflection-based stripping
# in release mode specifically (debug mode has no R8, so these issues are
# otherwise invisible until exactly the kind of release-build QA pass this
# file was created for).

# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# flutter_app_badger (ShortcutBadger reflects into launcher-specific classes)
-keep class me.leolin.shortcutbadger.** { *; }
-dontwarn me.leolin.shortcutbadger.**

# Syncfusion PDF viewer
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# flutter_local_notifications (uses reflection for scheduled notification receivers)
-keep class com.dexterous.** { *; }

# webview_flutter
-keep class io.flutter.plugins.webviewflutter.** { *; }

# General Flutter plugin embedding
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter's engine references Play Core's deferred-components (split
# install) API unconditionally, even though this app doesn't use dynamic
# feature delivery and doesn't depend on com.google.android.play:core at
# all - standard, well-known Flutter release fix.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

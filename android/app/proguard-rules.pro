# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Firebase Authentication
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.firestore.model.** { *; }

# Firebase Storage
-keep class com.google.firebase.storage.** { *; }

# Hive
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keep class * extends io.hive.** { *; }

# Workmanager
-keep class androidx.work.** { *; }

# Google Sign In
-keep class com.google.android.gms.auth.** { *; }

# Additional Google Play Services rules
-keep class com.google.android.gms.common.ConnectionResult {
    int SUCCESS;
}
-keep class com.google.android.gms.tasks.** { *; }
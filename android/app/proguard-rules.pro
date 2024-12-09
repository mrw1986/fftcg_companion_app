# android/app/proguard-rules.pro
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class com.google.firebase.** { *; }

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
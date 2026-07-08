# Flutter通用 ProGuard/R8 规则

# 保留 Flutter 引擎类
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# 保留 MainActivity
-keep class com.johntsui.stroom.MainActivity { *; }

# 保留 Flutter JNI 回调接口
-keep class io.flutter.embedding.engine.FlutterJNI { *; }
-keep class io.flutter.embedding.android.FlutterActivity { *; }

# 保留被反射调用的插件类
-keep class com.alexmercerind.media_kit_libs_android_video.** { *; }
-keep class com.alexmercerind.mediakitandroidhelper.** { *; }

# 保留 foreground service 类
-keep class com.foregroundservice.** { *; }

# 保留 sqflite 原生方法
-keep class com.tekartik.sqflite.** { *; }

# Keep Play Core classes used by Flutter deferred components (R8)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Keep annotations used by reflection
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

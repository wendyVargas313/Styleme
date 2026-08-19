# Keep Flutter Driver extended contexts
-keep class io.flutter.embedding.engine.FlutterEngine { *; }

# Keep Dart-defined classes
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enum types
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

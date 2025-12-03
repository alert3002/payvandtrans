# === ҚОИДАҲО БАРОИ FLUTTER ===
# Ин қоидаҳо ба R8 намегузоранд, ки классҳои муҳими Flutter-ро нест кунад.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter embedding
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter plugins
-keep class * extends io.flutter.plugin.common.PluginRegistry
-keep class * extends io.flutter.plugin.common.PluginRegistry$RegistrarCallback
-keep class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelables
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep annotation default values
-keepattributes AnnotationDefault

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep R classes
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Keep application classes
-keep public class * extends android.app.Application
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Fragment
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep custom views
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
    *** get*();
}

# Keep setters in Views
-keepclassmembers public class * extends android.view.View {
    void set*(***);
    *** get*();
}

# Keep onClick listeners
-keepclassmembers class * extends android.app.Activity {
    public void *(android.view.View);
}

# HTTP classes
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# SharedPreferences
-keep class androidx.preference.** { *; }
-dontwarn androidx.preference.**

# Image Picker
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urlauncher.**

# JWT Decoder
-keep class com.jonataslaw.** { *; }
-dontwarn com.jonataslaw.**

# Flutter Map
-keep class com.fleaflet.** { *; }
-dontwarn com.fleaflet.**

# ====================================

# === ҚОИДАҲО БАРОИ YANDEX MAPKIT ===
# Ин қоидаҳо ба R8 намегузоранд, ки классҳои муҳими Yandex-ро нест кунад.
-keep class com.yandex.mapkit.** { *; }
-keep interface com.yandex.mapkit.** { *; }
-dontwarn com.yandex.mapkit.**

-keep class com.yandex.runtime.** { *; }
-keep interface com.yandex.runtime.** { *; }
-dontwarn com.yandex.runtime.**
# ====================================
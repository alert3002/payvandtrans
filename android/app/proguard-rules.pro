# === ҚОИДАҲО БАРОИ YANDEX MAPKIT ===
# Ин қоидаҳо ба R8 намегузоранд, ки классҳои муҳими Yandex-ро нест кунад.
-keep class com.yandex.mapkit.** { *; }
-keep interface com.yandex.mapkit.** { *; }
-dontwarn com.yandex.mapkit.**

-keep class com.yandex.runtime.** { *; }
-keep interface com.yandex.runtime.** { *; }
-dontwarn com.yandex.runtime.**
# ====================================
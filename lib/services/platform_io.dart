// Барои mobile/desktop — dart:io
import 'dart:io' show Platform;

bool get platformIsAndroid => Platform.isAndroid;
bool get platformIsIOS => Platform.isIOS;
String get platformOperatingSystem => Platform.operatingSystem;

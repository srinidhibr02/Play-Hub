import 'package:flutter/foundation.dart';
class FlavorConfig {
  static String flavor = 'dev';
  static String get title {
    switch (flavor) {
      case 'prod':
        return 'Play Hub';
      case 'dev':
        return 'Play Hub Dev';
      default:
        return 'Play Hub';
    }
  }

  static void init(String f) {
    flavor = f;
    debugPrint('🚀 Flavor: $flavor');
  }
}

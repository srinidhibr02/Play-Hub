class FlavorConfig {
  static String flavor = 'dev';
  static String get title {
    switch (flavor) {
      case 'prod':
        return 'PlayHub';
      case 'dev':
        return 'PlayHub Dev';
      default:
        return 'PlayHub';
    }
  }

  static void init(String f) {
    flavor = f;
    print('🚀 Flavor: $flavor');
  }
}

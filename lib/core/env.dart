class Env {
  Env._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static bool get isProd => _env == 'prod';

  static String get nakamaHost => isProd ? 'api.abba-s.dev' : '192.168.1.8';
  static int    get nakamaPort => isProd ? 443 : 7350;
  static bool   get nakamaSSL  => isProd;

  static const String serverKey = String.fromEnvironment(
    'SERVER_KEY',
    defaultValue: 'mariyamisfrommuzaffarpur', // dev default only
  );
}

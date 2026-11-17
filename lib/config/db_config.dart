import 'dart:io' show Platform;

/// Datele de conectare la PostgreSQL.
///
/// Se pot schimba fără să modifici codul, la rulare:
///   flutter run --dart-define=DB_HOST=192.168.1.20 --dart-define=DB_PASSWORD=...
///
/// Atenție: tot ce e aici ajunge în aplicația compilată. E în regulă pentru
/// o bază de date locală, de dezvoltare; pentru o aplicație publicată,
/// telefonul ar trebui să vorbească cu un server (API), nu direct cu baza.
abstract final class DbConfig {
  static const _host = String.fromEnvironment('DB_HOST');
  static const port = int.fromEnvironment('DB_PORT', defaultValue: 5432);
  static const database = String.fromEnvironment(
    'DB_NAME',
    defaultValue: 'sarcini',
  );
  static const username = String.fromEnvironment(
    'DB_USER',
    defaultValue: 'sarcini_app',
  );
  static const password = String.fromEnvironment(
    'DB_PASSWORD',
    defaultValue: '32aa078c632cae7a686699da72a7f0b6',
  );

  /// Simulatorul iOS vede Mac-ul la 127.0.0.1; emulatorul Android la 10.0.2.2.
  static String get host {
    if (_host.isNotEmpty) return _host;
    return Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final double goalWeight;
  final double goalFat;
  final double minWeight;
  final double targetWeeklyGainMin;
  final double targetWeeklyGainMax;

  const AppSettings({
    this.goalWeight = 96,
    this.goalFat = 20,
    this.minWeight = 80,
    this.targetWeeklyGainMin = 0.15,
    this.targetWeeklyGainMax = 0.30,
  });
}

class AppCredentials {
  final String anthropicApiKey;
  final String tursoUrl;
  final String tursoToken;

  const AppCredentials({
    required this.anthropicApiKey,
    required this.tursoUrl,
    required this.tursoToken,
  });

  bool get isComplete =>
      anthropicApiKey.isNotEmpty &&
      tursoUrl.isNotEmpty &&
      tursoToken.isNotEmpty;
}

class AppPreferences {
  static const anthropicKey = 'anthropic_api_key';
  static const tursoTokenKey = 'turso_token';
  static const tursoUrlKey = 'turso_url';
  static const targetMinKey = 'target_weekly_gain_min';
  static const targetMaxKey = 'target_weekly_gain_max';

  final FlutterSecureStorage _secureStorage;

  AppPreferences({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> migrateSensitiveValues() async {
    final preferences = await SharedPreferences.getInstance();
    await _migrateKey(preferences, anthropicKey);
    await _migrateKey(preferences, tursoTokenKey);
  }

  Future<void> _migrateKey(SharedPreferences preferences, String key) async {
    final legacyValue = preferences.getString(key);
    if (legacyValue == null || legacyValue.isEmpty) return;

    await _secureStorage.write(key: key, value: legacyValue);
    final confirmedValue = await _secureStorage.read(key: key);
    if (confirmedValue == legacyValue) {
      await preferences.remove(key);
    }
  }

  Future<AppCredentials> loadCredentials() async {
    await migrateSensitiveValues();
    final preferences = await SharedPreferences.getInstance();
    return AppCredentials(
      anthropicApiKey: await _secureStorage.read(key: anthropicKey) ?? '',
      tursoUrl: preferences.getString(tursoUrlKey) ?? '',
      tursoToken: await _secureStorage.read(key: tursoTokenKey) ?? '',
    );
  }

  Future<void> saveCredentials(AppCredentials credentials) async {
    final preferences = await SharedPreferences.getInstance();
    await _secureStorage.write(
      key: anthropicKey,
      value: credentials.anthropicApiKey,
    );
    await _secureStorage.write(
      key: tursoTokenKey,
      value: credentials.tursoToken,
    );
    await preferences.setString(tursoUrlKey, credentials.tursoUrl);
    await preferences.remove(anthropicKey);
    await preferences.remove(tursoTokenKey);
  }

  Future<AppSettings> loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    return AppSettings(
      goalWeight: preferences.getDouble('goal_weight') ?? 96,
      goalFat: preferences.getDouble('goal_fat') ?? 20,
      minWeight: preferences.getDouble('min_weight') ?? 80,
      targetWeeklyGainMin: preferences.getDouble(targetMinKey) ?? 0.15,
      targetWeeklyGainMax: preferences.getDouble(targetMaxKey) ?? 0.30,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setDouble('goal_weight', settings.goalWeight),
      preferences.setDouble('goal_fat', settings.goalFat),
      preferences.setDouble('min_weight', settings.minWeight),
      preferences.setDouble(targetMinKey, settings.targetWeeklyGainMin),
      preferences.setDouble(targetMaxKey, settings.targetWeeklyGainMax),
    ]);
  }
}

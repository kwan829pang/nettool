import 'package:shared_preferences/shared_preferences.dart';

/// Persists user acknowledgment of authorized-use requirements.
class AuthorizedUseConsentService {
  static const _key = 'authorized_use_consent_v1';

  Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> grantConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

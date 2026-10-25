import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';

class AccountRepository {
  static const _keyAccounts = 'mn_accounts';
  static const _keyPasswordPrefix = 'mn_account_pw_';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  AccountRepository(this._prefs, [FlutterSecureStorage? secure])
    : _secure = secure ?? const FlutterSecureStorage();

  bool needsPasswordMigration() =>
      _prefs.getString(_keyAccounts)?.contains('"password"') ?? false;

  List<Account> loadAccounts() {
    final jsonString = _prefs.getString(_keyAccounts);
    if (jsonString == null) return [];

    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => Account.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveAccounts(List<Account> accounts) async {
    final list = accounts
        .map((e) => {'id': e.id, 'username': e.username})
        .toList();
    await _prefs.setString(_keyAccounts, jsonEncode(list));

    for (final account in accounts) {
      if (account.password.isEmpty) continue;
      await _secure.write(
        key: '$_keyPasswordPrefix${account.id}',
        value: account.password,
      );
    }
  }

  Future<String> loadPassword(String accountId) async {
    return await _secure.read(key: '$_keyPasswordPrefix$accountId') ?? '';
  }

  Future<void> deletePassword(String accountId) async {
    await _secure.delete(key: '$_keyPasswordPrefix$accountId');
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';

class AccountRepository {
  static const _keyAccounts = 'mn_accounts';
  final SharedPreferences _prefs;

  AccountRepository(this._prefs);

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
    final list = accounts.map((e) => e.toJson()).toList();
    final jsonString = jsonEncode(list);
    await _prefs.setString(_keyAccounts, jsonString);
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../repositories/account_repository.dart';
import '../services/runtime_manager.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AccountRepository(prefs);
});

/// True once the initial async load (account list + passwords from secure
/// storage) has finished.  The account dialog keeps Save disabled until this
/// flips, so an edit can never be submitted against a half-loaded account.
final accountsLoadedProvider = StateProvider<bool>((ref) => false);

final accountsProvider = StateNotifierProvider<AccountsNotifier, List<Account>>(
  (ref) {
    final repo = ref.watch(accountRepositoryProvider);
    return AccountsNotifier(repo, ref);
  },
);

class AccountsNotifier extends StateNotifier<List<Account>> {
  final AccountRepository _repo;
  final Ref _ref;

  AccountsNotifier(this._repo, this._ref) : super([]) {
    // Passwords are read from secure storage, which is async, so the initial
    // load cannot complete synchronously.
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final accounts = await Future.wait(
        _repo.loadAccounts().map((account) async {
          final password = await _repo.loadPassword(account.id);
          return account.copyWith(password: password);
        }),
      );

      state = accounts;
      if (_repo.needsPasswordMigration()) {
        await _repo.saveAccounts(accounts);
      }

      final runtime = _ref.read(runtimeManagerProvider.notifier);
      for (final account in accounts) {
        runtime.ensureHandle(account);
      }
      runtime.checkServiceCleanup();
    } finally {
      _ref.read(accountsLoadedProvider.notifier).state = true;
    }
  }

  bool _isUsernameTaken(String username, {String? exceptId}) {
    final normalized = username.trim().toLowerCase();
    return state.any(
      (a) => a.id != exceptId && a.username.trim().toLowerCase() == normalized,
    );
  }

  Future<void> addAccount(String username, String password) async {
    if (username.trim().isEmpty) return;
    if (_isUsernameTaken(username)) return;

    final newAccount = Account.create(username: username, password: password);
    _ref.read(runtimeManagerProvider.notifier).ensureHandle(newAccount);

    state = [...state, newAccount];
    await _repo.saveAccounts(state);
  }

  Future<void> removeAccount(String id) async {
    _ref.read(runtimeManagerProvider.notifier).destroyHandle(id);

    state = state.where((a) => a.id != id).toList();
    await _repo.deletePassword(id);
    await _repo.saveAccounts(state);
  }

  Future<void> updateAccount(Account updated) async {
    if (_isUsernameTaken(updated.username, exceptId: updated.id)) return;

    state = [
      for (final a in state)
        if (a.id == updated.id) updated else a,
    ];
    await _repo.saveAccounts(state);
  }
}

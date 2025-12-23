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
    _load();
  }

  void _load() {
    state = _repo.loadAccounts();

    final runtime = _ref.read(runtimeManagerProvider.notifier);
    for (final account in state) {
      runtime.ensureHandle(account);
    }
    runtime.checkServiceCleanup();
  }

  Future<void> addAccount(String username, String password) async {
    final newAccount = Account.create(username: username, password: password);
    _ref.read(runtimeManagerProvider.notifier).ensureHandle(newAccount);

    state = [...state, newAccount];
    await _repo.saveAccounts(state);
  }

  Future<void> removeAccount(String id) async {
    _ref.read(runtimeManagerProvider.notifier).destroyHandle(id);

    state = state.where((a) => a.id != id).toList();
    await _repo.saveAccounts(state);
  }

  Future<void> updateAccount(Account updated) async {
    state = [
      for (final a in state)
        if (a.id == updated.id) updated else a,
    ];
    await _repo.saveAccounts(state);
  }
}

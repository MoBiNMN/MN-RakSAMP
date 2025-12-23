import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/account.dart';
import '../providers/accounts_provider.dart';
import '../services/runtime_manager.dart';
import 'account_screen.dart';

import '../providers/theme_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final runningAccounts = ref.watch(runtimeManagerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MN-RakSAMP'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(context: context, builder: (_) => const AccountDialog());
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          accounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_add_disabled,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.2),
                      ),
                      const Gap(16),
                      Text(
                        'No accounts added',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: accounts.length,
                  separatorBuilder: (_, __) => const Gap(12),
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    final isRunning = runningAccounts.contains(account.id);

                    return _AccountCard(
                      account: account,
                      isRunning: isRunning,
                    ).animate().fadeIn(delay: (50 * index).ms).slideX();
                  },
                ),

          Positioned(
            left: 12,
            bottom: 12,
            child: GestureDetector(
              onTap: () => launchUrl(Uri.parse("https://t.me/NighTBlouD")),
              child: Text(
                'By @NighTBlouD',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withOpacity(0.65),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final Account account;
  final bool isRunning;

  const _AccountCard({required this.account, required this.isRunning});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AccountScreen(account: account)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status Indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRunning
                      ? const Color(0xFF00FF88)
                      : colorScheme.error,
                  boxShadow: [
                    if (isRunning)
                      BoxShadow(
                        color: const Color(0xFF00FF88).withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                  ],
                ),
              ),
              const Gap(16),
              // Account Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      isRunning ? 'Running' : 'Offline',
                      style: TextStyle(
                        color: isRunning
                            ? const Color(0xFF00FF88)
                            : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AccountDialog(account: account),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: colorScheme.error,
                onPressed: () {
                  if (isRunning) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Stop the account before deleting.'),
                      ),
                    );
                    return;
                  }

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Account'),
                      content: Text(
                        'Are you sure you want to delete "${account.username}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(accountsProvider.notifier)
                                .removeAccount(account.id);
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.error,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (isRunning)
                IconButton(
                  icon: const Icon(
                    Icons.stop_circle_outlined,
                    color: Colors.orange,
                  ),
                  onPressed: () {
                    ref
                        .read(runtimeManagerProvider.notifier)
                        .stopAccount(account.id);
                  },
                )
              else
                IconButton(
                  icon: Icon(
                    Icons.play_circle_fill,
                    color: colorScheme.primary,
                  ),
                  onPressed: () {
                    ref
                        .read(runtimeManagerProvider.notifier)
                        .startAccount(account);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountDialog extends ConsumerStatefulWidget {
  final Account? account;

  const AccountDialog({super.key, this.account});

  @override
  ConsumerState<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends ConsumerState<AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;
  bool _isObscure = true;

  @override
  void initState() {
    super.initState();
    _userCtrl = TextEditingController(text: widget.account?.username ?? '');
    _passCtrl = TextEditingController(text: widget.account?.password ?? '');
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (widget.account == null) {
        ref
            .read(accountsProvider.notifier)
            .addAccount(_userCtrl.text, _passCtrl.text);
      } else {
        final updated = widget.account!.copyWith(
          username: _userCtrl.text,
          password: _passCtrl.text,
        );
        ref.read(accountsProvider.notifier).updateAccount(updated);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.account == null ? 'Add Account' : 'Edit Account'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _userCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final accounts = ref.read(accountsProvider);
                  final alreadyExists = accounts.any(
                    (a) =>
                        a.username.toLowerCase() == v.toLowerCase() &&
                        a.id != widget.account?.id,
                  );
                  if (alreadyExists) return 'Username already exists';
                  return null;
                },
              ),
              const Gap(16),
              TextFormField(
                controller: _passCtrl,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

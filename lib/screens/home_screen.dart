import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/account.dart';
import '../providers/accounts_provider.dart';
import '../services/runtime_manager.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';

final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final runningAccounts = ref.watch(runtimeManagerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: _AddAccountFab(
        onPressed: () {
          showDialog(context: context, builder: (_) => const AccountDialog());
        },
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 150,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.16),
                        colorScheme.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Column(
              children: [
                const _HomeHeader(),
                Expanded(
                  child: accounts.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: accounts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final account = accounts[index];
                            final isRunning = runningAccounts.contains(
                              account.id,
                            );

                            return _EntranceFade(
                              index: index,
                              child: _AccountCard(
                                account: account,
                                isRunning: isRunning,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        children: [
          Text(
            'MN-RakSAMP',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: colorScheme.primary.withValues(alpha: 0.55),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 56,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
            ),
          ),
          const SizedBox(height: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => launchUrl(
                Uri.parse('https://t.me/NighTBlouD'),
                mode: LaunchMode.externalApplication,
              ),
              child: FutureBuilder<PackageInfo>(
                future: _packageInfo,
                builder: (context, snapshot) {
                  final version = snapshot.data?.version;
                  return Text(
                    version == null
                        ? '@NighTBlouD'
                        : 'v$version  ·  @NighTBlouD',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntranceFade extends StatefulWidget {
  final int index;
  final Widget child;

  const _EntranceFade({required this.index, required this.child});

  @override
  State<_EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<_EntranceFade> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: (widget.index * 55).clamp(0, 400));
    Future.delayed(delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _shown ? 1.0 : 0.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: t),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 18),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

class _StatusDot extends StatefulWidget {
  final bool isRunning;

  const _StatusDot({required this.isRunning});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isRunning) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!widget.isRunning) {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.error.withValues(alpha: 0.85),
        ),
      );
    }

    return SizedBox(
      width: 12,
      height: 12,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_controller.value);
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.runningGreen,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.runningGreen.withValues(
                    alpha: 0.55 - 0.35 * t,
                  ),
                  blurRadius: 6 + 8 * t,
                  spreadRadius: 2 + 4 * t,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

final _sampColorRegex = RegExp(r'\{([0-9A-Fa-f]{6})\}');

List<TextSpan> lastChatSpans(String logs, Color defaultColor) {
  final trimmed = logs.trimRight();
  if (trimmed.isEmpty) return const [];

  final nl = trimmed.lastIndexOf('\n');

  var currentColor = defaultColor;
  if (nl > 0) {
    final start = nl > 4000 ? nl - 4000 : 0;
    final before = trimmed.substring(start, nl);
    final last = _sampColorRegex.allMatches(before).lastOrNull;
    if (last != null) {
      currentColor = Color(int.parse('0xFF${last.group(1)}'));
    }
  }

  final line = (nl >= 0 ? trimmed.substring(nl + 1) : trimmed)
      .trim()
      .replaceFirstMapped(
        RegExp(r'^((?:\{[0-9A-Fa-f]{6}\})*)\[\d{2}:\d{2}:\d{2}\]\s?'),
        (m) => m.group(1)!,
      );

  final spans = <TextSpan>[];
  var lastEnd = 0;

  for (final match in _sampColorRegex.allMatches(line)) {
    if (match.start > lastEnd) {
      spans.add(
        TextSpan(
          text: line.substring(lastEnd, match.start),
          style: TextStyle(color: currentColor),
        ),
      );
    }
    currentColor = Color(int.parse('0xFF${match.group(1)}'));
    lastEnd = match.end;
  }

  if (lastEnd < line.length) {
    spans.add(
      TextSpan(
        text: line.substring(lastEnd),
        style: TextStyle(color: currentColor),
      ),
    );
  }

  return spans;
}

class _AccountCard extends ConsumerWidget {
  final Account account;
  final bool isRunning;

  const _AccountCard({required this.account, required this.isRunning});

  static const double _compactBreakpoint = 520;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < _compactBreakpoint;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (compact)
                    _buildCompactHeader(context, ref, colorScheme)
                  else
                    _buildWideHeader(context, ref, colorScheme),
                  if (isRunning) ...[
                    const SizedBox(height: 8),
                    _buildStatusLine(context, ref, colorScheme, compact),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWideHeader(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        _StatusDot(isRunning: isRunning),
        const SizedBox(width: 16),
        Expanded(
          child: Row(
            children: [
              Flexible(child: _nameText()),
              const SizedBox(width: 8),
              _statusBadge(colorScheme),
            ],
          ),
        ),
        ..._actions(context, ref, colorScheme),
      ],
    );
  }

  Widget _buildCompactHeader(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatusDot(isRunning: isRunning),
            const SizedBox(width: 12),
            Expanded(child: _nameText()),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _statusBadge(colorScheme),
            const Spacer(),
            ..._actions(context, ref, colorScheme),
          ],
        ),
      ],
    );
  }

  Widget _nameText() => Text(
    account.username,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  );

  Widget _statusBadge(ColorScheme colorScheme) {
    final color = isRunning
        ? AppTheme.runningGreen
        : colorScheme.onSurface.withValues(alpha: 0.6);
    ;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        isRunning ? 'Running' : 'Offline',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) {
    return [
      IconButton(
        icon: const Icon(Icons.edit),
        tooltip: 'Edit',
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AccountDialog(account: account),
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
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
      IconButton(
        icon: Icon(
          isRunning ? Icons.stop_circle_outlined : Icons.play_circle_fill,
          color: isRunning ? Colors.orange : colorScheme.primary,
        ),
        tooltip: isRunning ? 'Stop' : 'Start',
        onPressed: () {
          final manager = ref.read(runtimeManagerProvider.notifier);
          if (isRunning) {
            manager.stopAccount(account.id);
          } else {
            manager.startAccount(account);
          }
        },
      ),
    ];
  }

  Widget _buildStatusLine(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    bool compact,
  ) {
    final runtime = ref.read(runtimeManagerProvider.notifier);
    final leftPad = compact ? 0.0 : 28.0;

    return Padding(
      padding: EdgeInsets.only(left: leftPad),
      child: StreamBuilder<String>(
        stream: runtime.getLogStream(account.id),
        initialData: '',
        builder: (context, snapshot) {
          final spans = lastChatSpans(
            snapshot.data ?? '',
            colorScheme.onSurface,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: spans.isEmpty
                    ? Text(
                        'Waiting for messages...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      )
                    : Text.rich(
                        TextSpan(
                          children: spans,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            fontFamily: 'monospace',
                          ),
                        ),
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddAccountFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddAccountFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          mouseCursor: SystemMouseCursors.click,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Color(0xFF04120B)),
                SizedBox(width: 8),
                Text(
                  'Add Account',
                  style: TextStyle(
                    color: Color(0xFF04120B),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (context, t, child) =>
                Transform.scale(scale: t, child: child),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.person_add_alt_1,
                size: 44,
                color: colorScheme.primary.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No accounts yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "Add Account" to get started.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
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
    final accountsLoaded = ref.watch(accountsLoadedProvider);

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
                autofocus: widget.account == null,
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _passCtrl,
                obscureText: _isObscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
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
        ElevatedButton(
          onPressed: accountsLoaded ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

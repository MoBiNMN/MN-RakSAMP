import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../models/account.dart';
import '../services/runtime_manager.dart';
import '../providers/log_settings_provider.dart';
import '../theme/app_theme.dart';

class _HistoryIntent extends Intent {
  final int direction;

  const _HistoryIntent(this.direction);
}

class AccountScreen extends ConsumerStatefulWidget {
  final Account account;
  const AccountScreen({super.key, required this.account});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _cmdCtrl = TextEditingController();
  final FocusNode _cmdFocus = FocusNode();
  final List<String> _history = [];
  int _historyIndex = -1;

  bool _pointerDown = false;

  void _addToHistory(String val) {
    if (val.trim().isEmpty) return;
    if (_history.isNotEmpty && _history.first == val) return;
    _history.insert(0, val);
    if (_history.length > 100) _history.removeLast();
    _historyIndex = -1;
  }

  void _moveHistory(int direction) {
    if (_history.isEmpty) return;
    final newIndex = _historyIndex + direction;
    if (newIndex >= 0 && newIndex < _history.length) {
      _historyIndex = newIndex;
      _cmdCtrl.text = _history[_historyIndex];
      _cmdCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _cmdCtrl.text.length),
      );
    } else if (newIndex == -1) {
      _historyIndex = -1;
      _cmdCtrl.clear();
    }
  }

  void _send() {
    final val = _cmdCtrl.text;
    if (val.trim().isNotEmpty) {
      ref
          .read(runtimeManagerProvider.notifier)
          .sendChat(widget.account.id, val);
      _addToHistory(val);
      _cmdCtrl.clear();
    }
    _cmdFocus.requestFocus();
  }

  List<TextSpan> _parseSampColors(String text, bool showTimestamps) {
    if (!showTimestamps) {
      final tsRegex = RegExp(r'\[\d{2}:\d{2}:\d{2}\]\s');
      text = text.replaceAll(tsRegex, '');
    }

    final List<TextSpan> spans = [];
    final RegExp colorRegex = RegExp(r'\{([0-9A-Fa-f]{6})\}');

    int lastMatchEnd = 0;
    Color currentColor = const Color(0xFFFFFFFF);

    final Iterable<RegExpMatch> matches = colorRegex.allMatches(text);

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: TextStyle(color: currentColor, fontFamily: 'monospace'),
          ),
        );
      }

      final colorHex = match.group(1)!;
      try {
        currentColor = Color(int.parse('0xFF$colorHex'));
      } catch (e) {
        currentColor = Colors.white;
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: TextStyle(color: currentColor, fontFamily: 'monospace'),
        ),
      );
    }

    return spans;
  }

  @override
  void initState() {
    super.initState();
    _cmdFocus.addListener(_refocusInput);
  }

  void _refocusInput() {
    if (_cmdFocus.hasFocus || _pointerDown || !mounted) return;
    if (!ref.read(runtimeManagerProvider).contains(widget.account.id)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _cmdFocus.hasFocus || _pointerDown) return;
      if (!ref.read(runtimeManagerProvider).contains(widget.account.id)) {
        return;
      }
      _cmdFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _cmdFocus.removeListener(_refocusInput);
    _scrollCtrl.dispose();
    _cmdCtrl.dispose();
    _cmdFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runningIds = ref.watch(runtimeManagerProvider);
    final isRunning = runningIds.contains(widget.account.id);
    final runtimeManager = ref.read(runtimeManagerProvider.notifier);
    final logSettings = ref.watch(logSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.account.username),
            Text(
              isRunning ? 'Running' : 'Offline',
              style: TextStyle(
                fontSize: 12,
                color: isRunning ? AppTheme.runningGreen : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          ExcludeFocus(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    logSettings.showTimestamps
                        ? Icons.access_time_filled
                        : Icons.access_time,
                  ),
                  tooltip: 'Toggle Timestamps',
                  onPressed: () =>
                      ref.read(logSettingsProvider.notifier).toggleTimestamps(),
                ),
                IconButton(
                  icon: Icon(
                    logSettings.autoScroll
                        ? Icons.vertical_align_bottom
                        : Icons.pause,
                  ),
                  tooltip: 'Auto-scroll',
                  onPressed: () =>
                      ref.read(logSettingsProvider.notifier).toggleAutoScroll(),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Clear Logs',
                  onPressed: () {
                    runtimeManager.clearLogs(widget.account.id);
                  },
                ),
                IconButton(
                  icon: Icon(
                    isRunning ? Icons.stop_circle : Icons.play_circle_fill,
                  ),
                  color: isRunning
                      ? Colors.redAccent
                      : Theme.of(context).colorScheme.primary,
                  tooltip: isRunning ? 'Stop' : 'Start',
                  onPressed: () {
                    if (isRunning) {
                      runtimeManager.stopAccount(widget.account.id);
                    } else {
                      runtimeManager.startAccount(widget.account);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: Listener(
        onPointerDown: (_) => _pointerDown = true,
        onPointerUp: (_) => _pointerDown = false,
        onPointerCancel: (_) => _pointerDown = false,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<String>(
                stream: runtimeManager.getLogStream(widget.account.id),
                initialData: runtimeManager.getLogs(widget.account.id),
                builder: (context, snapshot) {
                  final data = snapshot.data ?? '';
                  if (logSettings.autoScroll) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollCtrl.hasClients) {
                        _scrollCtrl.jumpTo(
                          _scrollCtrl.position.maxScrollExtent,
                        );
                      }
                    });
                  }
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1520),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.07),
                      ),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: data.isNotEmpty
                        ? SingleChildScrollView(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.all(12),
                            child: SelectableText.rich(
                              TextSpan(
                                children: _parseSampColors(
                                  data,
                                  logSettings.showTimestamps,
                                ),
                              ),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          )
                        : const Center(child: Text('Chats...')),
                  );
                },
              ),
            ),
            if (isRunning)
              Shortcuts(
                shortcuts: <LogicalKeySet, Intent>{
                  LogicalKeySet(LogicalKeyboardKey.arrowUp):
                      const _HistoryIntent(1),
                  LogicalKeySet(LogicalKeyboardKey.arrowDown):
                      const _HistoryIntent(-1),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    _HistoryIntent: CallbackAction<_HistoryIntent>(
                      onInvoke: (intent) => _moveHistory(intent.direction),
                    ),
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cmdCtrl,
                            focusNode: _cmdFocus,
                            autofocus: true,
                            textInputAction: TextInputAction.send,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Type a message...',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        ExcludeFocus(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (Platform.isAndroid) ...[
                                IconButton(
                                  onPressed: () => _moveHistory(1),
                                  icon: const Icon(Icons.arrow_upward),
                                  tooltip: 'Previous message',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  onPressed: () => _moveHistory(-1),
                                  icon: const Icon(Icons.arrow_downward),
                                  tooltip: 'Next message',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                              IconButton(
                                onPressed: () {
                                  _cmdCtrl.text += '/';
                                  _cmdFocus.requestFocus();
                                },
                                icon: const Text(
                                  '/',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                tooltip: 'Type /',
                              ),
                              IconButton.filled(
                                onPressed: _send,
                                icon: const Icon(Icons.send),
                                tooltip: 'Send',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

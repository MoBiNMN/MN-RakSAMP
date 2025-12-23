import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../models/account.dart';
import '../services/runtime_manager.dart';
import '../providers/log_settings_provider.dart';

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
        TextSelection.fromPosition(
          TextPosition(offset: _cmdCtrl.text.length),
        ).base,
      );
    } else if (newIndex == -1) {
      _historyIndex = -1;
      _cmdCtrl.clear();
    }
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
  void dispose() {
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
                color: isRunning ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
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
            icon: Icon(isRunning ? Icons.stop_circle : Icons.play_circle_fill),
            color: isRunning ? Colors.redAccent : Colors.greenAccent,
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
      body: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: (event) {
          if (isRunning &&
              event.logicalKey.keyLabel.length == 1 &&
              !_cmdFocus.hasFocus) {
            _cmdFocus.requestFocus();
          }
        },
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
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
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
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          )
                        : const Center(child: Text('Chats...')),
                  );
                },
              ),
            ),
            if (isRunning)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cmdCtrl,
                        focusNode: _cmdFocus,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            runtimeManager.sendChat(widget.account.id, val);
                            _addToHistory(val);
                            _cmdCtrl.clear();
                          }
                        },
                      ),
                    ),
                    // const SizedBox(width: 1),
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
                    IconButton(
                      onPressed: () => _moveHistory(1),
                      icon: const Icon(Icons.arrow_upward),
                      tooltip: 'History Up',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      onPressed: () => _moveHistory(-1),
                      icon: const Icon(Icons.arrow_downward),
                      tooltip: 'History Down',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    //     const SizedBox(width: 2),
                    IconButton.filled(
                      onPressed: () {
                        final val = _cmdCtrl.text;
                        if (val.trim().isNotEmpty) {
                          runtimeManager.sendChat(widget.account.id, val);
                          _addToHistory(val);
                          _cmdCtrl.clear();
                        }
                      },
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

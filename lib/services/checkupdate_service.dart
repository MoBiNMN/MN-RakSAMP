import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class GitHubAsset {
  final String name;
  final String url;
  final int size;

  GitHubAsset(this.name, this.url, this.size);
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String body;
  final List<GitHubAsset> assets;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.body,
    required this.assets,
  });

  bool get hasUpdate => _isNewer(latestVersion, currentVersion);

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map(int.parse).toList();
    final c = current.split('.').map(int.parse).toList();

    for (int i = 0; i < l.length; i++) {
      final li = i < l.length ? l[i] : 0;
      final ci = i < c.length ? c[i] : 0;
      if (li > ci) return true;
      if (li < ci) return false;
    }
    return false;
  }
}

class CheckUpdateService {
  Future<UpdateInfo> check() async {
    final pkg = await PackageInfo.fromPlatform();

    final res = await http.get(
      Uri.parse(
        'https://api.github.com/repos/MoBiNMN/MN-RakSAMP/releases/latest',
      ),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch update info');
    }

    final json = jsonDecode(res.body);

    return UpdateInfo(
      currentVersion: pkg.version,
      latestVersion: (json['tag_name'] as String).replaceFirst('v', ''),
      body: json['body'] ?? '',
      assets: (json['assets'] as List)
          .map(
            (a) => GitHubAsset(a['name'], a['browser_download_url'], a['size']),
          )
          .toList(),
    );
  }
}

class UpdateDialog extends StatelessWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Available',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Current version: ${info.currentVersion}'),
                    const SizedBox(width: 16),
                    Text(
                      'Latest version: ${info.latestVersion}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "What's New",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  info.body.isEmpty ? '-' : info.body,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                if (info.assets.isNotEmpty) ...[
                  Text(
                    'Downloads',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...info.assets.map(
                    (a) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: InkWell(
                        onTap: () => launchUrl(Uri.parse(a.url)),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: theme.cardColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                '${(a.size / 1024 / 1024).toStringAsFixed(1)} MB',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.download, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Later', style: TextStyle(fontSize: 16)),
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

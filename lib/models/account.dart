import 'dart:math';

class Account {
  final String id;
  final String username;
  final String password;

  Account({required this.id, required this.username, required this.password});

  static String _newId() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  factory Account.create({required String username, required String password}) {
    return Account(id: _newId(), username: username, password: password);
  }

  Account copyWith({String? username, String? password}) {
    return Account(
      id: id,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'username': username};
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      username: json['username'] as String,
      password: json['password'] as String? ?? '',
    );
  }
}

import 'package:uuid/uuid.dart';

class Account {
  final String id;
  final String username;
  final String password;

  Account({required this.id, required this.username, required this.password});

  factory Account.create({required String username, required String password}) {
    return Account(
      id: const Uuid().v4(),
      username: username,
      password: password,
    );
  }

  Account copyWith({String? username, String? password}) {
    return Account(
      id: id,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'username': username, 'password': password};
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
    );
  }
}

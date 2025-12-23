import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef MMHandle = Pointer<Void>;

class MN {
  late final DynamicLibrary _lib;
  late final bool Function(MMHandle) _mnIsRunning;
  late final MMHandle Function() _mnCreate;
  late final void Function(MMHandle) _mnDestroy;
  late final int Function(MMHandle, Pointer<Utf8>, Pointer<Utf8>) _mnStart;
  late final void Function(MMHandle) _mnStop;
  late final Pointer<Utf8> Function(MMHandle) _mnGetLogs;
  late final void Function(MMHandle) _mnClearLogs;
  late final void Function(MMHandle, Pointer<Utf8>) _mnSendChat;
  late final MMHandle Function(Pointer<Utf8>) _mnFindHandle;

  static final MN _instance = MN._internal();
  factory MN() => _instance;

  MN._internal() {
    _lib = _loadLib();

    _mnIsRunning = _lib
        .lookupFunction<Bool Function(MMHandle), bool Function(MMHandle)>(
          'mn_isrunning',
        );

    _mnCreate = _lib.lookupFunction<MMHandle Function(), MMHandle Function()>(
      'mn_create',
    );

    _mnDestroy = _lib
        .lookupFunction<Void Function(MMHandle), void Function(MMHandle)>(
          'mn_destroy',
        );

    _mnStart = _lib
        .lookupFunction<
          Int32 Function(MMHandle, Pointer<Utf8>, Pointer<Utf8>),
          int Function(MMHandle, Pointer<Utf8>, Pointer<Utf8>)
        >('mn_start');

    _mnStop = _lib
        .lookupFunction<Void Function(MMHandle), void Function(MMHandle)>(
          'mn_stop',
        );

    _mnGetLogs = _lib
        .lookupFunction<
          Pointer<Utf8> Function(MMHandle),
          Pointer<Utf8> Function(MMHandle)
        >('mn_get_logs');

    _mnClearLogs = _lib
        .lookupFunction<Void Function(MMHandle), void Function(MMHandle)>(
          'mn_clear_logs',
        );

    _mnSendChat = _lib
        .lookupFunction<
          Void Function(MMHandle, Pointer<Utf8>),
          void Function(MMHandle, Pointer<Utf8>)
        >('mn_sendchat');

    _mnFindHandle = _lib
        .lookupFunction<
          MMHandle Function(Pointer<Utf8>),
          MMHandle Function(Pointer<Utf8>)
        >('mn_find_handle');
  }

  static DynamicLibrary _loadLib() {
    if (Platform.isWindows) {
      return DynamicLibrary.open('MNRakSAMPCore.dll');
    } else if (Platform.isAndroid) {
      return DynamicLibrary.open('libMNRakSAMPCore.so');
    }
    throw UnsupportedError(
      'Platform not supported: ${Platform.operatingSystem}',
    );
  }

  MMHandle create() => _mnCreate();

  void start(MMHandle h, String username, String password) {
    final u = username.toNativeUtf8();
    final p = password.toNativeUtf8();

    _mnStart(h, u, p);

    malloc.free(u);
    malloc.free(p);
  }

  bool isRunning(MMHandle h) {
    return _mnIsRunning(h);
  }

  void stop(MMHandle h) => _mnStop(h);
  void destroy(MMHandle h) => _mnDestroy(h);

  String getLogs(MMHandle h) {
    final ptr = _mnGetLogs(h);
    return ptr == nullptr ? '' : ptr.toDartString();
  }

  void clearLogs(MMHandle h) => _mnClearLogs(h);

  void sendChat(MMHandle h, String text) {
    final ptr = text.toNativeUtf8();
    _mnSendChat(h, ptr);
    malloc.free(ptr);
  }

  MMHandle findHandle(String username) {
    final ptr = username.toNativeUtf8();
    final h = _mnFindHandle(ptr);
    malloc.free(ptr);
    return h;
  }
}

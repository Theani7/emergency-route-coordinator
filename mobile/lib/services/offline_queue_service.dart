import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  Box get _box => Hive.box('offline_queue');
  Dio? _dio;
  bool _isReplaying = false;

  void init(Dio dio) {
    _dio = dio;
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        replay();
      }
    });
  }

  Future<void> enqueue(String path, String method, dynamic data) async {
    final request = {
      'path': path,
      'method': method,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _box.add(request);
  }

  Future<Map<dynamic, dynamic>?> dequeue() async {
    if (_box.isEmpty) return null;
    final key = _box.keys.first;
    final request = _box.get(key);
    await _box.delete(key);
    return request;
  }

  Future<void> replay() async {
    if (_dio == null || _box.isEmpty || _isReplaying) return;

    _isReplaying = true;
    try {
      final keys = _box.keys.toList();
      for (final key in keys) {
        final request = _box.get(key);
        if (request != null) {
          final path = request['path'];
          final method = request['method'];
          final data = request['data'];

          try {
            if (method == 'POST') {
              await _dio!.post(path, data: data);
            } else if (method == 'PATCH') {
              await _dio!.patch(path, data: data);
            } else if (method == 'PUT') {
              await _dio!.put(path, data: data);
            }
            await _box.delete(key);
          } catch (e) {
            if (e is DioException &&
                (e.type == DioExceptionType.connectionError ||
                 e.type == DioExceptionType.connectionTimeout)) {
              break;
            } else {
              await _box.delete(key);
            }
          }
        }
      }
    } finally {
      _isReplaying = false;
    }
  }
}

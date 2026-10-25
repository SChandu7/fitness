import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Where the Django API lives. Default is the live server, so a plain
/// `flutter build apk` talks to production. Local backend:
///   flutter run --dart-define=EXERLIO_API=http://10.0.2.2:8000/api/exerlio/v1
const String kApiBase = String.fromEnvironment(
  'EXERLIO_API',
  defaultValue: 'https://api.chandus7.in/api/exerlio/v1',
);

class ApiError implements Exception {
  final String message;
  final int status;
  const ApiError(this.message, [this.status = 0]);
  bool get unauthorized => status == 401;
  @override
  String toString() => message;
}

typedef Json = Map<String, dynamic>;

/// One small HTTP client for the whole app.
class Api {
  Api._();
  static final Api i = Api._();

  String? token;
  void Function()? onUnauthorized;
  final _client = http.Client();
  static const _timeout = Duration(seconds: 20);

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Token $token',
      };

  Uri _uri(String path) => Uri.parse('$kApiBase/${path.startsWith('/') ? path.substring(1) : path}');

  Future<dynamic> get(String path) => _send(() => _client.get(_uri(path), headers: _headers));
  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => _client.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => _client.put(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
  Future<dynamic> patch(String path, [Object? body]) =>
      _send(() => _client.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
  Future<dynamic> delete(String path) => _send(() => _client.delete(_uri(path), headers: _headers));

  /// Multipart upload: photos, reels, stories, meal scans.
  Future<dynamic> upload(String path, {Map<String, String> fields = const {}, Map<String, File> files = const {}}) {
    return _send(() async {
      final req = http.MultipartRequest('POST', _uri(path));
      if (token != null) req.headers['Authorization'] = 'Token $token';
      req.headers['Accept'] = 'application/json';
      req.fields.addAll(fields);
      for (final e in files.entries) {
        req.files.add(await http.MultipartFile.fromPath(e.key, e.value.path));
      }
      return http.Response.fromStream(await req.send());
    }, timeout: const Duration(seconds: 90));
  }

  /// Raw text download (CSV export).
  Future<String> text(String path) async {
    final res = await _client.get(_uri(path), headers: _headers).timeout(_timeout);
    if (res.statusCode >= 400) throw ApiError('Could not download that file.', res.statusCode);
    return utf8.decode(res.bodyBytes);
  }

  Future<dynamic> _send(Future<http.Response> Function() run, {Duration timeout = _timeout}) async {
    http.Response res;
    try {
      res = await run().timeout(timeout);
    } on TimeoutException {
      throw const ApiError('The request timed out. Please try again.');
    } on SocketException {
      throw const ApiError('No connection to the server. Check your internet and try again.');
    } on http.ClientException {
      throw const ApiError('Could not reach the server. Please try again.');
    }

    if (res.statusCode == 204 || res.body.isEmpty) return null;
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      if (res.statusCode >= 400) throw ApiError('Server error (${res.statusCode}).', res.statusCode);
      return null;
    }
    if (res.statusCode >= 400) {
      final msg = data is Map
          ? (data['message'] ?? data['detail'] ?? 'Something went wrong.').toString()
          : 'Something went wrong.';
      if (res.statusCode == 401) onUnauthorized?.call();
      throw ApiError(msg, res.statusCode);
    }
    return data;
  }
}

/// Safe reads from JSON maps — never crash on a missing or wrong-typed field.
extension JsonX on Map {
  String s(String k, [String d = '']) => this[k] == null ? d : this[k].toString();
  int i(String k, [int d = 0]) {
    final v = this[k];
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? double.tryParse('$v')?.round() ?? d;
  }

  double d(String k, [double d = 0]) {
    final v = this[k];
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? d;
  }

  bool b(String k, [bool d = false]) => this[k] is bool ? this[k] as bool : d;
  Json m(String k) => this[k] is Map ? Map<String, dynamic>.from(this[k] as Map) : <String, dynamic>{};
  List<Json> l(String k) => this[k] is List
      ? (this[k] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Json>[];
  List<String> strs(String k) => this[k] is List ? (this[k] as List).map((e) => '$e').toList() : <String>[];
  bool has(String k) => this[k] != null;
}

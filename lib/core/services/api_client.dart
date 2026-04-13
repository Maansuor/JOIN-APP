import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ══════════════════════════════════════════════════════════════
//  ApiClient  — Capa de red centralizada
//
//  – Gestiona el base URL (XAMPP local / producción)
//  – Añade el token Authorization en cada request autenticado
//  – Decodifica respuestas JSON y lanza ApiException en errores
// ══════════════════════════════════════════════════════════════

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  // ── URL Base ─────────────────────────────────────────────
  // 10.0.2.2 = localhost desde el emulador Android
  // Para dispositivo físico: reemplaza con tu IP local (ej: 192.168.1.x)
  static const String _emulatorHost = 'http://10.0.2.2';
  static const String _apiPath = '/join/api';

  String get baseUrl {
    if (kIsWeb) return 'http://localhost/join/api';
    // En release, cambiar a la URL de producción
    return (_emulatorHost) + _apiPath;
  }

  // ── Token de sesión ───────────────────────────────────────
  String? _authToken;

  void setToken(String? token) => _authToken = token;
  bool get hasToken => _authToken != null;
  String? get token => _authToken;

  // ── Headers base ─────────────────────────────────────────
  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (_authToken != null) ...{
          'Authorization': 'Bearer $_authToken',
          'X-Authorization': 'Bearer $_authToken', // Fallback para Apache
        },
      };

  // ── GET ───────────────────────────────────────────────────
  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final uri = _buildUri(path, queryParams);
    debugPrint('→ GET $uri');
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException(
          503, 'Sin conexión al servidor. ¿Está XAMPP encendido?');
    } on http.ClientException catch (e) {
      throw ApiException(503, 'Error de red: ${e.message}');
    }
  }

  // ── POST ─────────────────────────────────────────────────
  Future<dynamic> post(String path, Map<String, dynamic> body,
      {Map<String, String>? queryParams}) async {
    final uri = _buildUri(path, queryParams);
    debugPrint('→ POST $uri ${jsonEncode(body)}');
    try {
      final response = await http
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException(503, 'Sin conexión al servidor');
    }
  }

  // ── PUT ──────────────────────────────────────────────────
  Future<dynamic> put(String path, Map<String, dynamic> body,
      {Map<String, String>? queryParams}) async {
    final uri = _buildUri(path, queryParams);
    debugPrint('→ PUT $uri');
    try {
      final response = await http
          .put(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException(503, 'Sin conexión al servidor');
    }
  }

  // ── DELETE ────────────────────────────────────────────────
  Future<dynamic> delete(String path,
      {Map<String, String>? queryParams}) async {
    final uri = _buildUri(path, queryParams);
    debugPrint('→ DELETE $uri');
    try {
      final response = await http
          .delete(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException(503, 'Sin conexión al servidor');
    }
  }

  // ── MULTIPART POST ────────────────────────────────────────
  Future<dynamic> postMultipart(String path, Map<String, String> body,
      {File? file, String fileField = 'photo', Map<String, String>? queryParams}) async {
    final uri = _buildUri(path, queryParams);
    debugPrint('→ POST MULTIPART $uri');
    try {
      final request = http.MultipartRequest('POST', uri);
      
      // Add text fields
      request.fields.addAll(body);
      
      // Add headers
      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
        request.headers['X-Authorization'] = 'Bearer $_authToken';
      }

      // Add file if present
      if (file != null) {
        request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException(503, 'Sin conexión al servidor');
    }
  }

  // ── Helpers internos ──────────────────────────────────────
  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final full = '$baseUrl$path';
    final uri = Uri.parse(full);
    return queryParams != null
        ? uri.replace(queryParameters: {
            ...uri.queryParameters,
            ...queryParams,
          })
        : uri;
  }

  dynamic _handleResponse(http.Response response) {
    debugPrint('← ${response.statusCode} ${response.request?.url}');
    final body = utf8.decode(response.bodyBytes);
    late Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(response.statusCode,
          'Respuesta no válida del servidor: ${body.substring(0, body.length.clamp(0, 200))}');
    }

    if (json['success'] == true) {
      return json['data'];
    } else {
      throw ApiException(
        response.statusCode,
        json['error'] as String? ?? 'Error desconocido',
      );
    }
  }
}

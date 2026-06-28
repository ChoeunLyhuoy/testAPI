// lib/services/api_service.dart
// Routes synced 1-to-1 with pos-system-api controllers

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  // ── Config ────────────────────────────────────────────────────────────────
  static const String _host   = '192.168.1.159';
  static const String baseUrl = 'http://$_host/api/v1';
  static const String imgBase = 'http://192.168.1.159';
  static const Duration _timeout = Duration(seconds: 20);

  // ── Auth token ────────────────────────────────────────────────────────────
  static String? _accessToken;
  static String? _refreshToken;
  static bool get isLoggedIn => _accessToken != null;

  static void saveTokens(String access, String refresh) {
    _accessToken  = access;
    _refreshToken = refresh;
  }

  static void clearTokens() {
    _accessToken  = null;
    _refreshToken = null;
  }

  static Map<String, String> _headers({bool auth = true}) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (auth && _accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  // ── Safe JSON decode ──────────────────────────────────────────────────────
  static Map<String, dynamic> _safeDecode(http.Response res) {
    final bodyBytes = res.bodyBytes;
    if (bodyBytes.isEmpty) {
      return {'error': 'Empty response (status ${res.statusCode})', 'status': res.statusCode};
    }
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map<String, dynamic>) {
        decoded.putIfAbsent('status', () => res.statusCode);
        return decoded;
      }
      if (decoded is List) return {'data': decoded, 'status': res.statusCode};
      return {'data': decoded, 'status': res.statusCode};
    } catch (e) {
      debugPrint('[API] Non-JSON response (status ${res.statusCode}): $e');
      return {'error': 'Invalid server response (status ${res.statusCode})', 'status': res.statusCode};
    }
  }

  // ── Core HTTP ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> _req(
      String method,
      String path, {
        Map<String, dynamic>? body,
        bool auth = true,
      }) async {
    try {
      final uri     = Uri.parse('$baseUrl$path');
      final headers = _headers(auth: auth);
      http.Response res;
      switch (method) {
        case 'POST':
          res = await http
              .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(_timeout);
          break;
        case 'PUT':
          res = await http
              .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(_timeout);
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: headers).timeout(_timeout);
          break;
        default:
          res = await http.get(uri, headers: headers).timeout(_timeout);
      }
      debugPrint('[API] $method ${uri.path} → ${res.statusCode}');
      if (res.statusCode == 401) { clearTokens(); return {'error': 'Unauthorized', 'status': 401}; }
      return _safeDecode(res);
    } on SocketException catch (e) {
      debugPrint('[API Error] $method $path — $e');
      return {'error': 'Cannot connect to server: ${e.message}'};
    } on HttpException catch (e) {
      debugPrint('[API Error] $method $path — $e');
      return {'error': 'Network error: ${e.message}'};
    } on FormatException catch (e) {
      debugPrint('[API Error] $method $path — $e');
      return {'error': 'Invalid server response'};
    } catch (e) {
      debugPrint('[API Error] $method $path — $e');
      return {'error': e.toString()};
    }
  }

  // ── Multipart ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> _multipart(
      String method,
      String path,
      Map<String, String> fields, {
        String? fileField,
        File?   file,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final req = http.MultipartRequest(method, uri);
      if (_accessToken != null) req.headers['Authorization'] = 'Bearer $_accessToken';
      req.headers['Accept'] = 'application/json';
      req.fields.addAll(fields);
      if (file != null && fileField != null) {
        if (!await file.exists()) return {'error': 'File does not exist: ${file.path}'};
        req.files.add(await http.MultipartFile.fromPath(fileField, file.path));
      }
      final stream = await req.send().timeout(_timeout);
      final res    = await http.Response.fromStream(stream);
      debugPrint('[API] $method ${uri.path} → ${res.statusCode}');
      if (res.statusCode == 401) { clearTokens(); return {'error': 'Unauthorized', 'status': 401}; }
      return _safeDecode(res);
    } on SocketException catch (e) {
      return {'error': 'Cannot connect to server: ${e.message}'};
    } on HttpException catch (e) {
      return {'error': 'Network error: ${e.message}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static List<dynamic> extractList(Map<String, dynamic>? res) {
    if (res == null) return [];
    final data = res['data'];
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      if (data['content'] != null && data['content'] is List) return data['content'] as List;
      if (data['data']    != null && data['data']    is List) return data['data']    as List;
    }
    return [];
  }

  static Map<String, dynamic>? extractData(Map<String, dynamic>? res) {
    final d = res?['data'];
    return d is Map<String, dynamic> ? d : null;
  }

  static String imageUrl(dynamic raw) {
    if (raw == null) return '';
    final url = raw.toString().trim();
    if (url.isEmpty || url == 'null' || url == 'undefined') return '';
    if (url.startsWith('http')) {
      return url.replaceFirstMapped(
        RegExp(r'^https?://(?:localhost|127\.0\.0\.1)(?::\d+)?'),
            (_) => imgBase,
      );
    }
    if (url.startsWith('/')) return '$imgBase$url';
    return '$imgBase/$url';
  }

  static bool isSuccess(Map<String, dynamic>? res) =>
      res != null &&
          res['error'] == null &&
          (res['status'] == 200 || res['status'] == 201 ||
              res['data'] != null  || res['message'] != null);

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final res = await _req('POST', '/auths/login',
        body: {'email': email, 'password': password}, auth: false);
    if (res != null && res['data'] is Map) {
      final d = res['data'] as Map<String, dynamic>;
      saveTokens(d['accessToken']?.toString() ?? '', d['refreshToken']?.toString() ?? '');
    }
    return res;
  }

  static void logout() => clearTokens();

  // ── Products ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getProducts({
    String? query, int page = 0, int size = 18, int? categoryId,
  }) {
    var p = '/products?page=$page&size=$size';
    if (query?.isNotEmpty == true) p += '&query=$query';
    if (categoryId != null) p += '&categoryId=$categoryId';
    return _req('GET', p);
  }

  static Future<Map<String, dynamic>?> getProductById(int id) =>
      _req('GET', '/products/$id');

  static Future<Map<String, dynamic>?> createProduct(
      Map<String, String> fields, {File? image}) =>
      _multipart('POST', '/products', fields, fileField: 'image', file: image);

  static Future<Map<String, dynamic>?> updateProduct(
      String id, Map<String, String> fields, {File? image}) =>
      _multipart('PUT', '/products/$id', fields, fileField: 'image', file: image);

  static Future<Map<String, dynamic>?> deleteProduct(String id) =>
      _req('DELETE', '/products/$id');

  static Future<Map<String, dynamic>?> createOption(
      Map<String, String> fields, {File? image}) =>
      _multipart('POST', '/products/options', fields, fileField: 'image', file: image);

  static Future<Map<String, dynamic>?> updateOption(
      String id, Map<String, String> fields, {File? image}) =>
      _multipart('PUT', '/products/options/$id', fields, fileField: 'image', file: image);

  static Future<Map<String, dynamic>?> deleteOption(String id) =>
      _req('DELETE', '/products/options/$id');

  /// GET /api/v1/products/options/code/{productCode}
  static Future<Map<String, dynamic>?> getOptionByCode(String productCode) =>
      _req('GET', '/products/options/code/$productCode');

  // ── Categories ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getCategories({String? query}) {
    var p = '/categories';
    if (query?.isNotEmpty == true) p += '?query=$query';
    return _req('GET', p);
  }

  static Future<Map<String, dynamic>?> createCategory(
      Map<String, String> fields, {File? image}) =>
      _multipart('POST', '/categories', fields, fileField: 'image', file: image);

  static Future<Map<String, dynamic>?> updateCategory(
      String id, Map<String, String> fields, {File? image}) =>
      _multipart('PUT', '/categories/$id', fields, fileField: 'image', file: image);

  static Future<Map<String, dynamic>?> deleteCategory(String id) =>
      _req('DELETE', '/categories/$id');

  // ── Suppliers ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getSuppliers({String? query}) {
    var p = '/suppliers';
    if (query?.isNotEmpty == true) p += '?query=$query';
    return _req('GET', p);
  }

  static Future<Map<String, dynamic>?> createSupplier(
      Map<String, String> fields, {File? image}) =>
      _multipart('POST', '/suppliers', fields, fileField: 'image', file: image);

  static Future<Map<String, dynamic>?> updateSupplier(
      String id, Map<String, String> fields, {File? image}) =>
      _multipart('PUT', '/suppliers/$id', fields, fileField: 'image', file: image);

  static Future<Map<String, dynamic>?> deleteSupplier(String id) =>
      _req('DELETE', '/suppliers/$id');

  // ── Customers ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getCustomers({
    String? query, int page = 0, int size = 50,
  }) {
    var p = '/customers?page=$page&size=$size';
    if (query?.isNotEmpty == true) p += '&query=$query';
    return _req('GET', p);
  }

  static Future<Map<String, dynamic>?> createCustomer(Map<String, dynamic> body) =>
      _req('POST', '/customers', body: body);

  static Future<Map<String, dynamic>?> updateCustomer(
      String id, Map<String, dynamic> body) =>
      _req('PUT', '/customers/$id', body: body);

  static Future<Map<String, dynamic>?> deleteCustomer(String id) =>
      _req('DELETE', '/customers/$id');

  // ── Payments ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getPayments() => _req('GET', '/payments');

  static Future<Map<String, dynamic>?> createPayment(
      Map<String, String> fields, {File? image}) =>
      _multipart('POST', '/payments', fields, fileField: 'image', file: image);

  static Future<Map<String, dynamic>?> updatePayment(
      String id, Map<String, String> fields, {File? image}) =>
      _multipart('PUT', '/payments/$id', fields, fileField: 'image', file: image);

  static Future<Map<String, dynamic>?> deletePayment(String id) =>
      _req('DELETE', '/payments/$id');

  // ── Cart ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getCart() => _req('GET', '/carts');

  static Future<Map<String, dynamic>?> addToCart(
      List<Map<String, dynamic>> items) =>
      _req('POST', '/carts', body: {'items': items});

  static Future<Map<String, dynamic>?> clearCart() => _req('DELETE', '/carts');

  // ── Orders ────────────────────────────────────────────────────────────────
  // FIX: old getOrders had no date-range support and used the wrong param name
  // ('query' instead of 'search'). Updated to accept optional [from]/[to]
  // DateTime params and build fromDate/toDate query strings that the API expects.
  // Added getOrderById for the detail screen (was getOrder(String id) before —
  // renamed + typed as int to match InvoiceDetailScreen's orderId field).
  static Future<Map<String, dynamic>?> getOrders({
    String?   query,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 100,
  }) {
    final params = <String>['page=$page', 'size=$size'];
    if (query?.isNotEmpty == true) params.add('search=$query');
    if (from != null)
      params.add('fromDate=${from.year}-${_pad(from.month)}-${_pad(from.day)}');
    if (to != null)
      params.add('toDate=${to.year}-${_pad(to.month)}-${_pad(to.day)}');
    return _req('GET', '/orders?${params.join('&')}');
  }

  /// GET /api/v1/orders/{id}  — returns single order as `data: { … }`
  static Future<Map<String, dynamic>?> getOrderById(int id) =>
      _req('GET', '/orders/$id');

  /// POST /api/v1/orders
  static Future<Map<String, dynamic>?> createOrder({
    required int paymentId,
    double? discount,
  }) =>
      _req('POST', '/orders', body: {
        'paymentId': paymentId,
        if (discount != null && discount > 0) 'discount': discount,
      });

  // ── Purchases ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getPurchases({
    String? query, int page = 0, int size = 50,
  }) {
    var p = '/purchases?page=$page&size=$size';
    if (query?.isNotEmpty == true) p += '&query=$query';
    return _req('GET', p);
  }

  static Future<Map<String, dynamic>?> getPurchase(String id) =>
      _req('GET', '/purchases/$id');

  static Future<Map<String, dynamic>?> createPurchase(Map<String, dynamic> body) =>
      _req('POST', '/purchases', body: body);

  // ── Promotions ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getPromotions({
    String? query, int size = 50,
  }) {
    var p = '/promotions?size=$size';
    if (query?.isNotEmpty == true) p += '&query=$query';
    return _req('GET', p);
  }

  static Future<Map<String, dynamic>?> getPromotion(String id) =>
      _req('GET', '/promotions/$id');

  static Future<Map<String, dynamic>?> createPromotion(
      Map<String, dynamic> body) =>
      _req('POST', '/promotions', body: body);

  static Future<Map<String, dynamic>?> updatePromotion(
      String id, Map<String, dynamic> body) =>
      _req('PUT', '/promotions/$id', body: body);

  static Future<Map<String, dynamic>?> deletePromotion(String id) =>
      _req('DELETE', '/promotions/$id');

  static Future<Map<String, dynamic>?> addProductsToPromotion(
      String promotionId,
      List<Map<String, dynamic>> products,
      ) =>
      _req('POST', '/promotions/$promotionId/products');

  // ── Reports ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getDashboard() =>
      _req('GET', '/reports/dashboard');

  static Future<Map<String, dynamic>?> getStockReport({
    String? categoryId, bool lowStockOnly = false,
  }) {
    var p = '/reports/stock?lowStockOnly=$lowStockOnly';
    if (categoryId?.isNotEmpty == true) p += '&categoryId=$categoryId';
    return _req('GET', p);
  }

  static Future<Map<String, dynamic>?> getSalesReport({
    String? from, String? to, String? categoryId,
  }) {
    var p = '/reports/sales';
    final params = <String>[];
    if (from?.isNotEmpty       == true) params.add('from=$from');
    if (to?.isNotEmpty         == true) params.add('to=$to');
    if (categoryId?.isNotEmpty == true) params.add('categoryId=$categoryId');
    if (params.isNotEmpty) p += '?${params.join('&')}';
    return _req('GET', p);
  }

  static Future<Map<String, dynamic>?> getSalesDaily({String? from, String? to}) {
    var p = '/reports/sales/daily';
    final params = <String>[];
    if (from?.isNotEmpty == true) params.add('from=$from');
    if (to?.isNotEmpty   == true) params.add('to=$to');
    if (params.isNotEmpty) p += '?${params.join('&')}';
    return _req('GET', p);
  }

  static Future<Map<String, dynamic>?> getMonthlySales({int? year}) {
    final y = year ?? DateTime.now().year;
    return _req('GET', '/reports/sales/monthly?year=$y');
  }

  static Future<Map<String, dynamic>?> getSalesByCategory({String? from, String? to}) {
    var p = '/reports/sales/category';
    final params = <String>[];
    if (from?.isNotEmpty == true) params.add('from=$from');
    if (to?.isNotEmpty   == true) params.add('to=$to');
    if (params.isNotEmpty) p += '?${params.join('&')}';
    return _req('GET', p);
  }

  static Future<Map<String, dynamic>?> getPurchasesReport({String? from, String? to}) {
    var p = '/reports/purchases';
    final params = <String>[];
    if (from?.isNotEmpty == true) params.add('from=$from');
    if (to?.isNotEmpty   == true) params.add('to=$to');
    if (params.isNotEmpty) p += '?${params.join('&')}';
    return _req('GET', p);
  }

  // ── Private utils ─────────────────────────────────────────────────────────
  static String _pad(int v) => v.toString().padLeft(2, '0');
}
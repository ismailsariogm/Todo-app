/// DbClient — Flutter tarafında yerel DB sunucusuna HTTP erişimi.
///
/// Kullanım:
///   final tasks = await DbClient.getList('tasks');
///   await DbClient.putList('tasks', tasks);
///   await DbClient.upsertItem('tasks', {'id': 'xyz', 'title': 'Test'});
///   await DbClient.deleteItem('tasks', 'xyz');
///
///   final friends = await DbClient.getMap('friends', 'uid123');
///   await DbClient.putMap('friends', 'uid123', [...]);

import 'dart:convert';

import 'package:http/http.dart' as http;

class DbClient {
  DbClient._();

  static const _base = 'http://localhost:3001';
  static const _timeout = Duration(seconds: 3);

  // ── Bağlantı kontrolü ──────────────────────────────────────────────────────

  static Future<bool> isAvailable() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/health'))
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Liste koleksiyonları (users, tasks, projects, members, user_registry) ──

  /// Koleksiyonun tamamını liste olarak getirir.
  static Future<List<Map<String, dynamic>>> getList(String collection) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/db/$collection'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Koleksiyonun tamamını liste olarak yazar (tam üzerine yazar).
  static Future<void> putList(
      String collection, List<Map<String, dynamic>> items) async {
    try {
      await http
          .put(
            Uri.parse('$_base/db/$collection'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(items),
          )
          .timeout(_timeout);
    } catch (_) {}
  }

  /// Listeye tek öğe ekler ya da id/email eşleşmesine göre günceller.
  static Future<void> upsertItem(
      String collection, Map<String, dynamic> item) async {
    try {
      await http
          .post(
            Uri.parse('$_base/db/$collection'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(item),
          )
          .timeout(_timeout);
    } catch (_) {}
  }

  /// Listeden tek öğeyi siler.
  static Future<void> deleteItem(String collection, String id) async {
    try {
      await http
          .delete(Uri.parse('$_base/db/$collection/${Uri.encodeComponent(id)}'))
          .timeout(_timeout);
    } catch (_) {}
  }

  // ── Sözlük (map) koleksiyonları (friends, conversations, messages) ──────────

  /// Map koleksiyonundan belirli anahtarı getirir.
  static Future<List<Map<String, dynamic>>> getMap(
      String collection, String key) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/db/$collection/${Uri.encodeComponent(key)}'))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  /// Map koleksiyonunda belirli anahtara liste yazar.
  static Future<void> putMap(
      String collection, String key, List<Map<String, dynamic>> items) async {
    try {
      await http
          .put(
            Uri.parse('$_base/db/$collection/${Uri.encodeComponent(key)}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(items),
          )
          .timeout(_timeout);
    } catch (_) {}
  }

  // ── Koleksiyon birleştirme (yükleme sırasında disk + SharedPreferences) ─────

  /// İki liste kaynağını id/email bazında birleştirir.
  /// [server] önceliklidir; [local] sadece eksik öğeleri ekler.
  static List<Map<String, dynamic>> merge(
    List<Map<String, dynamic>> server,
    List<Map<String, dynamic>> local, {
    String idField = 'id',
  }) {
    final combined = <String, Map<String, dynamic>>{};
    for (final item in server) {
      final k = item[idField]?.toString() ?? '';
      if (k.isNotEmpty) combined[k] = item;
    }
    for (final item in local) {
      final k = item[idField]?.toString() ?? '';
      if (k.isNotEmpty) combined.putIfAbsent(k, () => item);
    }
    return combined.values.toList();
  }
}

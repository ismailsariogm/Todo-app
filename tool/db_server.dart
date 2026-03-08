/// Todo Uygulaması — Yerel Veritabanı Sunucusu (port 3001)
///
/// Tüm uygulama verilerini tek bir app_db.json dosyasında saklar:
///   users        → kayıtlı kullanıcılar
///   tasks        → görevler
///   projects     → gruplar / projeler
///   members      → grup üyeleri
///   user_registry → sohbet kullanıcı dizini
///   friends      → arkadaşlık listesi (uid → [user])
///   conversations → sohbet listesi (uid → [conv])
///   messages     → mesajlar (convId → [msg])
///
/// Flutter web uygulaması bu sunucuya HTTP istekleri göndererek veri okur/yazar.

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

// ─── Veritabanı dosya yolu ─────────────────────────────────────────────────────
final _dbFile = File(
  '${Platform.script.toFilePath().split('tool')[0]}app_db.json',
);

// Eski users_db.json dosyası (geriye dönük uyumluluk için)
final _oldUsersFile = File(
  '${Platform.script.toFilePath().split('tool')[0]}users_db.json',
);

// ─── DB okuma / yazma ─────────────────────────────────────────────────────────

Map<String, dynamic> _readDb() {
  final defaults = <String, dynamic>{
    'users': <dynamic>[],
    'tasks': <dynamic>[],
    'projects': <dynamic>[],
    'members': <dynamic>[],
    'user_registry': <dynamic>[],
    'friends': <String, dynamic>{},
    'conversations': <String, dynamic>{},
    'messages': <String, dynamic>{},
    'task_views': <dynamic>[],
    'subtasks': <dynamic>[],
  };

  try {
    if (!_dbFile.existsSync()) {
      // Eski users_db.json varsa, kullanıcıları taşı
      if (_oldUsersFile.existsSync()) {
        final oldContent = _oldUsersFile.readAsStringSync();
        if (oldContent.trim().isNotEmpty) {
          final oldUsers = jsonDecode(oldContent) as List;
          defaults['users'] = oldUsers;
          _dbFile.writeAsStringSync(jsonEncode(defaults));
          print('Eski users_db.json → app_db.json\'a taşındı.');
          return defaults;
        }
      }
      _dbFile.writeAsStringSync(jsonEncode(defaults));
      return defaults;
    }
    final content = _dbFile.readAsStringSync();
    if (content.trim().isEmpty) return defaults;
    final loaded = jsonDecode(content) as Map<String, dynamic>;
    // Eksik koleksiyonları ekle
    for (final key in defaults.keys) {
      loaded.putIfAbsent(key, () => defaults[key]);
    }
    return loaded;
  } catch (e) {
    print('DB okuma hatası: $e');
    return defaults;
  }
}

void _writeDb(Map<String, dynamic> db) {
  _dbFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(db));
}

// ─── CORS ─────────────────────────────────────────────────────────────────────

Response _cors(Response r) => r.change(headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });

Middleware get _corsMiddleware => createMiddleware(
      responseHandler: _cors,
      requestHandler: (req) {
        if (req.method == 'OPTIONS') {
          return Response.ok('', headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
          });
        }
        return null;
      },
    );

Response _json(dynamic data, {int status = 200}) => Response(
      status,
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );

// ─── Main ─────────────────────────────────────────────────────────────────────

void main() async {
  final router = Router();

  // ── Sağlık kontrolü ────────────────────────────────────────────────────────
  router.get('/health', (_) => _json({
        'status': 'ok',
        'dbFile': _dbFile.path,
        'collections': _readDb().keys.toList(),
      }));

  // ── Tüm koleksiyon listesini getir ──────────────────────────────────────────
  // GET /db/users          → kullanıcı listesi
  // GET /db/tasks          → görev listesi
  // GET /db/projects       → proje listesi
  // GET /db/members        → üye listesi
  // GET /db/user_registry  → kullanıcı dizini
  router.get('/db/<collection>', (Request req, String collection) {
    final db = _readDb();
    if (!db.containsKey(collection)) {
      return _json({'error': 'Koleksiyon bulunamadı: $collection'}, status: 404);
    }
    return _json(db[collection]);
  });

  // ── Koleksiyonu komple değiştir ─────────────────────────────────────────────
  // PUT /db/tasks   body: [...]
  router.put('/db/<collection>', (Request req, String collection) async {
    final db  = _readDb();
    final body = await req.readAsString();
    try {
      db[collection] = jsonDecode(body);
      _writeDb(db);
      return _json({'ok': true});
    } catch (e) {
      return _json({'error': e.toString()}, status: 400);
    }
  });

  // ── Koleksiyona tek öğe ekle / güncelle ─────────────────────────────────────
  // POST /db/tasks           body: {id, ...}  → ekle veya güncelle (id'ye göre)
  router.post('/db/<collection>', (Request req, String collection) async {
    final db   = _readDb();
    final body = await req.readAsString();
    try {
      final item = jsonDecode(body) as Map<String, dynamic>;
      final col  = db[collection];

      if (col is List) {
        final id = item['id'] as String? ?? item['email'] as String?;
        if (id != null) {
          final idx = (col as List).indexWhere(
            (e) => (e as Map)['id'] == id || (e as Map)['email'] == id,
          );
          if (idx >= 0) {
            col[idx] = item;
          } else {
            col.add(item);
          }
        } else {
          col.add(item);
        }
      } else {
        return _json({'error': 'Bu koleksiyon liste değil'}, status: 400);
      }

      _writeDb(db);
      return _json({'ok': true});
    } catch (e) {
      return _json({'error': e.toString()}, status: 400);
    }
  });

  // ── Sözlük (map) koleksiyonuna anahtar bazlı okuma ─────────────────────────
  // GET /db/friends/uid123
  // GET /db/conversations/uid123
  // GET /db/messages/convId
  router.get('/db/<collection>/<key>', (Request req, String collection, String key) {
    final db  = _readDb();
    final col = db[collection];
    if (col is Map) {
      return _json(col[key] ?? []);
    }
    // Liste koleksiyonunda id araması
    if (col is List) {
      final decodedKey = Uri.decodeComponent(key);
      final found = (col as List).where(
        (e) => (e as Map)['id'] == decodedKey || (e as Map)['email'] == decodedKey,
      ).toList();
      if (found.isEmpty) return _json({'error': 'Bulunamadı'}, status: 404);
      return _json(found.first);
    }
    return _json({'error': 'Koleksiyon bulunamadı'}, status: 404);
  });

  // ── Sözlük (map) koleksiyonuna anahtar bazlı yazma ─────────────────────────
  // PUT /db/friends/uid123     body: [...]
  // PUT /db/messages/convId    body: [...]
  router.put('/db/<collection>/<key>', (Request req, String collection, String key) async {
    final db   = _readDb();
    final body = await req.readAsString();
    try {
      final value = jsonDecode(body);
      final col = db[collection];
      if (col is Map) {
        col[key] = value;
        _writeDb(db);
        return _json({'ok': true});
      }
      return _json({'error': 'Bu koleksiyon Map değil'}, status: 400);
    } catch (e) {
      return _json({'error': e.toString()}, status: 400);
    }
  });

  // ── Tek öğe silme ───────────────────────────────────────────────────────────
  // DELETE /db/tasks/taskId
  router.delete('/db/<collection>/<id>', (Request req, String collection, String id) {
    final db  = _readDb();
    final col = db[collection];
    if (col is List) {
      final decodedId = Uri.decodeComponent(id);
      (col as List).removeWhere(
        (e) => (e as Map)['id'] == decodedId || (e as Map)['email'] == decodedId,
      );
      _writeDb(db);
      return _json({'ok': true});
    }
    if (col is Map) {
      (col as Map).remove(Uri.decodeComponent(id));
      _writeDb(db);
      return _json({'ok': true});
    }
    return _json({'error': 'Koleksiyon bulunamadı'}, status: 404);
  });

  // ── Şifre güncelleme (geriye dönük uyumluluk) ──────────────────────────────
  router.put('/users/<email>/password', (Request req, String email) async {
    final body = await req.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final newPw = data['password'] as String? ?? '';
    if (newPw.length < 6) return _json({'error': 'Çok kısa'}, status: 400);

    final db    = _readDb();
    final users = db['users'] as List;
    final key   = Uri.decodeComponent(email).toLowerCase().trim();
    final idx   = users.indexWhere((u) => (u as Map)['email'] == key);
    if (idx < 0) return _json({'error': 'Kullanıcı bulunamadı'}, status: 404);
    (users[idx] as Map)['password'] = newPw;
    _writeDb(db);
    return _json({'ok': true});
  });

  // ── Tüm veritabanını getir (yedekleme amaçlı) ──────────────────────────────
  router.get('/db', (_) => _json(_readDb()));

  final handler = Pipeline()
      .addMiddleware(_corsMiddleware)
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await io.serve(handler, 'localhost', 3001);
  print('✅ DB Sunucusu: http://${server.address.host}:${server.port}');
  print('📁 Veritabanı : ${_dbFile.path}');
  print('📋 Koleksiyonlar: ${_readDb().keys.join(', ')}');
}

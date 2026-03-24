import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/task_file_entity.dart';
import '../utils/folder_name_normalize.dart';
import 'db_client.dart';

const _kKey = 'task_files_v1';
const _uuid = Uuid();

class TaskFileStorage {
  TaskFileStorage._();
  static final TaskFileStorage instance = TaskFileStorage._();

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  Future<List<TaskFileEntity>> _loadAll() async {
    final serverItems = await DbClient.getList('task_files');
    final prefs = await _prefs;
    List<Map<String, dynamic>> local = [];
    final raw = prefs.getString(_kKey);
    if (raw != null) {
      try {
        local = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    final merged = DbClient.merge(serverItems, local);
    if (merged.isNotEmpty) {
      await prefs.setString(_kKey, jsonEncode(merged));
      await DbClient.putList('task_files', merged);
    }
    return merged.map((m) => TaskFileEntity.fromJson(m)).toList();
  }

  Future<void> _saveAll(List<TaskFileEntity> files) async {
    final items = files.map((f) => f.toJson()).toList();
    final prefs = await _prefs;
    await prefs.setString(_kKey, jsonEncode(items));
    await DbClient.putList('task_files', items);
  }

  /// Kullanıcının tüm dosyalarını döndürür (isim sırasına göre).
  Future<List<TaskFileEntity>> getFiles(String ownerId) async {
    final all = await _loadAll();
    final userFiles = all.where((f) => f.ownerId == ownerId).toList();
    userFiles.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order != 0 ? order : a.name.compareTo(b.name);
    });
    return userFiles;
  }

  /// Yeni dosya oluşturur.
  Future<TaskFileEntity> createFile({
    required String ownerId,
    required String name,
    String? colorHex,
  }) async {
    if (await hasFolderWithName(ownerId, name)) {
      throw StateError('duplicate_folder');
    }
    final all = await _loadAll();
    final existing = all.where((f) => f.ownerId == ownerId).length;
    final file = TaskFileEntity(
      id: _uuid.v4(),
      ownerId: ownerId,
      name: name.trim(),
      colorHex: colorHex ?? '#6366F1',
      sortOrder: existing,
      createdAt: DateTime.now(),
    );
    all.add(file);
    await _saveAll(all);
    return file;
  }

  /// Dosyayı günceller.
  Future<void> updateFile(TaskFileEntity file) async {
    final all = await _loadAll();
    final idx = all.indexWhere((f) => f.id == file.id);
    if (idx >= 0) {
      all[idx] = file;
      await _saveAll(all);
    }
  }

  /// Dosyayı siler.
  Future<void> deleteFile(String id) async {
    final all = await _loadAll();
    all.removeWhere((f) => f.id == id);
    await _saveAll(all);
  }

  /// Aynı isimde klasör var mı (normalize edilmiş isim: ı/i, u/ü, o/ö, noktalama).
  Future<bool> hasFolderWithName(String ownerId, String name) async {
    final files = await getFiles(ownerId);
    final key = normalizeFolderNameForDuplicate(name);
    if (key.isEmpty) return false;
    return files.any(
        (f) => normalizeFolderNameForDuplicate(f.name) == key);
  }

  /// Dosya adına göre bulur, yoksa null.
  Future<TaskFileEntity?> getFileById(String id) async {
    final all = await _loadAll();
    try {
      return all.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }
}

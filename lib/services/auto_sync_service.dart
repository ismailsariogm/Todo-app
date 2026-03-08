/// AutoSyncService — Her 1 saniyede bir tüm uygulama verilerini diske yazar.
///
/// Ayrıca uygulama arka plana alındığında veya kapatıldığında
/// (pause / detach lifecycle) hemen tam bir senkronizasyon yapar.
/// Uygulama tekrar öne geldiğinde (resumed) diskten taze veri yükler.
///
/// Kullanım (main.dart):
///   AutoSyncService.instance.start();
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/repositories/web_task_repository.dart';
import '../data/repositories/project_repository.dart';
import 'db_client.dart';

class AutoSyncService with WidgetsBindingObserver {
  AutoSyncService._();
  static final AutoSyncService instance = AutoSyncService._();

  Timer? _timer;
  bool _syncing = false;

  // ─── Başlat ───────────────────────────────────────────────────────────────

  void start() {
    WidgetsBinding.instance.addObserver(this);

    // 1 saniyede bir senkronize et (yazma)
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _sync());
    // 2 saniyede bir sunucudan veri yenile (anlık görünüm)
    Timer.periodic(const Duration(seconds: 2), (_) => _reload());

    debugPrint('[AutoSync] Başlatıldı — her 1 saniyede yazma, 2 saniyede okuma.');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('[AutoSync] Durduruldu.');
  }

  // ─── Uygulama yaşam döngüsü ───────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Uygulama kapatılıyor veya arka plana alınıyor → hemen kaydet
        debugPrint('[AutoSync] Uygulama kapanıyor/pause — acil senkronizasyon...');
        _sync(force: true);
      case AppLifecycleState.resumed:
        // Uygulama tekrar öne geldi → veriyi yenile
        debugPrint('[AutoSync] Uygulama resumed — veri yenileniyor...');
        _reload();
      case AppLifecycleState.inactive:
        break;
    }
  }

  // ─── Senkronizasyon ───────────────────────────────────────────────────────

  /// Bellekteki tüm veriyi DB sunucusuna yazar.
  Future<void> _sync({bool force = false}) async {
    if (_syncing && !force) return; // önceki sync bitmemişse atla
    _syncing = true;
    try {
      final available = await DbClient.isAvailable();
      if (!available) return; // sunucu kapalıysa atla

      // Görevler
      final tasks = WebTaskRepository.instance.currentTasksJson;
      if (tasks.isNotEmpty) {
        await DbClient.putList('tasks', tasks);
      }

      // Projeler
      final projects = WebProjectRepository.instance.currentProjectsJson;
      if (projects.isNotEmpty) {
        await DbClient.putList('projects', projects);
      }

      // Grup üyeleri
      final members = WebProjectRepository.instance.currentMembersJson;
      if (members.isNotEmpty) {
        await DbClient.putList('members', members);
      }
    } catch (e) {
      debugPrint('[AutoSync] Senkronizasyon hatası: $e');
    } finally {
      _syncing = false;
    }
  }

  /// Diskten taze veri yükler (uygulama resume sonrası).
  Future<void> _reload() async {
    try {
      await WebTaskRepository.instance.init();
      await WebProjectRepository.instance.init(forceReload: true);
    } catch (e) {
      debugPrint('[AutoSync] Yeniden yükleme hatası: $e');
    }
  }

  /// Dışarıdan manuel senkronizasyon tetiklemek için.
  Future<void> flush() => _sync(force: true);
}

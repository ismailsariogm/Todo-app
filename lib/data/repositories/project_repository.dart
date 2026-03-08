import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/filter_entity.dart';
import '../../domain/entities/project_entity.dart';
import '../../services/db_client.dart';

const _uuid = Uuid();
const _projectsKey = 'web_projects_v1';
const _membersKey = 'web_members_v1';
const _filtersKey = 'web_saved_filters_v1';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return WebProjectRepository.instance;
});

abstract class ProjectRepository {
  Stream<List<ProjectEntity>> watchProjects(String ownerId);
  /// Returns ALL shared groups where user is owner OR member.
  Stream<List<ProjectEntity>> watchSharedGroupsForUser(String userId);
  Future<ProjectEntity> createProject({
    required String ownerId,
    required String name,
    String? description,
    bool isShared,
    String colorHex,
    String? photoBase64,
    bool isCommunityGroup = false,
    String? parentCommunityId,
  });
  Future<void> updateProject(String id, {String? name, String? colorHex, String? photoBase64, bool removePhoto = false});
  Future<void> deleteProject(String id);
  Stream<List<GroupMemberEntity>> watchGroupMembers(String groupId);
  Future<void> addMember({
    required String groupId,
    required String userId,
    required String email,
    required String displayName,
    String role,
  });
  Future<void> removeMember(String groupId, String userId);
  Stream<List<SavedFilterEntity>> watchSavedFilters(String userId);
  Future<void> upsertSavedFilter({
    String? id,
    required String userId,
    required String name,
    required String filterJson,
  });
  Future<void> deleteSavedFilter(String id);
  /// Topluluk grubunun alt gruplarını döndürür
  Stream<List<ProjectEntity>> watchSubGroups(String communityId);
}

class WebProjectRepository extends ProjectRepository {
  WebProjectRepository._();
  static final WebProjectRepository instance = WebProjectRepository._();

  List<ProjectEntity> _projects = [];
  List<GroupMemberEntity> _members = [];
  List<SavedFilterEntity> _savedFilters = [];

  final _projectsCtrl = StreamController<List<ProjectEntity>>.broadcast();
  final _membersCtrl = StreamController<List<GroupMemberEntity>>.broadcast();
  final _filtersCtrl = StreamController<List<SavedFilterEntity>>.broadcast();

  bool _initialized = false;

  Future<void> init({bool forceReload = false}) async {
    if (_initialized && !forceReload) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();

    // ── Projeler ──────────────────────────────────────────────────────────────
    final serverProjects = await DbClient.getList('projects');
    List<Map<String, dynamic>> localProjects = [];
    final pRaw = prefs.getString(_projectsKey);
    if (pRaw != null) {
      try { localProjects = (jsonDecode(pRaw) as List).cast<Map<String, dynamic>>(); } catch (_) {}
    }
    final mergedProjects = DbClient.merge(serverProjects, localProjects);
    _projects = mergedProjects.map(ProjectEntity.fromJson).toList();
    if (mergedProjects.isNotEmpty) {
      await prefs.setString(_projectsKey, jsonEncode(mergedProjects));
      await DbClient.putList('projects', mergedProjects);
    }

    // ── Üyeler ───────────────────────────────────────────────────────────────
    final serverMembers = await DbClient.getList('members');
    List<Map<String, dynamic>> localMembers = [];
    final mRaw = prefs.getString(_membersKey);
    if (mRaw != null) {
      try { localMembers = (jsonDecode(mRaw) as List).cast<Map<String, dynamic>>(); } catch (_) {}
    }
    // members id alanı yok, groupId+userId ile birleştir
    final memberKeys = <String>{};
    final mergedMembers = <Map<String, dynamic>>[];
    for (final m in [...serverMembers, ...localMembers]) {
      final k = '${m['groupId']}_${m['userId']}';
      if (memberKeys.add(k)) mergedMembers.add(m);
    }
    _members = mergedMembers.map(GroupMemberEntity.fromJson).toList();
    if (mergedMembers.isNotEmpty) {
      await prefs.setString(_membersKey, jsonEncode(mergedMembers));
      await DbClient.putList('members', mergedMembers);
    }

    // ── Kaydedilmiş filtreler ─────────────────────────────────────────────────
    final serverFilters = await DbClient.getList('saved_filters');
    List<Map<String, dynamic>> localFilters = [];
    final fRaw = prefs.getString(_filtersKey);
    if (fRaw != null) {
      try { localFilters = (jsonDecode(fRaw) as List).cast<Map<String, dynamic>>(); } catch (_) {}
    }
    final mergedFilters = DbClient.merge(serverFilters, localFilters);
    _savedFilters = mergedFilters.map((m) => SavedFilterEntity(
      id: m['id'] as String,
      userId: m['userId'] as String,
      name: m['name'] as String,
      filter: TaskFilter.fromJsonString(m['filterJson'] as String),
      createdAt: DateTime.parse(m['createdAt'] as String),
    )).toList();

    _pushAll();
  }

  Future<void> _saveProjects() async {
    final encoded = _projects.map((p) => p.toJson()).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_projectsKey, jsonEncode(encoded));
    await DbClient.putList('projects', encoded);
    _projectsCtrl.add(List.unmodifiable(_projects));
  }

  Future<void> _saveMembers() async {
    final encoded = _members.map((m) => m.toJson()).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_membersKey, jsonEncode(encoded));
    await DbClient.putList('members', encoded);
    _membersCtrl.add(List.unmodifiable(_members));
    _projectsCtrl.add(List.unmodifiable(_projects));
  }

  Future<void> _saveFilters() async {
    final raw = _savedFilters.map((f) => {
      'id': f.id,
      'userId': f.userId,
      'name': f.name,
      'filterJson': f.filter.toJsonString(),
      'createdAt': f.createdAt.toIso8601String(),
    }).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_filtersKey, jsonEncode(raw));
    await DbClient.putList('saved_filters', raw);
    _filtersCtrl.add(List.unmodifiable(_savedFilters));
  }

  void _pushAll() {
    _projectsCtrl.add(List.unmodifiable(_projects));
    _membersCtrl.add(List.unmodifiable(_members));
    _filtersCtrl.add(List.unmodifiable(_savedFilters));
  }

  /// Mevcut veriyi JSON listesi olarak döndürür — auto-sync için.
  List<Map<String, dynamic>> get currentProjectsJson =>
      _projects.map((p) => p.toJson()).toList();

  List<Map<String, dynamic>> get currentMembersJson =>
      _members.map((m) => m.toJson()).toList();

  @override
  Stream<List<ProjectEntity>> watchProjects(String ownerId) {
    List<ProjectEntity> _compute() =>
        _projects.where((p) => p.ownerId == ownerId).toList();
    return Stream.fromIterable([_compute()]).asyncExpand(
      (_) => _projectsCtrl.stream.map((_) => _compute()),
    );
  }

  // Controller for combined project+member events keyed by userId
  final _sharedGroupsCtrl = StreamController<List<ProjectEntity>>.broadcast();

  /// Called after any project or member change to push updated shared-groups.
  void _pushSharedGroups() {
    // We don't know the userId here; each subscriber handles filtering inline.
    // Trigger by pushing to _projectsCtrl and _membersCtrl which listeners map over.
  }

  @override
  Stream<List<ProjectEntity>> watchSharedGroupsForUser(String userId) {
    List<ProjectEntity> compute() {
      final memberGroupIds = _members
          .where((m) => m.userId == userId)
          .map((m) => m.groupId)
          .toSet();
      return _projects
          .where((p) =>
              (p.ownerId == userId || memberGroupIds.contains(p.id)))
          .toList();
    }
    // Emit initial value, then on any project OR member change.
    return Stream.fromIterable([compute()]).asyncExpand((_) {
      final c = StreamController<List<ProjectEntity>>.broadcast();
      void emit() => c.add(compute());
      final sub1 = _projectsCtrl.stream.listen((_) => emit());
      final sub2 = _membersCtrl.stream.listen((_) => emit());
      c.onCancel = () async {
        await sub1.cancel();
        await sub2.cancel();
      };
      return c.stream;
    });
  }

  @override
  Future<ProjectEntity> createProject({
    required String ownerId,
    required String name,
    String? description,
    bool isShared = false,
    String colorHex = '#6366F1',
    String? photoBase64,
    bool isCommunityGroup = false,
    String? parentCommunityId,
  }) async {
    await init();
    final now = DateTime.now();
    final project = ProjectEntity(
      id: _uuid.v4(),
      ownerId: ownerId,
      name: name,
      description: description,
      isShared: isShared,
      colorHex: colorHex,
      photoBase64: photoBase64,
      createdAt: now,
      updatedAt: now,
      isCommunityGroup: isCommunityGroup,
      parentCommunityId: parentCommunityId,
    );
    _projects.add(project);
    await _saveProjects();
    return project;
  }

  @override
  Stream<List<ProjectEntity>> watchSubGroups(String communityId) {
    List<ProjectEntity> _compute() => _projects
        .where((p) => p.parentCommunityId == communityId)
        .toList();
    return Stream.fromIterable([_compute()]).asyncExpand(
      (_) => _projectsCtrl.stream.map((_) => _compute()),
    );
  }

  @override
  Future<void> updateProject(String id,
      {String? name, String? colorHex, String? photoBase64, bool removePhoto = false}) async {
    await init();
    final idx = _projects.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final old = _projects[idx];
    _projects[idx] = ProjectEntity(
      id: old.id,
      ownerId: old.ownerId,
      name: name ?? old.name,
      description: old.description,
      isShared: old.isShared,
      colorHex: colorHex ?? old.colorHex,
      photoBase64: removePhoto ? null : (photoBase64 ?? old.photoBase64),
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
      isCommunityGroup: old.isCommunityGroup,
      parentCommunityId: old.parentCommunityId,
    );
    await _saveProjects();
  }

  @override
  Future<void> deleteProject(String id) async {
    await init();
    _projects.removeWhere((p) => p.id == id);
    _members.removeWhere((m) => m.groupId == id);
    await _saveProjects();
    await _saveMembers();
  }

  @override
  Stream<List<GroupMemberEntity>> watchGroupMembers(String groupId) {
    List<GroupMemberEntity> _compute() =>
        _members.where((m) => m.groupId == groupId).toList();
    return Stream.fromIterable([_compute()]).asyncExpand(
      (_) => _membersCtrl.stream.map((_) => _compute()),
    );
  }

  @override
  Future<void> addMember({
    required String groupId,
    required String userId,
    required String email,
    required String displayName,
    String role = 'member',
  }) async {
    await init();
    _members.removeWhere(
        (m) => m.groupId == groupId && m.userId == userId);
    _members.add(GroupMemberEntity(
      groupId: groupId,
      userId: userId,
      email: email,
      displayName: displayName,
      role: role,
      joinedAt: DateTime.now(),
    ));
    await _saveMembers();
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    await init();
    _members.removeWhere(
        (m) => m.groupId == groupId && m.userId == userId);
    await _saveMembers();
  }

  @override
  Stream<List<SavedFilterEntity>> watchSavedFilters(String userId) {
    return _filtersCtrl.stream
        .map((list) => list.where((f) => f.userId == userId).toList());
  }

  @override
  Future<void> upsertSavedFilter({
    String? id,
    required String userId,
    required String name,
    required String filterJson,
  }) async {
    await init();
    final fId = id ?? _uuid.v4();
    _savedFilters.removeWhere((f) => f.id == fId);
    _savedFilters.add(SavedFilterEntity(
      id: fId,
      userId: userId,
      name: name,
      filter: TaskFilter.fromJsonString(filterJson),
      createdAt: DateTime.now(),
    ));
    await _saveFilters();
  }

  @override
  Future<void> deleteSavedFilter(String id) async {
    await init();
    _savedFilters.removeWhere((f) => f.id == id);
    await _saveFilters();
  }
}

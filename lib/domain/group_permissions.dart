/// Grup rol yetkileri
///
/// Yönetici: Görev ekleme, rol düzenleme, kıdemli/üye atma, davet, tamamlama
/// Kıdemli: Görev ekleme, üye atma, davet, tamamlama
/// Üye: Görev ekleme, tamamlama
class GroupPermissions {
  GroupPermissions._();

  static const _admin = {'yonetici', 'owner'};
  static const _senior = {'kıdemli'};
  static const _member = {'uye', 'member'};

  static bool _isAdmin(String? role) =>
      role != null && _admin.contains(role);
  static bool _isSenior(String? role) =>
      role != null && _senior.contains(role);
  static bool _isMember(String? role) =>
      role != null &&
      (_member.contains(role) ||
          (!_isAdmin(role) && !_isSenior(role)));

  /// Görev ekleme — Yönetici, Kıdemli, Üye
  static bool canAddTask(String? role) =>
      _isAdmin(role) || _isSenior(role) || _isMember(role);

  /// Görev tamamlama — Yönetici, Kıdemli, Üye
  static bool canCompleteTask(String? role) =>
      _isAdmin(role) || _isSenior(role) || _isMember(role);

  /// Rol değiştirme — sadece Yönetici
  static bool canChangeRoles(String? role) => _isAdmin(role);

  /// Hedef üyeyi gruptan atma
  /// Yönetici: kıdemli ve üyeleri atabilir
  /// Kıdemli: sadece üyeleri atabilir
  /// Üye: atamaz
  static bool canRemoveMember(String? actorRole, String? targetRole) {
    if (actorRole == null || targetRole == null) return false;
    if (actorRole == targetRole) return false; // kendini atamaz
    if (_isAdmin(actorRole)) {
      return _isSenior(targetRole) || _isMember(targetRole);
    }
    if (_isSenior(actorRole)) {
      return _isMember(targetRole);
    }
    return false;
  }

  /// Gruba davet etme — Yönetici, Kıdemli
  static bool canInvite(String? role) => _isAdmin(role) || _isSenior(role);

  /// Grup bilgisi düzenleme (ad, renk) — sadece Yönetici
  static bool canEditGroupInfo(String? role) => _isAdmin(role);

  /// Profil fotoğrafı değiştirme/düzenleme — sadece Yönetici
  static bool canEditGroupPhoto(String? role) => _isAdmin(role);

  /// Grubu silme — sadece Yönetici (owner)
  static bool canDeleteGroup(String? role) => _isAdmin(role);

  /// Rol için yetki açıklaması (UI'da göstermek için)
  static String roleDescription(String? role) {
    if (_isAdmin(role)) {
      return 'Görev ekleme, rol düzenleme, üye atma, davet, tamamlama';
    }
    if (_isSenior(role)) {
      return 'Görev ekleme, üye atma, davet, tamamlama';
    }
    if (_isMember(role)) {
      return 'Görev ekleme, tamamlama';
    }
    return 'Temel erişim';
  }
}

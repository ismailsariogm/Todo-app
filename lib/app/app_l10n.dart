import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_note/app/providers.dart';

/// Centralized localization strings for TR and EN.
/// Access via: final l = ref.watch(appL10nProvider);
class AppL10n {
  const AppL10n(this._tr);
  final bool _tr;

  // ── Common ───────────────────────────────────────────────────────────────
  String get cancel => _tr ? 'İptal' : 'Cancel';
  String get save => _tr ? 'Kaydet' : 'Save';
  String get add => _tr ? 'Ekle' : 'Add';
  String get remove => _tr ? 'Kaldır' : 'Remove';
  String get user => _tr ? 'Kullanıcı' : 'User';

  // ── Bottom tab bar ────────────────────────────────────────────────────────
  String get tabToday => _tr ? 'Bugün' : 'Today';
  String get tabOngoing => _tr ? 'Devam' : 'Ongoing';
  String get tabCompleted => _tr ? 'Bitti' : 'Done';
  String get tabDeleted => _tr ? 'Silindi' : 'Deleted';
  String get tabFolders => _tr ? 'Klasörlerim' : 'My Folders';
  String get tabSettings => _tr ? 'Ayarlar' : 'Settings';

  // ── Folders (Klasörler) ───────────────────────────────────────────────────
  String get addFolder => _tr ? 'Klasör Ekle' : 'Add Folder';
  String get createFolder => _tr ? 'Yeni Klasör Oluştur' : 'Create New Folder';
  String get folderNameHint => _tr ? 'Klasör adı' : 'Folder name';
  String get folderNameExample =>
      _tr ? 'örn: Market Alışverişi' : 'e.g. Grocery';
  String get noFoldersYet =>
      _tr ? 'Henüz klasör yok' : 'No folders yet';
  String get noFoldersSubtitle =>
      _tr ? 'Klasör ekleyerek görevlerinizi düzenleyin.' : 'Add folders to organize your tasks.';
  String get foldersLoadError =>
      _tr ? 'Klasörler yüklenemedi' : 'Could not load folders';
  String get duplicateFolderWarning =>
      _tr ? 'Bu isimde klasör zaten var. Lütfen "Seç" bölümünden mevcut klasörü seçin.' : 'A folder with this name already exists. Please select it from the dropdown.';
  String folderCreated(String name) =>
      _tr ? '"$name" klasörü oluşturuldu' : 'Folder "$name" created';
  String get folderCreateError =>
      _tr ? 'Klasör oluşturulamadı' : 'Could not create folder';

  // ── Home screen ───────────────────────────────────────────────────────────
  String get greetingMorning => _tr ? 'Günaydın' : 'Good morning';
  String get greetingAfternoon => _tr ? 'İyi günler' : 'Good afternoon';
  String get greetingEvening => _tr ? 'İyi akşamlar' : 'Good evening';
  String get groupWork => _tr ? 'Ortak Grup' : 'Group Work';
  String get searchHint => _tr ? 'Görevlerde ara…' : 'Search tasks…';
  String get searchResults => _tr ? 'Arama Sonuçları' : 'Search Results';
  String get noResults => _tr ? 'Sonuç bulunamadı' : 'No results found';
  String get noResultsSubtitle =>
      _tr ? 'Farklı bir arama terimi deneyin.' : 'Try a different search term.';
  String get myTasks => _tr ? 'Görevlerim' : 'My Tasks';
  String tasks(int n) => _tr ? '$n görev' : '$n tasks';
  String get todayProgress =>
      _tr ? 'Bugünün İlerlemesi' : "Today's Progress";
  String completed(int done, int total) =>
      _tr ? '$done/$total tamamlandı' : '$done/$total completed';
  String get noTasksTitle => _tr ? 'Henüz görev yok!' : 'No tasks yet!';
  String get noTasksSubtitle =>
      _tr ? '"+" butonuna basarak ilk görevinizi ekleyin.' : 'Tap "+" to add your first task.';

  // ── Active screen ─────────────────────────────────────────────────────────
  String activeTitle(int n) => _tr ? 'Devam Eden ($n)' : 'Active ($n)';
  String get activeLoading => _tr ? 'Devam Eden' : 'Active';
  String get sort => _tr ? 'Sırala' : 'Sort';
  String get noActiveTasks => _tr ? 'Aktif görev yok' : 'No active tasks';
  String get noActiveSubtitle =>
      _tr ? 'Tüm görevleriniz tamamlanmış. Harika iş çıkardınız!' : 'All tasks completed. Great job!';

  // ── Completed screen ──────────────────────────────────────────────────────
  String completedTitle(int n) => _tr ? 'Tamamlanan ($n)' : 'Completed ($n)';
  String get completedLoading => _tr ? 'Tamamlanan' : 'Completed';
  String get noCompleted => _tr ? 'Henüz tamamlanan görev yok' : 'No completed tasks yet';
  String get notCompletedOnTime =>
      _tr ? 'Zamanında bitirilemedi' : 'Not completed on time';
  String get noCompletedSubtitle =>
      _tr ? 'Görevleri tamamladıkça burada görünecek.' : 'Completed tasks will appear here.';
  String get noDate => _tr ? 'Tarih yok' : 'No date';
  String get today => _tr ? 'Bugün' : 'Today';
  String get yesterday => _tr ? 'Dün' : 'Yesterday';
  String get dateLocale => _tr ? 'tr_TR' : 'en_US';
  String get datePattern => _tr ? 'd MMMM yyyy' : 'MMMM d, yyyy';
  String get homeDatePattern => _tr ? 'EEEE, d MMMM' : 'EEEE, MMMM d';

  // ── Trash screen ──────────────────────────────────────────────────────────
  String trashTitle(int n) => _tr ? 'Silinenler ($n)' : 'Deleted ($n)';
  String get trashLoading => _tr ? 'Silinenler' : 'Deleted';
  String get deleteAll => _tr ? 'Hepsini Sil' : 'Delete All';
  String get trashInfo =>
      _tr ? '30 günden eski görevler otomatik olarak kalıcı silinir.' : 'Tasks older than 30 days are automatically deleted.';
  String get noTrashTitle => _tr ? 'Çöp kutusu boş' : 'Trash is empty';
  String get noTrashSubtitle =>
      _tr ? 'Silinen görevler burada 30 gün saklanır.' : 'Deleted tasks are stored here for 30 days.';
  String get confirmDeleteAll => _tr ? 'Tümünü kalıcı sil?' : 'Permanently delete all?';
  String get confirmDeleteAllContent =>
      _tr ? 'Çöp kutusundaki tüm görevler kalıcı olarak silinecek. Bu işlem geri alınamaz.' : 'All tasks in trash will be permanently deleted. This cannot be undone.';
  String get permanentDelete => _tr ? 'Kalıcı Sil' : 'Delete Permanently';

  // ── Settings screen ───────────────────────────────────────────────────────
  String get settings => _tr ? 'Ayarlar' : 'Settings';
  String get myProfile => _tr ? 'Profilim' : 'My Profile';
  String get profileSubtitle =>
      _tr ? 'Durum, fotoğraf ve bağlantılar' : 'Status, photo and links';
  String get appearance => _tr ? 'Görünüm' : 'Appearance';
  String get theme => _tr ? 'Tema' : 'Theme';
  String get systemTheme => _tr ? 'Sistem' : 'System';
  String get lightTheme => _tr ? 'Açık' : 'Light';
  String get darkTheme => _tr ? 'Koyu' : 'Dark';
  String get language => _tr ? 'Dil Tercihleri' : 'Language';
  String get appLanguage => _tr ? 'Uygulama Dili' : 'App Language';
  String get notifications => _tr ? 'Bildirimler' : 'Notifications';
  String get notificationSettings =>
      _tr ? 'Bildirim Ayarları' : 'Notification Settings';
  String get notificationSubtitle =>
      _tr ? 'Zamanlanmış hatırlatıcılar' : 'Scheduled reminders';
  String get notificationComingSoon =>
      _tr ? 'Bildirim ayarları yakında eklenecek' : 'Notification settings coming soon';
  String get dataSync => _tr ? 'Veri & Senkronizasyon' : 'Data & Sync';
  String get syncNow => _tr ? 'Şimdi Senkronize Et' : 'Sync Now';
  String get syncSubtitle =>
      _tr ? 'Firebase ile verileri eşitle' : 'Sync data with Firebase';
  String get syncStarted =>
      _tr ? 'Senkronizasyon başlatıldı...' : 'Sync started...';
  String get about => _tr ? 'Hakkında' : 'About';
  String get appVersion => _tr ? 'Uygulama Versiyonu' : 'App Version';
  String get privacy => _tr ? 'Gizlilik Politikası' : 'Privacy Policy';
  String get signOut => _tr ? 'Çıkış Yap' : 'Sign Out';
  String get signOutConfirm =>
      _tr ? 'Çıkış yapmak istiyor musunuz?' : 'Do you want to sign out?';

  // ── Profile screen ────────────────────────────────────────────────────────
  String get profileTitle => _tr ? 'Profilim' : 'My Profile';
  String get aboutMe => _tr ? 'Hakkımda' : 'About';
  String get aboutMeTitle => _tr ? 'Hakkımda' : 'About Me';
  String get aboutMeHint =>
      _tr ? 'Kendinizi kısaca tanıtın...' : 'Introduce yourself briefly...';
  String get aboutMePlaceholder =>
      _tr ? 'Kendinizi kısaca tanıtın...' : 'Introduce yourself briefly...';
  String get privacySection => _tr ? 'Gizlilik' : 'Privacy';
  String get onlineVisibility =>
      _tr ? 'Görülme (Çevrimiçi)' : 'Online Visibility';
  String get onlineSubtitle =>
      _tr ? 'Diğerleri çevrimiçi durumunuzu görebilir' : 'Others can see your online status';
  String get readReceipts => _tr ? 'Okundu Bilgisi' : 'Read Receipts';
  String get readReceiptsSubtitle =>
      _tr ? 'Mesajlarınızın okunduğunu göster' : 'Show when your messages are read';
  String get links => _tr ? 'Bağlantılar' : 'Links';
  String get addLink => _tr ? 'Bağlantı Ekle' : 'Add Link';
  String get groups => _tr ? 'Gruplar' : 'Groups';
  String get viewGroups => _tr ? 'Gruplarımı Görüntüle' : 'View My Groups';
  String get viewGroupsSubtitle =>
      _tr ? 'Ekip çalışması ve ortak projeler' : 'Teamwork and shared projects';
  String get photoOptions => _tr ? 'Profil Fotoğrafı' : 'Profile Photo';
  String get chooseFromGallery => _tr ? 'Galeriden Seç' : 'Choose from Gallery';
  String get takePhoto => _tr ? 'Fotoğraf Çek' : 'Take Photo';
  String get enterUrlOption => _tr ? 'URL ile Ekle' : 'Add with URL';
  String get photoUrlTitle =>
      _tr ? 'Profil Fotoğrafı URL\'si' : 'Profile Photo URL';
  String get removePhoto => _tr ? 'Fotoğrafı Kaldır' : 'Remove Photo';
  String get imageTooLarge =>
      _tr ? 'Görsel çok büyük, lütfen daha küçük bir görsel seçin.' : 'Image too large, please choose a smaller one.';

  // ── Privacy banner ────────────────────────────────────────────────────────
  String get taskPrivate => _tr ? 'Özel' : 'Private';
  String get taskPrivateBanner =>
      _tr ? 'Görevleriniz özel — grup oluşturmadan kimse göremez' : 'Your tasks are private — no one can see them without a group';
  String get taskPrivateBannerGroup =>
      _tr ? 'Arkadaşlarınız var — grup oluşturarak görev paylaşabilirsiniz' : 'You have friends — create a group to share tasks';

  // ── Blocked users ────────────────────────────────────────────────────────
  String get blockedUsers => _tr ? 'Engellenenler' : 'Blocked Users';
  String get noBlockedUsers =>
      _tr ? 'Engellenen kullanıcı yok' : 'No blocked users';
  String get noBlockedUsersSubtitle =>
      _tr ? 'Engellediğiniz kullanıcılar burada görünecek.' : 'Blocked users will appear here.';
  String get blockedUsersSubtitle =>
      _tr ? 'Engellenen kullanıcıları yönetin' : 'Manage blocked users';
  String get unblock => _tr ? 'Engeli kaldır' : 'Unblock';
  String get unblockSuccess =>
      _tr ? 'Engel kaldırıldı' : 'User unblocked';
  String get errorLoadingBlocked =>
      _tr ? 'Engellenenler yüklenemedi' : 'Could not load blocked users';
  String get blockUser => _tr ? 'Engelle' : 'Block';
  String get blockConfirm =>
      _tr ? 'Bu kullanıcıyı engellemek istiyor musunuz?' : 'Block this user?';
  String get blockSuccess =>
      _tr ? 'Kullanıcı engellendi' : 'User blocked';
}

final appL10nProvider = Provider<AppL10n>((ref) {
  final locale = ref.watch(localeProvider);
  return AppL10n(locale.languageCode == 'tr');
});

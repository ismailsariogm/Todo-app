# To-Do Note

Şık, hızlı, offline-first çalışan ve ekip işbirliği destekleyen Flutter Todo uygulaması.

## Özellikler

| Özellik | Durum |
|---|---|
| Offline-first (Drift + SQLite) | ✅ MVP |
| Firebase Auth (Google + Apple + E-posta) | ✅ MVP |
| Firestore cloud sync | ✅ MVP |
| Görev ekle / düzenle / sil (soft delete) | ✅ MVP |
| Öncelik (P1–P4), Etiket, Alt görev | ✅ MVP |
| Hatırlatıcı & yerel bildirim | ✅ MVP |
| Tekrarlayan görevler | ✅ MVP |
| Filtreler (bugün/yarın/geciken/bu hafta) | ✅ MVP |
| Kayıtlı filtreler | ✅ MVP |
| Arama (başlık + notlar) | ✅ MVP |
| Grup çalışması (paylaşılan liste + üye) | ✅ MVP |
| Görev yorumları | ✅ MVP |
| Çöp kutusu (geri yükle / kalıcı sil) | ✅ MVP |
| Light/Dark tema | ✅ MVP |
| Swipe actions (tamamla / sil) | ✅ MVP |
| Onboarding (3 sayfa) | ✅ MVP |
| Takvim görünümü | ⏳ v2 |
| Dosya ekleri (upload) | ⏳ v2 |
| Konum bazlı hatırlatma | ⏳ v2 |
| İstatistik dashboard | ⏳ v2 |
| AI görev önerisi | ⏳ v2 |

---

## Başlamadan Önce Gereksinimler

- Flutter SDK ≥ 3.3.0 (stable)
- Dart ≥ 3.3.0
- Firebase projesi kurulmuş olmalı
- FlutterFire CLI kurulu olmalı

---

## Kurulum

### 1. Flutter projesini oluştur

Önce platform dosyalarını oluşturmak için çalıştır:

```bash
cd "Todo app"
flutter create . --project-name todo_note --org com.yourcompany
```

### 2. Bağımlılıkları yükle

```bash
flutter pub get
```

### 3. Code generation (Drift + Riverpod)

```bash
dart run build_runner build --delete-conflicting-outputs
```

> Her şema değişikliğinden sonra tekrar çalıştır.

### 4. Firebase kurulumu

#### 4a. Firebase projesini oluştur
1. [Firebase Console](https://console.firebase.google.com/) → Yeni proje oluştur
2. Authentication → Sign-in providers: **Google** ve **Apple** etkinleştir
3. Firestore Database → Create database (production mode)
4. Firestore Rules → `firestore.rules` dosyasındaki kuralları yapıştır

#### 4b. FlutterFire CLI

```bash
# FlutterFire CLI kurulumu (zaten yoksa)
dart pub global activate flutterfire_cli

# Firebase konfigürasyonu otomatik oluştur
flutterfire configure
```

Bu komut `lib/firebase_options.dart` dosyasını **otomatik** oluşturur.  
Mevcut placeholder dosyasını **replace** et.

#### 4c. Android – google-services.json

Firebase Console → Project settings → Android → `google-services.json` indir → `android/app/` klasörüne koy.

#### 4d. iOS – GoogleService-Info.plist

Firebase Console → Project settings → iOS → `GoogleService-Info.plist` indir → Xcode'da `Runner` hedefine ekle.

#### 4e. Apple Sign-In (iOS)

`ios/Runner/Info.plist` içine ekle:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>$(REVERSED_CLIENT_ID)</string>
    </array>
  </dict>
</array>
```

Xcode → Runner → Signing & Capabilities → **+ Sign In with Apple** ekle.

#### 4f. Google Sign-In (Android)

`android/app/build.gradle` içine SHA-1 fingerprint ekle (Firebase Console'dan alınır):
```bash
# Debug SHA-1 almak için:
cd android && ./gradlew signingReport
```

---

## Çalıştırma

```bash
# Android emülatör / cihaz
flutter run

# iOS simülatör (Mac'te)
flutter run -d iPhone

# Release build (Android)
flutter build apk --release

# Release build (iOS)
flutter build ipa --release
```

---

## Proje Yapısı

```
lib/
├── app/                    # Uygulama geneli (router, theme, providers)
│   ├── router.dart         # go_router tanımları
│   ├── theme.dart          # Material 3 tema + PriorityColor
│   └── providers.dart      # Genel providorlar (DB, theme)
│
├── data/                   # Veri katmanı
│   ├── database.dart       # Drift tabloları + DAO'lar + AppDatabase
│   ├── repositories/
│   │   ├── task_repository.dart
│   │   └── project_repository.dart
│   └── sync/
│       └── sync_service.dart  # Firestore push/pull
│
├── domain/                 # İş mantığı
│   └── entities/
│       ├── task_entity.dart
│       └── filter_entity.dart
│
├── features/               # Ekranlar + feature providorları
│   ├── auth/               # Giriş, kayıt, onboarding
│   ├── shell/              # Alt tab bar shell
│   ├── tasks/              # Ana görev ekranları
│   │   ├── home_screen.dart
│   │   ├── active_screen.dart
│   │   ├── completed_screen.dart
│   │   ├── trash_screen.dart
│   │   ├── task_form_screen.dart
│   │   ├── task_detail_screen.dart
│   │   ├── providers/      # tasks_provider, filter_provider
│   │   └── widgets/        # task_card, filter_bar, filter_bottom_sheet
│   ├── collaboration/      # Grup ekranları
│   └── settings/           # Ayarlar
│
├── services/
│   └── notification_service.dart  # flutter_local_notifications
│
├── ui/
│   └── widgets/            # Ortak widget'lar
│       └── empty_state_widget.dart
│
├── firebase_options.dart   # FlutterFire CLI tarafından oluşturulur
└── main.dart
```

---

## Drift Veri Şeması

| Tablo | Açıklama |
|---|---|
| `tasks` | Ana görev tablosu (soft delete + sync metadata) |
| `subtasks` | Alt görevler |
| `task_comments` | Görev yorumları |
| `projects` | Proje/Liste |
| `group_members` | Grup üyeleri (owner/member) |
| `saved_filters` | Kayıtlı filtre şablonları |
| `sync_outbox` | Offline-first değişiklik kuyruğu |

---

## Sync Stratejisi (Offline-First)

```
Yerel işlem
    ↓
Drift DB'ye yaz (source of truth)
    ↓
sync_outbox'a kayıt ekle
    ↓
Network gelince → pushPendingOps()
    ↓
Firestore'a yaz
    ↓
Çakışma? updatedAt büyük olan kazanır
```

---

## Testleri Çalıştırma

```bash
flutter test
```

Test dosyaları:
- `test/task_entity_test.dart` – TaskEntity iş mantığı (10 test)
- `test/filter_entity_test.dart` – Filtre sistemi (10 test)
- `test/widget_test.dart` – Widget + tema testleri (8 test)

---

## Firebase Emülatör (Geliştirme)

```bash
# Firebase CLI kurulumu
npm install -g firebase-tools

# Emülatörleri başlat
firebase emulators:start --only auth,firestore

# Flutter'a emülatör adresini bildir (main.dart'ta yorum kaldır):
# FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
# FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
```

---

## v2 Backlog

- [ ] Takvim görünümü (aylık/haftalık)
- [ ] Dosya/fotoğraf ekleri (Firebase Storage upload)
- [ ] Konum bazlı hatırlatma (geofencing)
- [ ] İstatistik dashboard (günlük/haftalık tamamlama grafikleri)
- [ ] AI ile görev önerisi (OpenAI / Gemini entegrasyonu)
- [ ] Widget (Android/iOS home screen widget)
- [ ] Supabase alternatif backend seçeneği
- [ ] Conflict history tablosu (soft merge)
- [ ] E-posta ile üye arama/doğrulama (collab davet sistemi)
- [ ] Push notification (FCM) – grup görev atamaları için

---

## Katkı

1. Fork et
2. Feature branch oluştur: `git checkout -b feature/yeni-ozellik`
3. Commit: `git commit -m "feat: yeni özellik"`
4. PR aç

---

## Lisans

MIT License – bkz. [LICENSE](LICENSE)

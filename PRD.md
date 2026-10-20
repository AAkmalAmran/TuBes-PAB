# Product Requirement Document (PRD) — v5.2 (Firebase + Provider + Offline-First + Budget Survival)

## FinQuest: Pahlawan Finansial (Mobile Application)

> **Revision summary (v5.1 → v5.2):** review fixes on top of v5.1, which follows the lecturer's Pertemuan 12 layered architecture (**UI → Store/ViewModel (`ChangeNotifier` + `provider`) → Repository → Service**) together with Pertemuan 13 (UI & notifications), 14 (web service, auth & security) and 15 (full CRUD & signed release).
> * **Bug fixes:** corrupted `NEWS_API_URL` default in §10.1; the hero name no longer stays stale after registration (`ChangeNotifierProxyProvider0` + `GameStore.updateProfile`, §6.2/§7.2); `GameStore` is safe against use-after-dispose (`_disposed` guard, §7.1/§7.4); `TransactionDetailScreen` no longer throws when its record is deleted (§9.6); an unambiguous `GameStateEvent` contract so default data can never overwrite real progress (§4.7/§5.4/§5.6).
> * **Quality:** `GameStore` receives its dependencies through the constructor, so it is unit-testable with fakes (§7.2); required `context.select`/`Selector`, change-only `notifyListeners()` and copy-on-change publishing to limit rebuilds (§7.1/§7.4); Security Rules also validate `category` (§5.3); `provider` is added with `flutter pub add` instead of a hand-written version (§2).
> * **Earlier in v5.1:** state management moved from prop-drilling to a single `GameStore extends ChangeNotifier` (`lib/state/game_store.dart`); `AppTheme.dark` added with `ThemeMode.system` (Pertemuan 06).
> * **Unchanged:** models §4.1–4.6, Firestore schema (§5.2), game rules & formulas (§8), NewsAPI logic (§10), notifications (§11), release & distribution (§12). **Changed sections:** §2 (#1), §4.7, §5.3–5.6, §6.2, §7, §9.6, §10.1, §13–§16.

---

## 1. Product Overview

* **Application Name:** FinQuest: Pahlawan Finansial
* **Platform:** Flutter (Android primary; iOS best-effort if a Mac is available)
* **Category:** Gamified Personal Finance & Financial Literacy
* **Academic Context:** Mobile Programming (BBK4DBB3) Tugas Besar 1–3, deadline mid-to-late December.

### 1.1. Problem & Target Users
* **Users:** university students and young adults (18–25) on Android with a limited allowance.
* **Problem:** they struggle to record expenses consistently and to stick to their own spending limits; typical finance apps feel like chores.
* **Solution:** an RPG where saving damages "Monster Boros", and spending **beyond the limits the user sets** hurts the hero. Reading daily finance news gives attack buffs.

### 1.2. Core Features (MVP, max 5)
| # | Feature | Summary |
|---|---|---|
| F1 | **Account & Login** | Register/login with email + password (Firebase Auth); secure session; logout |
| F2 | **Arena (log + battle)** | Log savings/expenses with category; monster battle; hero HP and level-down |
| F3 | **Daily Budget** | User-defined daily limit per category; progress bars; daily HP regeneration; daily reminder notification |
| F4 | **History & CRUD** | List, detail, edit, delete (with confirmation and undo) of transactions |
| F5 | **Daily Mission (news)** | Read up to 3 articles/day from NewsAPI (REST) for attack buffs |

### 1.3. User Flows
* **End-to-end demo flow (matches the P15 demo scenario):**
  `Register/Login → Arena: Catat Tabungan (monster hit) → Catat Pengeluaran (pick category; over limit = HP loss) → Riwayat (list) → Detail → Ubah → Hapus (confirm, Urungkan) → Quest: read article → Klaim Buff → Arena: stronger attack → Profil: Atur Batas Harian, enable Pengingat Harian → notification appears → Keluar`
* **Auth flow:** app start → `AuthGate` → (no session) Login ⇄ Register → (session) `ChangeNotifierProvider<GameStore>` wrapping `MainNavigationScreen`. Session survives app restarts and works offline.
* **CRUD flow:** Riwayat → tap item → Detail → [Ubah → Edit form → Simpan → back to list] or [Hapus → dialog → back to list + SnackBar *Urungkan*].
* **Quest flow:** Quest tab → article list → tap → reader sheet (10 s gate) → Klaim Buff → SnackBar.

### 1.4. Wireframes (low-fidelity; recreate in Figma for the P13 document)

```text
LOGIN                    ARENA                         RIWAYAT
┌────────────────┐      ┌────────────────────────┐    ┌────────────────────────┐
│   FinQuest     │      │ Pahlawan Hemat  Lv 3   │    │ Riwayat Transaksi      │
│ [Email       ] │      │ HP Hero ████████░░ 80  │    │ ┌────────────────────┐ │
│ [Kata sandi 👁]│      │ ┌────────────────────┐ │    │ │↓ Makan siang       │ │
│ [   Masuk    ] │      │ │   (monster image)  │ │    │ │  Makan  -Rp 25.000 │ │
│ Belum punya    │      │ │ Monster Kopi Susu  │ │    │ ├────────────────────┤ │
│ akun? Daftar   │      │ │ HP ██████░░░ 210   │ │    │ │↑ Tabungan          │ │
└────────────────┘      │ └────────────────────┘ │    │ │         +Rp 50.000 │ │
                         │ [Nominal Transaksi   ] │    │ └────────────────────┘ │
DETAIL / EDIT            │ [Kategori ▼ Makan    ] │    │ (empty/loading states) │
┌────────────────┐      │ Terpakai Rp 30k/50k    │    └────────────────────────┘
│ ← Detail       │      │ [Deskripsi           ] │
│ Makan siang    │      │ [Catat Tabungan]       │    PROFIL
│ -Rp 25.000     │      │ [Catat Pengeluaran]    │    ┌────────────────────────┐
│ Makan • 14 Okt │      └────────────────────────┘    │ Stats: Lv, HP, Gold    │
│ [Ubah] [Hapus] │      [Arena|Riwayat|Quest|Profil]  │ Anggaran Harian (bars) │
└────────────────┘                                     │ [Atur Batas Harian]    │
                                                       │ Pengingat Harian  [⏻]  │
                                                       │ [Keluar]               │
                                                       └────────────────────────┘
```

### 1.5. Product Principles
* **Offline-first:** after the first login, logging, budgets, battles, history, and CRUD work with **no internet** (Firestore offline cache + queued writes, synced automatically later). Only **login/register** and the **Quest article list** need the network.
* **Persistence:** all data lives in Firestore under the signed-in user; it survives restarts and reinstalls (after login).
* **Security:** per-user Firestore Security Rules, no secrets beyond the documented exception (§13), obfuscated release build.

### 1.6. Rubric Traceability (lecturer slides → this PRD)
| Slide requirement | Where covered |
|---|---|
| P06: Material 3 `ColorScheme.fromSeed`, light + dark theme | §9.1 |
| P10/P12: Detail screen, PUT/update, DELETE with confirmation & undo | §9.5–9.7 |
| P12: Layered architecture (UI → Store/ViewModel `ChangeNotifier` + `provider` → Repository → Service) | §2 (#1, #3), §3, §7 |
| P13: topic, users, max 5 features, user flow, wireframe, task division | §1.1–1.4, §17 |
| P13: folder structure, feature-per-folder, widgets ≤ ~150 lines, Git branch per feature, `flutter analyze` | §2 (#12), §3 |
| P13: all screens navigable, back works | §9.1, §15 |
| P13: loading / error / empty states, validation, two screen sizes, demo on emulator + phone | §9.10, §9.11, §15 |
| P13/P15: local notification (+ Android 13 permission) | §11 |
| P14: all main features use API/Firebase data | §5, §10 |
| P14: login works, token stored securely | §6 |
| P14: runtime permission requested when needed, app works if denied | §11 |
| P14: security checklist (HTTPS, secrets, backend validation, Security Rules, obfuscation, minimal permissions) | §13 |
| P14: performance basics (const, builder, cached images, profile mode) | §13, §15 |
| P15: full CRUD end-to-end demo | §9.5–9.7, §15 |
| P15: applicationId, version, signed build, minimal permissions, distribution evidence, README | §12 |

---

## 2. Strict Guardrails & Constraints for AI Coding Assistants

> ⚠️ **CRITICAL DIRECTIVES FOR AI ASSISTANTS & VIBECODERS:**
>
> 1. **State management: `ChangeNotifier` + `provider` ONLY (P12 architecture).** ALLOWED: `provider` with a single `GameStore extends ChangeNotifier` (`lib/state/game_store.dart`). FORBIDDEN: `bloc`, `flutter_bloc`, `riverpod`, `get`, `mobx`, creating extra `ChangeNotifier`/`ValueNotifier` classes, or global mutable variables. In UI widgets, read reactive state with `context.select<GameStore, T>((s) => s.field)` (or a `Selector<GameStore, T>`) for only the field(s) the widget needs; use a plain `context.watch<GameStore>()` only in small leaf widgets that need most of the store; use `context.read<GameStore>().method()` inside callbacks (`onPressed`, `onSubmitted`). `GameStore` receives its dependencies (`GameRepository`, `NotificationService`, `AuthService`) through the constructor and never creates them itself, so it can be unit-tested with fakes. `GameStore` must be safe after `dispose()` (no state change and no `notifyListeners()` afterwards). Local UI-only state (`TextEditingController`, `_isSubmitting`, bottom-nav `_currentIndex`, countdown `Timer`) stays in `StatefulWidget` + `setState()`.
> 2. **Backend: Firebase only.** ALLOWED: `firebase_core`, `firebase_auth`, `cloud_firestore`. FORBIDDEN: `sqflite`, `hive`, `isar`, `drift`, `objectbox`, `sembast`, `shared_preferences`, `supabase_*`, hand-written JSON/text files. Firestore's own offline cache is the only local persistence. Do NOT store tokens manually: the Firebase SDK keeps the session securely (Keystore/Keychain).
> 3. **Service & Store boundaries:** only `lib/services/*.dart` may import `firebase_*`, `cloud_firestore`, `flutter_local_notifications`, `timezone`, or `http`. Auth screens (`login_screen`, `register_screen`, `auth_gate`) may call `AuthService`. **Only `GameStore` (`lib/state/game_store.dart`) may call `GameRepository` and `NotificationService`.** Screens and widgets NEVER call `GameRepository` or `NotificationService` directly — they only read/call `GameStore` via `provider`.
> 4. **Strict directory adherence:** no files outside the tree in §3. Allowed generated/platform files: `android/`, `ios/`, `test/`, `.gitignore`, `firebase.json`, `.firebaserc`, `lib/firebase_options.dart`, and the Android manifest/Gradle edits listed in §12.
> 5. **Locked dependencies:** `flutter`, `provider`, `http`, `intl`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `flutter_local_notifications`, `timezone`, `cached_network_image`. No others without explicit request. SDK libraries (`dart:async`, `dart:convert`, `dart:io`, `package:flutter/services.dart`) are allowed.
> 6. **Zero layout overflow & responsive:** every screen/sheet with a `TextField` must be scrollable (`SingleChildScrollView`; sheets use `isScrollControlled: true` + `viewInsets.bottom` padding). No `ListView` inside `SingleChildScrollView` without `shrinkWrap: true` + `NeverScrollableScrollPhysics()`. No scrollable inside `Column` without bounds. Every screen body is wrapped in `ResponsiveBody` (max width 600, centered) so tablets look correct.
> 7. **Language:** code, comments, enum values, Firestore field names in English. All user-facing text (labels, monster/category names, dialogs, SnackBars, validation and error messages) in Indonesian.
> 8. **Do not change contracts:** models (§4), Firestore schema (§5.2), `GameStore` & widget signatures (§7.2–7.3), constants/formulas (§8). Update this PRD first, then notify the team.
> 9. **Never await a Firestore write acknowledgement in the UI path.** While offline, `batch.commit()` / `set()` Futures complete only when the server acknowledges. Pattern inside `GameStore`: compute → mutate local fields → `notifyListeners()` → call `_save()` **without `await`** (which catches async errors) → the snapshot listener reconciles. Awaiting would freeze buttons offline.
> 10. **Single source of game math:** all formulas live as static members in `game_rules.dart` (§8.9) and are reused by `GameStore` and UI previews. No duplicated formulas in widgets.
> 11. **Secrets:** never commit a real NewsAPI key; use `--dart-define` (§10, §12). `firebase_options.dart` contains client config (not secret); access is protected by Security Rules (§5.3).
> 12. **Team rules (from P13):** one feature = one folder under `screens/`; split any widget over ~150 lines; one Git branch per feature with pull requests; run `flutter analyze` before every commit; use `const` constructors wherever possible.

### Official Dependencies (`pubspec.yaml`)

```yaml
name: finquest
description: "Gamified Personal Finance Application"
publish_to: "none"
version: 1.0.0+1          # number after '+' MUST increase with every release upload

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0                    # NewsAPI (Quest)
  intl: ^0.19.0                   # Rupiah and Indonesian date formatting
  # Added with `flutter pub add` (do NOT hand-write versions; commit the generated lines):
  # provider, firebase_core, firebase_auth, cloud_firestore,
  # flutter_local_notifications, timezone, cached_network_image

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0           # if it conflicts with the team's Flutter SDK, use the version from `flutter create`

flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

Install command (run once, then commit `pubspec.yaml`/`pubspec.lock`):
```bash
flutter pub add provider firebase_core firebase_auth cloud_firestore flutter_local_notifications timezone cached_network_image
```

---

## 3. Project Architecture & Directory Tree

```text
finquest/
├── README.md                        # how to run, folder structure, task division (P15)
├── firestore.rules                  # copy of the Security Rules (§5.3)
├── android/                         # generated
├── ios/                             # generated
├── assets/
│   └── images/                      # commit the PNGs
│       ├── monster_kopi.png
│       ├── monster_belanja.png
│       └── monster_ongkir.png
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart        # generated by `flutterfire configure`
│   ├── core/
│   │   ├── constants/
│   │   │   ├── api_endpoints.dart
│   │   │   ├── app_colors.dart
│   │   │   └── game_rules.dart      # constants + pure game-math functions
│   │   ├── theme/
│   │   │   └── app_theme.dart       # AppTheme.light and AppTheme.dark (Material 3)
│   │   └── utils/
│   │       ├── formatters.dart
│   │       └── validators.dart
│   ├── models/
│   │   ├── monster.dart
│   │   ├── character.dart
│   │   ├── transaction_record.dart
│   │   ├── article.dart
│   │   ├── budget.dart
│   │   ├── game_results.dart
│   │   └── game_state.dart          # DTO between GameRepository and GameStore
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── game_repository.dart     # single gateway to Firestore
│   │   ├── notification_service.dart
│   │   └── news_service.dart
│   ├── state/
│   │   └── game_store.dart          # P12 ChangeNotifier Store / ViewModel
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── auth_gate.dart
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── main_navigation_screen.dart
│   │   ├── arena/
│   │   │   ├── arena_screen.dart
│   │   │   └── widgets/
│   │   │       ├── hero_status.dart
│   │   │       ├── monster_display.dart
│   │   │       └── attack_form.dart
│   │   ├── history/
│   │   │   ├── history_screen.dart
│   │   │   ├── transaction_detail_screen.dart
│   │   │   └── transaction_edit_screen.dart
│   │   ├── quest/
│   │   │   ├── quest_screen.dart
│   │   │   └── widgets/
│   │   │       ├── news_card.dart
│   │   │       └── article_reader_sheet.dart
│   │   └── profile/
│   │       ├── profile_screen.dart
│   │       └── widgets/
│   │           └── budget_settings_sheet.dart
│   └── widgets/
│       ├── hp_bar.dart
│       └── responsive_body.dart
├── test/
└── pubspec.yaml
```

> Mapping to the lecturer's P12 & P13 layered architecture:
> * **UI layer:** `screens/<feature>` + `widgets/`
> * **Store / ViewModel layer:** `state/game_store.dart` (`ChangeNotifier`)
> * **Repository layer:** `services/game_repository.dart`
> * **Service layer:** `services/auth_service.dart`, `services/news_service.dart`, `services/notification_service.dart`, plus Firebase SDK

---

## 4. Data Contract & Model Definitions

> Models are plain Dart classes with **no `toMap`/`fromMap`**: mapping to Firestore lives in `game_repository.dart`.

### 4.1. `lib/models/monster.dart`
```dart
class Monster {
  final String id;
  final String name;
  final int maxHp;
  int currentHp;
  final String assetImagePath;

  Monster({
    required this.id,
    required this.name,
    required this.maxHp,
    required this.currentHp,
    required this.assetImagePath,
  });

  bool get isDefeated => currentHp <= 0;
}
```

### 4.2. `lib/models/character.dart`
```dart
import '../core/constants/game_rules.dart';

class Character {
  final String name;
  int gold;
  int exp;
  int level;
  int attackBuff; // Damage modifier granted when reading news articles
  int hp;         // Current hero HP (0..maxHp)
  int maxHp;

  Character({
    required this.name,
    this.gold = 0,
    this.exp = 0,
    this.level = 1,
    this.attackBuff = 0,
    this.hp = GameRules.heroMaxHp,
    this.maxHp = GameRules.heroMaxHp,
  });
}
```

### 4.3. `lib/models/transaction_record.dart`
```dart
enum TransactionType { expense, saving }

// Fixed category list (no custom categories in this version).
enum ExpenseCategory { food, transport, entertainment, shopping, other }

extension ExpenseCategoryLabel on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.food:
        return 'Makan';
      case ExpenseCategory.transport:
        return 'Transportasi';
      case ExpenseCategory.entertainment:
        return 'Hiburan';
      case ExpenseCategory.shopping:
        return 'Belanja';
      case ExpenseCategory.other:
        return 'Lainnya';
    }
  }
}

class TransactionRecord {
  final String id;                 // Firestore document id (generated client-side)
  final String description;
  final double amount;             // whole Rupiah
  final TransactionType type;
  final DateTime date;
  final ExpenseCategory? category; // REQUIRED for expense, MUST be null for saving

  TransactionRecord({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
    this.category,
  }) : assert(
          (type == TransactionType.expense) == (category != null),
          'Expense needs a category; saving must not have one',
        );
}
```

### 4.4. `lib/models/article.dart`
```dart
class Article {
  final String title;
  final String sourceName;
  final String description;
  final String url;
  final String? urlToImage;
  final String publishedAt;

  Article({
    required this.title,
    required this.sourceName,
    required this.description,
    required this.url,
    this.urlToImage,
    required this.publishedAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: json['title'] ?? 'Tanpa Judul',
      sourceName: json['source']?['name'] ?? 'Sumber Tidak Diketahui',
      description: json['description'] ?? 'Tidak ada deskripsi tersedia.',
      url: json['url'] ?? '',
      urlToImage: json['urlToImage'],
      publishedAt: json['publishedAt'] ?? '',
    );
  }
}
```

### 4.5. `lib/models/budget.dart`
```dart
import 'transaction_record.dart';

class Budget {
  final ExpenseCategory category;
  int dailyLimit; // whole Rupiah, GameRules.minDailyLimit .. 999999999

  Budget({required this.category, required this.dailyLimit});
}
```

### 4.6. `lib/models/game_results.dart`
```dart
import 'transaction_record.dart';

class SavingResult {
  final int damage;                    // total damage dealt (0 if adventure already complete)
  final int hpRestored;                // actual hero HP restored (0 if already full)
  final bool leveledUp;
  final int newLevel;
  final String? defeatedMonsterName;   // non-null if this attack defeated the monster
  final bool adventureCompleted;       // true if the defeated monster was the last one

  SavingResult({
    required this.damage,
    required this.hpRestored,
    required this.leveledUp,
    required this.newLevel,
    this.defeatedMonsterName,
    this.adventureCompleted = false,
  });
}

class ExpenseResult {
  final ExpenseCategory category;
  final bool exceededLimit;            // this expense pushed spending further over the limit
  final int hpLost;
  final int monsterHealed;             // 0 if within limit or adventure complete
  final int remainingToday;            // limit - spent today after this expense, never below 0
  final bool hpDepleted;               // hero HP reached 0 (level-down triggered)
  final bool leveledDown;              // level actually decreased (false when already Level 1)
  final int newLevel;

  ExpenseResult({
    required this.category,
    required this.exceededLimit,
    required this.hpLost,
    required this.monsterHealed,
    required this.remainingToday,
    required this.hpDepleted,
    required this.leveledDown,
    required this.newLevel,
  });
}

enum ArticleClaimResult { granted, alreadyClaimed, dailyLimitReached, buffAtMax }
```

### 4.7. `lib/models/game_state.dart`
DTO read from / written to the user's Firestore document. The hero **name is not stored in Firestore**: it comes from the Firebase user's `displayName` (fallback: the part of the email before `@`) and is injected by `GameStore`.
```dart
import 'character.dart';
import 'monster.dart';
import 'transaction_record.dart';

class GameState {
  final Character character;                         // name is a placeholder; GameStore overrides it
  final List<Monster> monsters;                      // 3 monsters in fixed order, currentHp restored from the document
  final int currentMonsterIndex;
  final bool isAdventureComplete;
  final String lastRegenDate;                        // 'yyyy-MM-dd'
  final Map<ExpenseCategory, int> budgets;           // all 5 categories present
  final String spentDayKey;                          // the day that todaySpent belongs to
  final Map<ExpenseCategory, int> todaySpent;        // missing category = 0
  final int totalSaving;                             // all-time, whole Rupiah
  final int totalExpense;
  final Map<String, String> claimedArticles;         // url -> claimed date 'yyyy-MM-dd'
  final bool reminderEnabled;
  final bool hasPendingWrites;                       // snapshot metadata: local writes not yet synced

  GameState({
    required this.character,
    required this.monsters,
    required this.currentMonsterIndex,
    required this.isAdventureComplete,
    required this.lastRegenDate,
    required this.budgets,
    required this.spentDayKey,
    required this.todaySpent,
    required this.totalSaving,
    required this.totalExpense,
    required this.claimedArticles,
    required this.reminderEnabled,
    required this.hasPendingWrites,
  });
}

// Wraps every emission of GameRepository.watchGameState() (same file).
class GameStateEvent {
  final GameState? state;     // null = the user document does not exist in what the listener currently sees
  final bool isFromCache;     // snapshot metadata: true = served from the local cache, NOT confirmed by the server

  const GameStateEvent({required this.state, required this.isFromCache});
}
```

---

## 5. Firebase Data Layer

### 5.1. Firebase project (one shared project for the whole team)
1. Create a Firebase project (Spark/free plan is sufficient).
2. **Authentication → Sign-in method → Email/Password: enable.**
3. **Firestore Database:** create in production mode, location `asia-southeast2` (Jakarta), then publish the rules in §5.3.
4. Register the Android app with the **exact applicationId** used by the project (§12.2). Add teammates as project members.
5. Run `flutterfire configure` (§12.4) to generate `lib/firebase_options.dart` and the Android config.

### 5.2. Firestore data model (all paths are per signed-in user)

**Document `users/{uid}`** (one document holds profile-less game state; ~1 KB):

| Field | Type | Notes |
|---|---|---|
| `gold`, `exp`, `level`, `attackBuff` | int | character |
| `hp`, `maxHp` | int | hero HP |
| `monsterHp` | map<string,int> | `{kopi, belanja, ongkir}` current HP (max HP and names are code constants) |
| `currentMonsterIndex` | int | 0..2 |
| `isAdventureComplete` | bool | |
| `lastRegenDate` | string | `'yyyy-MM-dd'` |
| `budgets` | map<string,int> | keys `food, transport, entertainment, shopping, other`; each ≥ 1000 |
| `spentDayKey` | string | day that `spentToday` belongs to |
| `spentToday` | map<string,int> | category name → Rupiah spent that day |
| `totalSaving`, `totalExpense` | int | running all-time totals (aggregation queries are online-only, so totals are stored) |
| `claimedArticles` | array<map> | items `{url: string, date: 'yyyy-MM-dd'}` |
| `reminderEnabled` | bool | |
| `createdAt` | timestamp | |

**Sub-collection `users/{uid}/transactions/{txId}`** (`txId` = `collection.doc().id`, generated client-side so it works offline):

| Field | Type | Notes |
|---|---|---|
| `description` | string | ≤ 100 chars |
| `amount` | int | whole Rupiah, > 0 (store `amount.round()`) |
| `type` | string | `'expense'` or `'saving'` |
| `category` | string? | category enum name for expense; field absent/null for saving |
| `date` | timestamp | |
| `dateKey` | string | `'yyyy-MM-dd'` local day of `date` |

**Defaults for a new user document:** `gold 0, exp 0, level 1, attackBuff 0, hp = maxHp = 100`, `monsterHp` all at full (300/800/1500), index 0, not complete, `lastRegenDate = today`, `budgets = GameRules.defaultDailyLimits`, `spentDayKey = today`, `spentToday = {}`, totals 0, `claimedArticles = []`, `reminderEnabled = false`.

### 5.3. Security Rules (`firestore.rules`)
```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isOwner(uid) {
      return request.auth != null && request.auth.uid == uid;
    }

    match /users/{uid} {
      allow read, create, update: if isOwner(uid);
      allow delete: if false;

      match /transactions/{txId} {
        allow read, delete: if isOwner(uid);
        allow create, update: if isOwner(uid)
          && request.resource.data.amount is int
          && request.resource.data.amount > 0
          && request.resource.data.type in ['expense', 'saving']
          && (!('category' in request.resource.data)
              || request.resource.data.category == null
              || request.resource.data.category in ['food', 'transport', 'entertainment', 'shopping', 'other'])
          && request.resource.data.description is string
          && request.resource.data.description.size() <= 100;
      }
    }
    // everything else is denied by default
  }
}
```
Backend validation covers only structure and ownership; game math is computed on the client (§16).

### 5.4. `lib/services/game_repository.dart`: the single gateway to Firestore
```dart
class GameRepository {
  GameRepository(this.uid);
  final String uid;

  static List<Monster> defaultMonsters();                     // fresh monsters at full HP (§7.2 table)

  // users/{uid} snapshots (includeMetadataChanges: true so hasPendingWrites and isFromCache are available).
  // Every emission is a GameStateEvent: state == null means "document missing in what the listener sees",
  // isFromCache tells whether the server has confirmed that.
  Stream<GameStateEvent> watchGameState();

  // Creates the default user document ONLY IF it does not exist yet (Firestore transaction: get, then set).
  // GameStore calls it only after an event with state == null && isFromCache == false.
  // It must never overwrite an existing document. Transactions are online-only, which is acceptable
  // because the server-confirmed event proves connectivity.
  Future<void> createDefaultDocument();

  // users/{uid}/transactions ordered by date desc, limit GameRules.historyLimit.
  Stream<List<TransactionRecord>> watchRecentTransactions();

  String newTransactionId();                                   // transactions.doc().id

  // ONE WriteBatch: write all fields of [state] to users/{uid} (merge), plus at most one
  // transaction operation. Callers MUST NOT await the returned Future in the UI path (guardrail #9).
  Future<void> save(
    GameState state, {
    TransactionRecord? upsertTransaction,    // create or overwrite users/{uid}/transactions/{id}
    String? deleteTransactionId,
  });
}
```
Implementation requirements:
* Map enum names and `Timestamp` here; models stay Firestore-free.
* `monsterHp` is written as a whole map; `budgets`, `spentToday`, and `claimedArticles` are written as whole values (no dotted-path increments, no `FieldValue.increment`): the in-memory state of the single active device is authoritative.
* `amount` is written as `int` (`amount.round()`); read back with `(value as num).toDouble()`.
* `GameStateEvent.isFromCache` and `GameState.hasPendingWrites` come from `snapshot.metadata`. A missing document with `isFromCache == true` is **not** proof that the user is new (for example a fresh install that is offline), so defaults must never be created from it.
* If the history query needs an index, Firestore logs a link; a single-field `date` order does not.

### 5.5. Offline behavior
* Firestore persistence is enabled by default on Android/iOS: reads are served from the local cache, writes are queued and synced when online.
* Snapshot listeners fire immediately for local writes (latency compensation); if the server later rejects a write (Security Rules), the listener automatically reverts to server state.
* `hasPendingWrites == true` means data is saved on the device but not yet synced; the Arena shows a small chip *"Menunggu sinkronisasi"* (P2).
* **Limitation:** one active device per account (last write wins).

### 5.6. Startup flow (after login)
1. When `AuthGate` detects a signed-in `User`, it creates the `GameStore` through `ChangeNotifierProxyProvider0<GameStore>` (§6.2) with injected `GameRepository(uid)`, `NotificationService.instance`, and `AuthService()`, then calls `init()`.
2. `GameStore.init()` subscribes to `_repo.watchGameState()` and `_repo.watchRecentTransactions()`. `isLoadingState = true`, `isLoadingTransactions = true`.
3. While `isLoadingState`: `MainNavigationScreen` renders a centered `CircularProgressIndicator` with text *"Memuat data…"*. After 10 s without data, additionally show *"Menunggu koneksi untuk memuat data pertama kali…"*.
4. First event with `state != null` → fill `GameStore` fields (§7.2) → run `checkDailyRollover()` (§7.5) → if the reminder is enabled, ensure it is scheduled (§11) → `notifyListeners()`.
5. If an event arrives with `state == null && isFromCache == false` (server-confirmed missing) → `_repo.createDefaultDocument()` (create-if-absent); the listener then delivers the new state. An event with `state == null && isFromCache == true` is ignored: keep showing the loading state.
6. On stream error: `hasLoadError = true`, `notifyListeners()`; `MainNavigationScreen` shows centered *"Gagal memuat data. Coba lagi."* + **"Coba Lagi"** (`context.read<GameStore>().retryLoad()`).

---

## 6. Authentication (Firebase Auth, email + password)

### 6.1. `lib/services/auth_service.dart`
```dart
class AuthException implements Exception {
  final String message;                  // Indonesian, user-facing
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  Stream<User?> userChanges();           // FirebaseAuth.instance.userChanges()
  User? get currentUser;
  Future<void> signIn(String email, String password);                       // throws AuthException
  Future<void> register(String displayName, String email, String password); // createUser + updateDisplayName; throws AuthException
  Future<void> sendPasswordReset(String email);                              // P2
  Future<void> signOut();
}
```

### 6.2. Behavior
* **Token/session:** handled by the Firebase SDK (ID token + refresh token stored in Android Keystore / iOS Keychain). The app never reads, logs, or stores tokens itself. If a request fails with an invalid-session error, the SDK signs the user out and `AuthGate` returns to Login.
* **Offline:** the cached session opens the app offline. Login/register require internet; if offline show *"Tidak ada koneksi internet. Login membutuhkan internet."*.
* **`AuthGate`:** `StreamBuilder<User?>(stream: AuthService().userChanges())`:
  * waiting → splash (logo + `CircularProgressIndicator`);
  * `null` → `const LoginScreen()`;
  * user → `ChangeNotifierProxyProvider0<GameStore>(key: ValueKey(user.uid), create: (_) => GameStore(uid: user.uid, displayName: heroNameOf(user), email: user.email ?? '', repository: GameRepository(user.uid), notifications: NotificationService.instance, authService: AuthService())..init(), update: (_, store) => store!..updateProfile(displayName: heroNameOf(user), email: user.email ?? ''), child: const MainNavigationScreen())`, where `heroNameOf(user)` is the trimmed `displayName` if not empty, otherwise the part of the email before `@`, otherwise `'Pahlawan'`.
  * **Why `ChangeNotifierProxyProvider0`:** after registration `createUser` emits a user without a display name, and `updateDisplayName` emits a second `userChanges()` event. `update` runs on every rebuild and keeps the same store instance while refreshing the hero name, so no restart is needed. `updateProfile` calls `notifyListeners()` only if a value changed.
* **Logout:** from Profile with a confirmation dialog (*"Keluar dari akun?"*). Calls `context.read<GameStore>().logout()`, which cancels subscriptions and notifications, then signs out through the injected `AuthService`.

### 6.3. Screens
* **`LoginScreen`:** `Form` with email and password fields (password hidden with a visibility toggle), **"Masuk"** `FilledButton` (disabled + spinner while loading), link **"Belum punya akun? Daftar"** → `RegisterScreen`. Wrapped in `SingleChildScrollView` + `ResponsiveBody`. Errors shown in a SnackBar or inline text.
* **`RegisterScreen`:** fields *Nama Pahlawan*, *Email*, *Kata Sandi*, *Konfirmasi Kata Sandi*; **"Daftar"** button. On success `AuthGate` switches automatically. Back button returns to Login.

### 6.4. Validators (`lib/core/utils/validators.dart`)
| Function | Rule | Message (Indonesian) |
|---|---|---|
| `validateEmail` | required; simple pattern `x@y.z` | *Email wajib diisi* / *Format email tidak valid* |
| `validatePassword` | required; ≥ 6 chars | *Kata sandi wajib diisi* / *Kata sandi minimal 6 karakter* |
| `validateConfirmPassword` | equals password | *Konfirmasi kata sandi tidak sama* |
| `validateDisplayName` | 2–20 chars after trim | *Nama pahlawan 2–20 karakter* |
| `validateAmount` | digits only, > 0 | *Masukkan nominal lebih dari 0* |

### 6.5. Firebase error → message mapping
| `FirebaseAuthException.code` | Message (Indonesian) |
|---|---|
| `invalid-email` | Format email tidak valid. |
| `user-not-found`, `wrong-password`, `invalid-credential` | Email atau kata sandi salah. |
| `email-already-in-use` | Email sudah terdaftar. Silakan masuk. |
| `weak-password` | Kata sandi terlalu lemah (minimal 6 karakter). |
| `network-request-failed` | Tidak ada koneksi internet. Login membutuhkan internet. |
| `too-many-requests` | Terlalu banyak percobaan. Coba lagi beberapa saat lagi. |
| `user-disabled` | Akun ini dinonaktifkan. |
| any other | Terjadi kesalahan. Coba lagi. |

---

## 7. State Management (`GameStore` with `ChangeNotifier` + `provider`)

### 7.1. Principle (Matches P12 Architecture: UI → Store/ViewModel → Repository → Service)
Firestore (with its offline cache) is the persistence source of truth. **`GameStore extends ChangeNotifier`** (`lib/state/game_store.dart`) is the single application store: it subscribes to `GameRepository` streams, holds the in-memory copy that is replaced by every snapshot, applies **optimistic local updates**, calls `notifyListeners()`, and writes to Firestore without awaiting in the UI path (guardrail #9).

* **In `build()` methods:** read only what the widget needs with `context.select<GameStore, T>((s) => s.field)` (or a `Selector<GameStore, T>`), e.g. `context.select((GameStore s) => s.budgets)`. Use a plain `context.watch<GameStore>()` only in small leaf widgets that use most of the store. Reason: `MainNavigationScreen` keeps all four tabs alive in an `IndexedStack`, so a blanket `watch` rebuilds every tab on every notification (and one Firestore write can produce two snapshot events). `const` constructors do not prevent this because the `watch` happens inside the widget.
* **Copy-on-change publishing:** `select` compares values, and `Character`/`Monster` are mutable models that stay unchanged (§4). Before `notifyListeners()`, the store therefore replaces `_character` and the affected monster with fresh copies (private helpers `_copyCharacter`/`_copyMonster` in `game_store.dart`) and replaces every exposed collection (`budgets`, `todaySpent`, `recentTransactions`, `claimedArticleUrls`) with a new unmodifiable instance. Collections and models are never mutated in place after they were published. Getters return the stored instance (not a new wrapper each call).
* **Change-only notifications:** when a snapshot arrives, `GameStore` calls `notifyListeners()` only if the mapped data or `hasPendingWrites` actually changed; metadata-only duplicates are dropped.
* **Safe after `dispose()`:** `GameStore` keeps `bool _disposed = false` and overrides `notifyListeners()` to do nothing when `_disposed` is true; `dispose()` sets the flag first. All stream callbacks, `_save()` error handlers, and async actions check the flag before touching state. (After logout the provider disposes the store while `_save().catchError` callbacks may still fire.)
* **In event handlers (`onPressed`, `onSubmitted`):** use `context.read<GameStore>().method(...)` so the widget only triggers the action without subscribing inside a callback.
* Child screens never mutate objects returned by `GameStore` directly and never import Firebase or `GameRepository`.

### 7.2. `lib/state/game_store.dart` Contract
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../models/character.dart';
import '../models/game_results.dart';
import '../models/monster.dart';
import '../models/transaction_record.dart';
import '../services/auth_service.dart';
import '../services/game_repository.dart';
import '../services/notification_service.dart';

class GameStore extends ChangeNotifier {
  GameStore({
    required this.uid,
    required String displayName,
    required String email,
    required GameRepository repository,          // injected: tests pass a fake (class FakeRepo implements GameRepository)
    required NotificationService notifications,  // injected
    required AuthService authService,            // injected
  })  : _displayName = displayName,
        _email = email,
        _repo = repository,
        _notifications = notifications,
        _auth = authService;

  final String uid;
  String get displayName => _displayName;        // updated via updateProfile()
  String get email => _email;

  // --- Read-only getters for UI (read via context.select<GameStore, T>(...) / Selector) ---
  bool get isLoadingState;
  bool get isLoadingTransactions;
  bool get hasLoadError;
  bool get hasPendingWrites;
  String? get lastSyncErrorMessage;   // non-null when an async _save() failed; cleared via clearSyncError()

  Character get character;
  Monster get currentMonster;
  bool get isAdventureComplete;
  Map<ExpenseCategory, int> get budgets;
  Map<ExpenseCategory, int> get todaySpent;
  int get totalSaving;
  int get totalExpense;
  Set<String> get claimedArticleUrls;
  int get claimsToday;
  bool get reminderEnabled;
  List<TransactionRecord> get recentTransactions; // newest first, max GameRules.historyLimit

  // --- Lifecycle ---
  void init();                        // subscribes to watchGameState & watchRecentTransactions (§5.6)
  void retryLoad();                   // re-subscribes after a stream error
  void checkDailyRollover();          // §7.5, also called by MainNavigationScreen on app resume
  void clearSyncError();
  void updateProfile({required String displayName, required String email}); // refreshes the hero name; notifies only if changed

  // --- Actions (call via context.read<GameStore>().method()) ---
  Future<SavingResult?> recordSaving(double amount, String description);
  Future<ExpenseResult?> recordExpense(double amount, String description, ExpenseCategory category);
  Future<bool> updateTransaction(
    TransactionRecord original,
    double amount,
    String description,
    ExpenseCategory? category,
  );
  Future<bool> deleteTransaction(TransactionRecord record);
  Future<bool> restoreTransaction(TransactionRecord record); // undo delete
  Future<void> restartAdventure();
  Future<ArticleClaimResult> claimArticle(Article article);
  Future<bool> updateBudgets(Map<ExpenseCategory, int> newBudgets);
  Future<bool> toggleReminder(bool enabled);                 // false = permission denied / failed
  Future<void> logout();

  @override
  void dispose();                     // sets _disposed = true, then cancels _stateSub and _txSub
}
```

`GameRepository.defaultMonsters()` (fixed order):

| # | id | name (UI) | maxHp | asset |
|---|---|---|---|---|
| 1 | `kopi` | Monster Kopi Susu Mahal | 300 | `assets/images/monster_kopi.png` |
| 2 | `belanja` | Monster Belanja Impulsif | 800 | `assets/images/monster_belanja.png` |
| 3 | `ongkir` | Monster Ongkir Makanan | 1500 | `assets/images/monster_ongkir.png` |

### 7.3. Constructor Signatures (MUST be followed exactly)
Because screens read state with `context.select<GameStore, T>(...)` and trigger actions via `context.read<GameStore>()`, screen constructors are clean and `const`-friendly:

> **Reading convention for the screen specs below:** wherever a spec says a widget "watches `GameStore`", it means the widget reads the listed fields reactively with `context.select`/`Selector` (§7.1), not a blanket `context.watch`.

```dart
// lib/screens/auth/auth_gate.dart (StatelessWidget)
const AuthGate({super.key})
// lib/screens/auth/login_screen.dart (StatefulWidget; may call AuthService)
const LoginScreen({super.key})
// lib/screens/auth/register_screen.dart (StatefulWidget; may call AuthService)
const RegisterScreen({super.key})

// lib/screens/main_navigation_screen.dart (StatefulWidget; manages _currentIndex + WidgetsBindingObserver)
const MainNavigationScreen({super.key})

// lib/screens/arena/arena_screen.dart (StatelessWidget; watches GameStore)
const ArenaScreen({super.key})
// lib/screens/arena/widgets/hero_status.dart (StatelessWidget)
const HeroStatus({super.key, required Character character})
// lib/screens/arena/widgets/monster_display.dart (StatelessWidget)
const MonsterDisplay({super.key, required Monster monster})
// lib/screens/arena/widgets/attack_form.dart (StatefulWidget; watches budgets/todaySpent & calls GameStore)
const AttackForm({super.key})

// lib/screens/history/history_screen.dart (StatelessWidget; watches GameStore)
const HistoryScreen({super.key})
// lib/screens/history/transaction_detail_screen.dart (StatelessWidget; pushed with Navigator)
const TransactionDetailScreen({super.key, required TransactionRecord record}) // pops with 'edited' | 'deleted' | null
// lib/screens/history/transaction_edit_screen.dart (StatefulWidget; pushed with Navigator)
const TransactionEditScreen({super.key, required TransactionRecord record})   // pops with true when saved

// lib/screens/quest/quest_screen.dart (StatefulWidget; watches GameStore + caches NewsService Future in initState)
const QuestScreen({super.key})
// lib/screens/quest/widgets/news_card.dart (StatelessWidget)
const NewsCard({super.key, required Article article, required bool isClaimed, required VoidCallback onTap})
// lib/screens/quest/widgets/article_reader_sheet.dart (StatefulWidget; owns the countdown Timer)
const ArticleReaderSheet({super.key, required Article article, required bool isClaimed, required VoidCallback onClaim})

// lib/screens/profile/profile_screen.dart (StatelessWidget; watches GameStore)
const ProfileScreen({super.key})
// lib/screens/profile/widgets/budget_settings_sheet.dart (StatefulWidget; owns controllers, calls GameStore.updateBudgets)
const BudgetSettingsSheet({super.key, required Map<ExpenseCategory, int> initialBudgets})

// lib/widgets/hp_bar.dart (StatelessWidget; monster and hero HP)
const HpBar({super.key, required int currentHp, required int maxHp})
// lib/widgets/responsive_body.dart (StatelessWidget)
const ResponsiveBody({super.key, required Widget child, double maxWidth = 600}) // Center + ConstrainedBox
```
`AttackForm` keeps `_isSubmitting`: both buttons are disabled while an action is pending. Check `mounted`/`context.mounted` after every `await`.

### 7.4. `GameStore` Action Logic
All store actions run **synchronously from read to local apply** (no `await` between reading state and `notifyListeners()`), so rapid taps cannot interleave. Pattern: **`checkDailyRollover()` (§7.5) → compute on local fields → `notifyListeners()` → `_save(...)`** where
```dart
void _save({TransactionRecord? upsert, String? deleteId}) {
  _repo
      .save(_buildState(), upsertTransaction: upsert, deleteTransactionId: deleteId)
      .catchError((Object e) {
    if (_disposed) return;
    _lastSyncErrorMessage = 'Gagal menyimpan ke server. Perubahan dibatalkan.';
    notifyListeners();
  });
}
```
(never `await` `_save` in the UI path). All game math uses **integer Rupiah** (`amount.round()`). Field-level changes described below are applied to the fresh copies required by copy-on-change publishing (§7.1), never to objects already published.

* **`recordSaving(amount, description)`**
  1. Compute per §8.2: damage (0 if `_isAdventureComplete`, buff then not consumed), gold, exp, level, hero HP restore (§8.4). If monster HP reaches 0 → victory bonus (§8.5), recompute level, next state (`_monsterIndex + 1`, or `_isAdventureComplete = true` with the index staying on the last monster).
  2. Build `TransactionRecord(id: _repo.newTransactionId(), type: saving, category: null, date: DateTime.now(), ...)`.
  3. Update character/monster/index/flags, `_totalSaving += amount.round()`, insert the record at the top of `_recentTransactions` (trim to `GameRules.historyLimit`), `notifyListeners()`.
  4. `_save(upsert: record)`; return `SavingResult`.
* **`recordExpense(amount, description, category)`**
  1. `limit = _budgets[category]!`, `spentBefore = _todaySpent[category] ?? 0`, `newOverage = GameRules.newOverage(limit, spentBefore, amount.round())`.
  2. `newOverage == 0` → no gameplay effect. Otherwise `hpLost = GameRules.hpLoss(newOverage)`; `monsterHealed = _isAdventureComplete ? 0 : GameRules.monsterHeal(newOverage)` (clamped to the monster's `maxHp`).
  3. Apply `hpLost`; if HP ≤ 0 → level-down rule (§8.4), HP refilled to max.
  4. Build the expense record (with category), replace `_todaySpent` with a copy in which `[category] = spentBefore + amount.round()`, `_totalExpense += amount.round()`, insert into `_recentTransactions`, `notifyListeners()`, `_save(upsert: record)`; return `ExpenseResult`.
* **`updateTransaction(original, amount, description, category)`** ("koreksi catatan"): `diff = amount.round() - original.amount.round()`; adjust `_totalSaving` or `_totalExpense` by `diff`; if `dateKey(original.date) == _spentDayKey` and it is an expense: subtract the old amount from the old category and add the new amount to the new category in `_todaySpent` (clamp ≥ 0). Type and date are not editable. Build the updated record (same `id`, `date`, `type`), replace in `_recentTransactions`, `notifyListeners()`, `_save(upsert: updated)`, return `true`. **No gameplay effect is recalculated** (HP, monster, gold, EXP, buff stay as they were).
* **`deleteTransaction(record)`**: reverse totals and (if today's expense) `_todaySpent`; remove from `_recentTransactions`; `notifyListeners()`; `_save(deleteId: record.id)`; return `true`. No gameplay rollback.
* **`restoreTransaction(record)`** (undo): re-apply totals/`_todaySpent`, re-insert into `_recentTransactions` in descending date order, `notifyListeners()`, `_save(upsert: record)`; return `true`.
* **`restartAdventure()`**: `_monsters = GameRepository.defaultMonsters()`, `_monsterIndex = 0`, `_isAdventureComplete = false`; `notifyListeners()`; `_save()`.
* **`claimArticle(article)`**, evaluated in this order:
  1. `today = todayKey()`.
  2. URL already in `_claimedArticles` → `alreadyClaimed`.
  3. `claimsToday >= GameRules.dailyArticleQuota` → `dailyLimitReached`.
  4. `_character.attackBuff >= GameRules.maxAttackBuff` → `buffAtMax`.
  5. Otherwise `_character.attackBuff += GameRules.articleBuff`, `_claimedArticles[article.url] = today`, `notifyListeners()`, `_save()` → `granted`.
* **`updateBudgets(newBudgets)`**: validate each value ≥ `minDailyLimit`, update `_budgets`, `notifyListeners()`, `_save()`, return `true`. Applies only to expenses logged afterwards.
* **`toggleReminder(enabled)`**: see §11.
* **`logout()`**: cancel `_stateSub` and `_txSub`, `await _notifications.cancelAll()`, `await _auth.signOut()`. The provider then disposes the store when `AuthGate` swaps to Login.
* `claimsToday` getter returns the count of `_claimedArticles.values` equal to `todayKey()`.

### 7.5. Daily rollover (`checkDailyRollover`)
Runs inside `GameStore` after the first state load, at the start of `recordSaving`/`recordExpense`, and when the app resumes (`MainNavigationScreen` implements `WidgetsBindingObserver.didChangeAppLifecycleState` → on `AppLifecycleState.resumed`, calls `context.read<GameStore>().checkDailyRollover()`).
```
today = todayKey()
if _spentDayKey != today:  _todaySpent = {}; _spentDayKey = today
if _lastRegenDate < today: // string compare works for 'yyyy-MM-dd'
    days = DateTime.parse(today).difference(DateTime.parse(_lastRegenDate)).inDays
    hp = min(maxHp, hp + days * GameRules.dailyHpRegen); _lastRegenDate = today
```
If the device date moves backward (`_lastRegenDate > today`), do nothing. If anything changed, `notifyListeners()` and `_save()`.

---

## 8. Game Rules (unchanged formulas)

All numbers live in `lib/core/constants/game_rules.dart`.

```dart
import '../../models/transaction_record.dart';

class GameRules {
  // --- Monster battle ---
  static const int rupiahPerDamage = 1000;   // Rp 1.000 saved = 1 damage
  static const int rupiahPerGold = 1000;     // Rp 1.000 saved = 1 gold
  static const int baseExpPerSaving = 10;
  static const int rupiahPerBonusExp = 5000; // +1 EXP per Rp 5.000 saved
  static const int rupiahPerHeal = 2000;     // Rp 2.000 of NEW overage = 1 HP healed on the monster
  static const int victoryGold = 50;
  static const int victoryExp = 50;
  static const int expPerLevel = 100;        // level = 1 + exp ~/ 100

  // --- Hero HP & budgets ---
  static const int heroMaxHp = 100;
  static const int rupiahPerHpLoss = 1000;   // Rp 1.000 of NEW overage = 1 hero HP lost (min 1)
  static const int rupiahPerHpHeal = 5000;   // Rp 5.000 saved = 1 hero HP restored (min 1)
  static const int dailyHpRegen = 25;        // per calendar day (lazy, §7.5)
  static const int minDailyLimit = 1000;
  static const Map<ExpenseCategory, int> defaultDailyLimits = {
    ExpenseCategory.food: 50000,
    ExpenseCategory.transport: 20000,
    ExpenseCategory.entertainment: 30000,
    ExpenseCategory.shopping: 50000,
    ExpenseCategory.other: 30000,
  };

  // --- Daily mission ---
  static const int articleBuff = 50;
  static const int maxAttackBuff = 150;
  static const int dailyArticleQuota = 3;
  static const int readSeconds = 10;

  // --- Misc ---
  static const int historyLimit = 100;
  // Pure functions: §8.9
}
```

### 8.1. Monsters
HP: Kopi Susu Mahal **300**, Belanja Impulsif **800**, Ongkir Makanan **1500**; fixed order; `currentHp` clamped to `0..maxHp`.

### 8.2. Saving ("Catat Tabungan"): player attacks
```
baseDamage = max(1, amount ~/ rupiahPerDamage)
damage     = isAdventureComplete ? 0 : baseDamage + attackBuff
newHp      = max(0, monster.currentHp - damage)          // skipped if complete
attackBuff = isAdventureComplete ? attackBuff : 0        // consumed by a real attack only
gold      += amount ~/ rupiahPerGold
exp       += baseExpPerSaving + amount ~/ rupiahPerBonusExp
level      = 1 + exp ~/ expPerLevel
heroHp     = min(maxHp, heroHp + max(1, amount ~/ rupiahPerHpHeal))
```
SnackBar: *"Serangan berhasil! Monster menerima {damage} damage."* + *" HP +{hpRestored}."* (if > 0) + *" Naik level! Sekarang Level {level}."* (if leveled up). If the adventure is complete: *"Tabungan tercatat! Semua monster sudah kalah."*

### 8.3. Expense ("Catat Pengeluaran") and daily budget
"Over the limit" means **strictly greater** than the limit.
```
overBefore = max(0, spentBefore - limit)
overAfter  = max(0, spentBefore + amount - limit)
newOverage = overAfter - overBefore       // only the newly exceeded part
```
| Case | Effect |
|---|---|
| `newOverage == 0` | Logged only: no HP loss, no monster heal, no gold/EXP change |
| `newOverage > 0` | Hero loses `max(1, newOverage ~/ rupiahPerHpLoss)` HP; monster heals `max(1, newOverage ~/ rupiahPerHeal)` HP (0 if adventure complete) |

Example (Makan limit Rp 50.000): 30.000 → none (remaining 20.000); then 40.000 → `newOverage` 20.000 → hero −20 HP, monster +10; then 10.000 → `newOverage` 10.000 → hero −10, monster +5.

SnackBars: within limit *"Pengeluaran {label} tercatat. Sisa batas hari ini: {Rp}."*; over limit *"Batas {label} harian terlampaui! HP kamu −{hpLost}, monster pulih +{monsterHealed}."* (omit the monster part when 0).

### 8.4. Hero HP, healing, regeneration & level-down
* HP range `0..maxHp` (default 100). Healing: saving records and daily regeneration (+25/day, capped).
* **Trigger:** after applying `hpLost`, if `hp <= 0`:
  ```
  if level > 1: level -= 1; exp = (level - 1) * expPerLevel; leveledDown = true
  else:         exp = 0; leveledDown = false
  hp = maxHp; hpDepleted = true
  ```
  Gold, monster progress, and buff are unaffected; leftover overage damage is discarded; invariant `level == 1 + exp ~/ expPerLevel` always holds.
* **Dialog** (`showDialog`, not dismissible, button *"Mengerti"*): level dropped → *"HP kamu habis! Level turun ke Level {n}. HP dipulihkan penuh."*; already Level 1 → *"HP kamu habis! Kamu sudah di Level 1, jadi EXP direset ke 0. HP dipulihkan penuh."*

### 8.5. Victory & end of game
* Victory rewards (`victoryGold`, `victoryExp`) are applied in the same local update and the same Firestore batch as the finishing blow.
* Arena shows a victory dialog (not dismissible): *"Kamu mengalahkan {name}! Hadiah: +50 Gold, +50 EXP"*, button *"Lanjut"*.
* After the last monster: end-state card *"Semua Monster Boros Telah Dikalahkan!"* + **"Mulai Petualangan Baru"** (`context.read<GameStore>().restartAdventure()`). **The attack form stays visible**: saving still gives Gold/EXP/HP without damage; expenses still cost HP without healing a monster.

### 8.6. Daily Mission (news)
* Up to **3 different articles per local day**; each claim gives **+50** buff; an article URL can be claimed **once, ever**; buff stacks to **+150**, is stored in Firestore, usable offline, and consumed by the next real saving attack.
* **Reading gate:** tapping an article opens `ArticleReaderSheet`; **"Klaim Buff"** is disabled for 10 s with a countdown (*"Baca dulu… 7 detik"*).
* SnackBars: `granted` *"Misi harian tercapai! Kamu mendapatkan Buff Serangan +50!"*; `alreadyClaimed` *"Artikel ini sudah kamu klaim. Cari artikel lain!"*; `dailyLimitReached` *"Misi harian hari ini sudah selesai (3/3). Kembali lagi besok!"*; `buffAtMax` *"Buff Serangan sudah maksimal (+150). Gunakan dulu untuk menyerang!"*

### 8.7. Financial health (Profile)
`ratio = totalSaving / (totalSaving + totalExpense)`: no data → *Belum ada data*; ≥ 0.70 → *Sehat 💚*; 0.40–0.69 → *Waspada 💛*; < 0.40 → *Boros ❤️*.

### 8.8. Level display
`level = 1 + exp ~/ expPerLevel`; Profile shows *"{exp % 100} / 100 EXP menuju level berikutnya"*.

### 8.9. Pure functions in `game_rules.dart`
```dart
static int newOverage(int limit, int spentBefore, int amount) {
  final overBefore = (spentBefore - limit) > 0 ? spentBefore - limit : 0;
  final overAfter = (spentBefore + amount - limit) > 0 ? spentBefore + amount - limit : 0;
  return overAfter - overBefore;
}
static int hpLoss(int newOverage) =>
    newOverage <= 0 ? 0 : (newOverage ~/ rupiahPerHpLoss < 1 ? 1 : newOverage ~/ rupiahPerHpLoss);
static int monsterHeal(int newOverage) =>
    newOverage <= 0 ? 0 : (newOverage ~/ rupiahPerHeal < 1 ? 1 : newOverage ~/ rupiahPerHeal);
static int heroHpRestore(int amount) =>
    (amount ~/ rupiahPerHpHeal) < 1 ? 1 : amount ~/ rupiahPerHpHeal;
```

---

## 9. Screen Specifications

### 9.1. Entry, Theme & Navigation
* `main.dart`: `WidgetsFlutterBinding.ensureInitialized()` → `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` → `await initializeDateFormatting('id_ID')` → `await NotificationService.instance.init()` → `runApp(MaterialApp(title: 'FinQuest', theme: AppTheme.light, darkTheme: AppTheme.dark, themeMode: ThemeMode.system, debugShowCheckedModeBanner: false, home: const AuthGate()))`. No network calls at startup.
* `AppTheme`:
  * `AppTheme.light`: `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light))`
  * `AppTheme.dark`: `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark))`
  * **All colors, fonts, and buttons come from `Theme.of(context)`** (consistency & dark-mode checklist); `AppColors` holds only seed and semantic `Color` constants.
* `MainNavigationScreen`: watches `GameStore` for initial `isLoadingState` / `hasLoadError` (§5.6). When loaded, shows a Material 3 `NavigationBar` (not `BottomNavigationBar`) with `IndexedStack(index: _currentIndex, children: const [ArenaScreen(), HistoryScreen(), QuestScreen(), ProfileScreen()])`:

| Index | Label | Icon |
|---|---|---|
| 0 | Arena | `Icons.shield` |
| 1 | Riwayat | `Icons.receipt_long` |
| 2 | Quest | `Icons.newspaper` |
| 3 | Profil | `Icons.person` |

* Detail/Edit screens are pushed with `Navigator.push(MaterialPageRoute)`; the back button/arrow always works. (`go_router` is optional and not used; adding it requires a PRD change.)

### 9.2. Formatters (`formatters.dart`)
```dart
String formatRupiah(num value);        // NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
String formatDate(String isoString);   // tryParse -> toLocal -> DateFormat('d MMM yyyy, HH:mm', 'id_ID'); fallback '-'
String formatDateTime(DateTime date);
String dateKey(DateTime date);         // 'yyyy-MM-dd' (local)
String todayKey();
```
All money goes through `formatRupiah` (e.g. `Rp 10.000`).

### 9.3. Battle Arena (`arena_screen.dart`)
* Watches `GameStore`. Body: `SingleChildScrollView` inside `ResponsiveBody`. Order: optional chip *"Menunggu sinkronisasi"* (when `store.hasPendingWrites`), `HeroStatus(character: store.character)`, `MonsterDisplay(monster: store.currentMonster)`, end-state card (if `store.isAdventureComplete`), `const AttackForm()`.
* **`HeroStatus`:** name, *"Level {level}"*, *"HP Hero: {hp} / {maxHp}"* with `HpBar`, buff chip *"Buff Serangan: +{attackBuff}"* (if > 0).
* **`MonsterDisplay`:** `Image.asset(..., height: 180, semanticLabel: monster.name, errorBuilder: placeholder icon)`; name; `Text('HP: ${currentHp} / ${maxHp}')`; `HpBar`.
* **`HpBar`:** `TweenAnimationBuilder<double>` (400 ms) → `LinearProgressIndicator(minHeight: 14)` with rounded corners; green > 50 %, orange 25–50 %, red < 25 %.
* **`AttackForm`:** watches `budgets` and `todaySpent` from `GameStore`; amount `TextField` (`TextInputType.number`, `digitsOnly`, max 9 digits, `OutlineInputBorder`, `prefixIcon: Icon(Icons.monetization_on)`, label *"Nominal Transaksi"*); category `DropdownMenu<ExpenseCategory>` (label *"Kategori Pengeluaran"*, default `food`); live hint *"Terpakai hari ini: {Rp spent} / {Rp limit}"* and red warning *"Melebihi batas! Perkiraan HP −{n}"* (via `GameRules`); description `TextField` (≤ 100 chars, label *"Deskripsi (opsional)"*, fallback *"Tabungan"*/*"Pengeluaran"*); buttons **"Catat Tabungan"** (`FilledButton`) and **"Catat Pengeluaran"** (`OutlinedButton`), disabled while `_isSubmitting`; validation via `validateAmount` (inline error). After success: clear amount/description (keep category), unfocus keyboard; dispose controllers.
* **After saving:** `final res = await context.read<GameStore>().recordSaving(...)` → SnackBar (§8.2) → victory dialog if `res?.defeatedMonsterName != null`. **After expense:** `final res = await context.read<GameStore>().recordExpense(...)` → SnackBar (§8.3) → HP-depleted dialog if `res?.hpDepleted == true`.
* Works fully offline.

### 9.4. Quest & News (`quest_screen.dart`): the only list that needs internet
* `StatefulWidget` with `late Future<List<Article>> _articlesFuture;` set in `initState()` and re-assigned on retry/refresh. **Never call `NewsService` in `build()`.**
* Watches `GameStore` for `character`, `claimedArticleUrls`, and `claimsToday`.
* Header (offline-safe): *"Misi Harian: {claimsToday}/3 artikel"*, progress indicator, buff chip, note *"Arena, Riwayat, dan Profil tetap bisa dipakai tanpa internet."*
* `FutureBuilder<List<Article>>`: waiting → `CircularProgressIndicator`; error → icon + Indonesian message (§10.3) + **"Coba Lagi"**; empty → *"Belum ada berita saat ini."* + retry; data → `ListView.builder` of `NewsCard` (optional `RefreshIndicator`).
* `NewsCard`: Material `Card`; thumbnail via **`CachedNetworkImage`** only if `urlToImage != null` (placeholder + error widget, `memCacheHeight: 180`); title (max 3 lines); source; `formatDate`; *"Sudah diklaim"* badge + dimmed style if claimed.
* Tap → `showModalBottomSheet(isScrollControlled: true)` with `ArticleReaderSheet` (title, source, date, description, `SelectableText(url)`; countdown via `Timer.periodic`, cancelled in `dispose()`; disabled with *"Sudah Diklaim"* if claimed). On **"Klaim Buff"**: close the sheet, `final result = await context.read<GameStore>().claimArticle(article)`, hide the current SnackBar, show the message for `result` (§8.6).
* Articles are not opened in a browser (no `url_launcher`).

### 9.5. History / List (`history_screen.dart`)
* Watches `GameStore` (`recentTransactions`, `isLoadingTransactions`).
* Title *"Riwayat Transaksi (100 terakhir)"*; `ListView.builder` inside `ResponsiveBody`, newest first. Item: icon (saving = green up-arrow, expense = red down-arrow), description, category label (expense), `formatDateTime`, signed amount (`+Rp` / `-Rp`).
* **States:** loading → `CircularProgressIndicator`; empty → *"Belum ada transaksi. Mulai catat di Arena!"*.
* Tap → `final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => TransactionDetailScreen(record: record)))`. On return `'deleted'` → SnackBar *"Transaksi dihapus"* with action **"Urungkan"** → `context.read<GameStore>().restoreTransaction(record)`; on `'edited'` → SnackBar *"Transaksi diperbarui"*.

### 9.6. Transaction Detail (`transaction_detail_screen.dart`)
* Receives `record` via constructor and shows the latest version of `record.id` taken from `context.select((GameStore s) => s.recentTransactions)`, using `indexWhere` or `firstWhere(..., orElse: () => widget.record)`. After a delete the record disappears from the list: the screen must fall back to the constructor record and **never throw** while it pops (keep a local `_isDeleting` flag to avoid stale UI).
* Shows description, amount (`formatRupiah`), type, category, full date/time. Buttons **"Ubah"** (`FilledButton`) and **"Hapus"** (`OutlinedButton`, error color).
* **Ubah** → push `TransactionEditScreen(record: currentRecord)`; on `true` pop with `'edited'`.
* **Hapus** → confirmation `AlertDialog` *"Hapus transaksi ini? Efek pertarungan yang sudah terjadi (HP, monster, Gold) tidak dibatalkan."* with *"Batal"* / *"Hapus"* → `await context.read<GameStore>().deleteTransaction(currentRecord)` → pop with `'deleted'`.

### 9.7. Transaction Edit (`transaction_edit_screen.dart`)
* `Form` in `SingleChildScrollView` + `ResponsiveBody`. Fields: amount (prefilled, `digitsOnly`, `validateAmount`), description (≤ 100), category dropdown (**only for expenses**). Type and date are read-only text.
* Notice text: *"Perubahan hanya memperbarui catatan dan total. Efek pertarungan tidak dihitung ulang."*
* **"Simpan"** disabled while submitting; calls `await context.read<GameStore>().updateTransaction(widget.record, amount, desc, category)`; on `true` pop with `true`. Validation errors inline.

### 9.8. Profile (`profile_screen.dart`)
* Watches `GameStore`. `SingleChildScrollView` + `Column` inside `ResponsiveBody`.
* **Hero Stats (Card):** name, email, Level, HP (`HpBar`), Gold, EXP progress text, Active Buff.
* **Anggaran Harian (Card):** per category *"{Rp spent} / {Rp limit}"* + `LinearProgressIndicator` (clamped; green < 80 %, orange 80–100 %, red > 100 %); button **"Atur Batas Harian"** → `BudgetSettingsSheet(initialBudgets: store.budgets)`.
* **`BudgetSettingsSheet`:** `showModalBottomSheet(isScrollControlled: true)`, `SingleChildScrollView`, padding `viewInsets.bottom`; five numeric fields (prefix *"Rp "*, `digitsOnly`, max 9 digits); each must be ≥ `minDailyLimit` (*"Minimal Rp 1.000"*); **"Simpan"** → `context.read<GameStore>().updateBudgets(newBudgets)`; success SnackBar *"Batas harian diperbarui. Berlaku untuk pengeluaran berikutnya."*
* **Pengingat Harian:** `SwitchListTile` *"Pengingat Harian (20.00 WIB)"*. On toggle → `final ok = await context.read<GameStore>().toggleReminder(value)`; if `!ok` (denied) show *"Izin notifikasi ditolak. Aktifkan lewat Pengaturan aplikasi jika ingin pengingat."*
* **Ringkasan Keuangan (Card):** Total Tabungan, Total Pengeluaran, health label (§8.7).
* **"Keluar"** button → confirmation dialog → `await context.read<GameStore>().logout()`.

### 9.9. Responsive Layout (phone + tablet)
Every screen body uses `ResponsiveBody` (center, max width 600). Verify on a small phone (360×640), a large phone, and a 10" tablet emulator, in portrait and landscape. (Optional P2: `NavigationRail` instead of `NavigationBar` when width ≥ 840.)

### 9.10. Required UI states (P13 checklist)
| Screen | Loading | Error | Empty |
|---|---|---|---|
| Initial load | spinner + text | message + Coba Lagi | n/a (defaults created) |
| Login/Register | button spinner | SnackBar/inline message | n/a |
| Riwayat | spinner | write errors via SnackBar | *Belum ada transaksi…* |
| Quest | spinner | message + Coba Lagi | *Belum ada berita…* |

### 9.11. Form validation (P13 checklist)
Login, Register, Arena amount, Edit transaction, and Budget settings all show clear inline Indonesian messages for each required field (§6.4).

---

## 10. Network Service (NewsAPI, Quest only)

### 10.1. `lib/core/constants/api_endpoints.dart`
```dart
class ApiEndpoints {
  static const String apiKey = String.fromEnvironment('NEWS_API_KEY');
  static const String baseUrl =
      String.fromEnvironment('NEWS_API_URL', defaultValue: 'https://newsapi.org');
  static const String financialNewsUrl =
      '$baseUrl/v2/top-headlines?category=business&country=us&apiKey=$apiKey';
}
```
* HTTPS only. `country=us` is deliberate (the free tier returns little or nothing for `country=id`); article text is English while the UI is Indonesian.
* If `apiKey` is empty, the service throws without calling the network.

### 10.2. `lib/services/news_service.dart`
```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../core/constants/api_endpoints.dart';

class NewsException implements Exception {
  final String message; // Indonesian, user-facing
  NewsException(this.message);
  @override
  String toString() => message;
}

class NewsService {
  Future<List<Article>> fetchFinancialNews() async {
    if (ApiEndpoints.apiKey.isEmpty) {
      throw NewsException('API key belum diatur. Jalankan aplikasi dengan --dart-define=NEWS_API_KEY=...');
    }
    try {
      final response = await http
          .get(Uri.parse(ApiEndpoints.financialNewsUrl))
          .timeout(const Duration(seconds: 10));
      switch (response.statusCode) {
        case 200:
          final Map<String, dynamic> data = jsonDecode(response.body);
          final List<dynamic> articlesJson = data['articles'] ?? [];
          return articlesJson
              .map((json) => Article.fromJson(json as Map<String, dynamic>))
              .where((a) => a.title != '[Removed]' && a.url.isNotEmpty)
              .toList();
        case 401:
          throw NewsException('API key tidak valid. Periksa kembali key NewsAPI kamu.');
        case 429:
          throw NewsException('Kuota NewsAPI hari ini habis. Coba lagi besok.');
        default:
          throw NewsException('Gagal memuat berita (kode ${response.statusCode}). Coba lagi nanti.');
      }
    } on SocketException {
      throw NewsException('Tidak ada koneksi internet. Misi harian butuh internet; fitur lain tetap bisa dipakai.');
    } on TimeoutException {
      throw NewsException('Koneksi terlalu lama. Coba lagi.');
    } on FormatException {
      throw NewsException('Data berita tidak dapat dibaca. Coba lagi nanti.');
    }
  }
}
```

### 10.3. Error → UI message
Missing key, 401, 429, other non-200, `SocketException`, `TimeoutException`, `FormatException` map to the messages above; anything else → *"Terjadi kesalahan. Coba lagi."* (`QuestScreen` shows `error is NewsException ? error.message : 'Terjadi kesalahan. Coba lagi.'`).

---

## 11. Notifications & Runtime Permission

### 11.1. Feature: Daily Reminder (local notification)
* Title *"Pengingat FinQuest"*, body *"Sudah catat pengeluaran hari ini? Monster Boros menunggumu!"*, channel id `finquest_reminder`, channel name *"Pengingat Harian"*.
* Scheduled every day at **20:00 WIB** (`Asia/Jakarta`) with `zonedSchedule`, `matchDateTimeComponents: DateTimeComponents.time`, and **inexact** scheduling (`AndroidScheduleMode.inexactAllowWhileIdle`): exact alarms are restricted on recent Android and not needed here. Time zone is fixed to WIB (`tz.initializeTimeZones(); tz.setLocalLocation(tz.getLocation('Asia/Jakarta'))`); this is a documented limitation.
* Follow the `flutter_local_notifications` README for the installed version (the lecturer's slides use the named-parameter API, e.g. `initialize(settings: ...)`, `show(id: ..., ...)`).

### 11.2. `lib/services/notification_service.dart`
```dart
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  Future<void> init();                     // plugin init + timezone setup (called in main)
  Future<bool> requestPermission();        // Android 13+: POST_NOTIFICATIONS via the plugin; true if granted or not needed
  Future<void> scheduleDailyReminder();    // fixed id (e.g. 1), idempotent
  Future<void> cancelDailyReminder();
  Future<void> cancelAll();
}
```

### 11.3. Permission flow (P14 rules)
1. Permission is requested **only when the user turns the reminder switch ON** (not at app start).
2. Before calling `toggleReminder(true)`, `ProfileScreen` shows a short explanation dialog: *"FinQuest ingin mengirim pengingat harian agar kamu tidak lupa mencatat pengeluaran."* with *"Nanti"* / *"Lanjut"*.
3. Inside `GameStore.toggleReminder(true)`: calls `_notifications.requestPermission()`. If granted → `scheduleDailyReminder()`, `_reminderEnabled = true`, `notifyListeners()`, `_save()`, returns `true`.
4. Denied → switch stays OFF (`_reminderEnabled = false`), returns `false`, and `ProfileScreen` shows the denial message (§9.8). **The app remains fully functional.**
5. On each app load with `_reminderEnabled == true`, `GameStore` re-ensures the schedule (idempotent); if permission was revoked meanwhile, set `_reminderEnabled = false`.

### 11.4. Android manifest
Permissions are minimal: `INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` (reschedule after reboot). Add the plugin's receivers and enable core library desugaring exactly as its README states (§12.6). Remove any permission not listed here.

---

## 12. Setup, Release & Distribution

### 12.1. Prerequisites
Flutter SDK, Android Studio/SDK, Firebase CLI (`npm i -g firebase-tools` or the standalone installer), FlutterFire CLI (`dart pub global activate flutterfire_cli`), a Google account added to the team's Firebase project.

### 12.2. Create the project (first teammate only; others clone)
```bash
flutter create . --org id.ac.telkomuniversity --project-name finquest --platforms=android,ios
```
This gives the applicationId `id.ac.telkomuniversity.finquest`. **The applicationId is permanent once published and must match the Android app registered in Firebase**; decide it now. Do not let `flutter create` overwrite `lib/main.dart` or `pubspec.yaml` contents (restore from Git if needed).

### 12.3. Scaffold directories (if starting clean)
* macOS/Linux/Git Bash:
  ```bash
  mkdir -p assets/images lib/core/constants lib/core/theme lib/core/utils lib/models lib/services lib/state lib/screens/auth lib/screens/arena/widgets lib/screens/history lib/screens/quest/widgets lib/screens/profile/widgets lib/widgets
  ```
* Windows PowerShell:
  ```powershell
  New-Item -ItemType Directory -Force -Path assets/images, lib/core/constants, lib/core/theme, lib/core/utils, lib/models, lib/services, lib/state, lib/screens/auth, lib/screens/arena/widgets, lib/screens/history, lib/screens/quest/widgets, lib/screens/profile/widgets, lib/widgets
  ```
Commit the three monster PNGs (empty folders are not tracked by Git).

### 12.4. Connect Firebase & Install Packages
```bash
firebase login
flutterfire configure        # pick the team project and the Android (and iOS) app
flutter pub add provider firebase_core firebase_auth cloud_firestore flutter_local_notifications timezone cached_network_image
flutter pub get
```
Publish `firestore.rules` in the console (Firestore → Rules) and keep the same text in the repo.

### 12.5. Run
```bash
flutter analyze
flutter run --dart-define=NEWS_API_KEY=YOUR_ACTUAL_API_KEY
```
VS Code: put `"args": ["--dart-define=NEWS_API_KEY=..."]` in a **local, uncommitted** `launch.json` (add `.vscode/` to `.gitignore`). Android Studio: *Run → Edit Configurations → Additional run args*. Emulator note: a local dev server would be `http://10.0.2.2:PORT`, but this project uses only HTTPS services.

### 12.6. Android configuration checklist
* `minSdk` as required by the Firebase plugins (check the plugin changelog; raise it in `android/app/build.gradle(.kts)` if the build complains).
* Core library desugaring enabled and its dependency added, as `flutter_local_notifications` requires.
* `AndroidManifest.xml`: only the permissions in §11.4, plus the notification receivers from the plugin README. `INTERNET` is mandatory for release builds.
* Launcher icon and app label (*FinQuest*) set (identity checklist).

### 12.7. Release build (P15)
1. **Upload key (once):** `keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`. Store the file and passwords safely; **never commit them**.
2. Create `android/key.properties` (gitignored) and configure signing in the app Gradle file as in docs.flutter.dev/deployment/android.
3. Bump `version` in `pubspec.yaml` (`1.0.0+1`, increase the number after `+` for every upload).
4. Build (obfuscated):
   ```bash
   flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define=NEWS_API_KEY=YOUR_ACTUAL_API_KEY
   flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define=NEWS_API_KEY=YOUR_ACTUAL_API_KEY
   ```
   Keep `build/symbols` for each released version (needed to read obfuscated crash traces).
5. **Test the release build on a real device:** normal network, slow network, and airplane mode.

### 12.8. Distribution (evidence required)
* **Recommended for class assessment:** Firebase App Distribution (testers receive an invite link) and/or the signed APK/AAB file.
* **Google Play:** a new personal developer account needs a closed test with ≥ 12 testers for 14 consecutive days before production access. Only plan this if the lecturer requires Play and recruiting starts early. Get written approval from the lecturer for any alternative.
* If publishing to Play: complete **Data safety** (collected: email, display name, financial entries; stored in Firebase), add a **privacy policy** URL, and provide **in-app account deletion** (Play policy for apps with accounts; currently out of scope, see §16).

### 12.9. README.md (P15)
Must contain: how to run (with `--dart-define`), Firebase setup notes, folder structure, feature list, task division (§17), distribution link or APK/AAB location, and known limitations (§16).

### 12.10. Troubleshooting
```bash
flutter clean
flutter pub get
flutter run --dart-define=NEWS_API_KEY=YOUR_ACTUAL_API_KEY
```

---

## 13. Security & Performance Checklist (P14)

| Item | Requirement in this project | Status target |
|---|---|---|
| HTTPS only | NewsAPI and Firebase over HTTPS; no cleartext traffic configured | ✅ |
| No secrets in the app | Firebase client config is not secret. **NewsAPI key is embedded via `--dart-define` and is extractable from the APK**; mitigation options in §16 (documented exception) | ⚠️ documented |
| Validation in backend | Firestore Security Rules: ownership + structure checks (§5.3) | ✅ |
| Security Rules | Per-user read/write only; default deny; user doc cannot be deleted | ✅ |
| Obfuscation | Release builds use `--obfuscate --split-debug-info` | ✅ |
| Minimal permissions | Only `INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` | ✅ |
| Secure token storage | Firebase Auth SDK (Keystore/Keychain); no manual tokens, no `shared_preferences` | ✅ |
| `const` widgets | Use `const` constructors wherever possible (`flutter analyze` lints) | ✅ |
| Builders for lists | `ListView.builder` for Riwayat and Quest | ✅ |
| Image cache & size | `CachedNetworkImage` with `memCacheHeight`; monster PNG ≤ 512 px | ✅ |
| Rebuild scope | `context.select`/`Selector` instead of blanket `watch`; change-only `notifyListeners()`; copy-on-change publishing | ✅ |
| Profile mode | Check jank with `flutter run --profile` + DevTools Performance (not in debug) | ✅ |
| Security review (forum) | Report one fix made (e.g. rules tightened, permission removed, key handling) | task |

---

## 14. AI Prompting Instructions for Teammates (Vibecoding Template)

Paste into your AI assistant (Cursor, Copilot, ChatGPT, Claude, Gemini) and attach this PRD:

```text
Context & Rules:
- Project: FinQuest (Flutter, Firebase Auth + Cloud Firestore, ChangeNotifier + provider, offline-first, college final project).
- Strictly obey PRD.md v5.2: models (section 4), Firestore schema (5.2), GameStore & widget contracts (section 7), game rules (section 8).
- STATE MANAGEMENT: Use `provider` with the single `GameStore extends ChangeNotifier` (`lib/state/game_store.dart`) as defined in PRD section 7. FORBIDDEN: Bloc, Riverpod, GetX, or creating extra ChangeNotifiers. In widgets, read state with `context.select<GameStore, T>(...)` (or `Selector`) inside `build()` and use `context.read<GameStore>()` inside button/form callbacks. Local UI state (TextEditingController, _isSubmitting, tab index, timers) stays in StatefulWidget + setState.
- GAMESTORE RULES: inject `GameRepository`, `NotificationService`, `AuthService` through the constructor; guard `notifyListeners()` and async callbacks with `_disposed`; publish new copies of models/collections on change (never mutate published objects); call `notifyListeners()` only when data actually changed; create the default user document only when a `GameStateEvent` has `state == null && isFromCache == false`.
- BOUNDARIES: Only `lib/services/*` may import `firebase_*`, `cloud_firestore`, `flutter_local_notifications`, `timezone`, or `http`. Auth screens may call `AuthService`. ONLY `GameStore` calls `GameRepository` and `NotificationService`. Child screens never touch Firebase or repositories directly.
- NEVER await a Firestore write in the UI path (offline it never completes). Inside `GameStore`: compute -> mutate fields -> `notifyListeners()` -> `_save()` without await -> snapshot listener reconciles.
- All game math lives in `lib/core/constants/game_rules.dart`. Only the newly exceeded part of a daily limit is penalized (`GameRules.newOverage`). Edit/delete of a transaction never recalculates battle effects.
- Never store tokens manually; Firebase Auth handles the session.
- Allowed packages: `flutter`, `provider`, `http`, `intl`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `flutter_local_notifications`, `timezone`, `cached_network_image`. Do not hand-write versions of Firebase, `provider`, or notification packages; use `flutter pub add`.
- DO NOT rename/change models, Firestore field names, `GameStore` members, constructor signatures, or folder structure.
- Wrap every screen body in `ResponsiveBody`. Any screen/sheet with a `TextField` must be scrollable (sheets: `isScrollControlled` + `viewInsets` padding). No `ListView` inside `SingleChildScrollView` without `shrinkWrap` + `NeverScrollableScrollPhysics`.
- Every screen needs loading, error, and empty states (PRD 9.10) and Indonesian validation messages (PRD 6.4).
- Use `const` constructors, `ListView.builder`, `CachedNetworkImage`. Keep widgets under ~150 lines (split them).
- Never call `NewsService` inside `build()`; cache the Future in `initState`. Never hardcode the API key (`String.fromEnvironment`).
- Use Material 3 and `ThemeData` colors only (supports light & dark mode; no hardcoded colors in widgets). All Rupiah text uses `formatRupiah()`.
- Check `mounted` / `context.mounted` after every `await`.
- Write code, comments, enum values, Firestore field names in English; ALL UI strings in Indonesian.
- Modify ONLY this file: [INSERT_TARGET_FILE_PATH, e.g., lib/state/game_store.dart]
- If you need something from another file, assume it exists with the signature in the PRD; do not rewrite it.
```

---

## 15. Acceptance Criteria (Definition of Done)

### 15.1. Build, Architecture & Quality
- [ ] `flutter run --dart-define=NEWS_API_KEY=...` runs on an Android emulator **and** a real phone.
- [ ] `flutter analyze` reports 0 errors and 0 warnings; `flutter test` passes (include at least unit tests for `GameRules` pure functions).
- [ ] Layered architecture (P12): UI reads/calls `GameStore` via `provider` (`context.select`/`Selector` in `build`, `context.read` in callbacks); `GameStore` calls `GameRepository`/`NotificationService`; Firebase imports appear only in `lib/services/*`.
- [ ] `GameStore` is constructed with injected `GameRepository`/`NotificationService`/`AuthService`; at least one `flutter test` exercises `recordSaving`, `recordExpense`, `updateTransaction`, and `deleteTransaction` using a fake repository (no Firebase).
- [ ] Widgets use `context.select`/`Selector` for reactive reads; adding a transaction does not rebuild the Quest tab (check with DevTools rebuild counts).
- [ ] `pubspec.yaml` contains only the allowed packages; no `sqflite`/`bloc`/`riverpod`/`shared_preferences`.
- [ ] No NewsAPI key, keystore, `key.properties`, or passwords in the repository (`git grep`/`git ls-files`).
- [ ] Game formulas exist only in `game_rules.dart`.

### 15.2. Authentication (F1)
- [ ] Register creates an account; the user lands in Main; the hero name equals the entered name.
- [ ] Login with wrong password/unknown email shows the correct Indonesian message; invalid email/short password blocked by validation.
- [ ] Closing and reopening the app keeps the session (no login again), **also in airplane mode**.
- [ ] Login/register without internet shows the no-internet message and does not crash.
- [ ] Logout returns to Login, disposes `GameStore`, cancels the reminder, and another account sees only its own data.
- [ ] Firestore rules: a second account cannot read the first account's documents (test in the Rules playground or with two accounts).
- [ ] Right after registration, the Arena shows the name typed in *Nama Pahlawan* (not the email prefix) without restarting the app.
- [ ] Logging out right after a write leaves no *"used after being disposed"* error in the logs.

### 15.3. Firebase data & offline (P14/P15)
- [ ] First login creates the default user document (100/100 HP, default limits, 3 monsters at full HP).
- [ ] Logging, battle, budget changes, and CRUD work in **airplane mode**; after reconnecting, the data appears in the Firestore console.
- [ ] Force-closing and reopening restores everything (monster/hero HP, gold, EXP, level, buff, history, today's spending, limits, current monster).
- [ ] Buttons never freeze while offline (no awaiting of write acknowledgements); the *Menunggu sinkronisasi* chip shows while writes are pending.
- [ ] A write rejected by Security Rules (simulated) shows the error SnackBar and the UI reverts to server state.
- [ ] Description `'; DROP TABLE x; --` is stored and shown literally.
- [ ] An existing user document is never overwritten: a fresh install that starts offline with an empty cache does not create default data, and after reconnecting the real progress loads.
- [ ] Default data is created only for an account whose server-confirmed document is missing.

### 15.4. Battle & Budget (F2, F3)
- [ ] Saving Rp 10.000 with no buff deals 10 damage and restores 2 hero HP (if below max); saving Rp 500 deals 1 and restores 1.
- [ ] Empty/0/non-numeric amount is rejected; letters cannot be typed; double-tapping a button creates only one transaction.
- [ ] Defeating monster 1 shows the victory dialog, next monster at full HP, +50 Gold/+50 EXP; defeating all three shows the end card while the form stays usable.
- [ ] Default limits appear on first launch; Makan Rp 30.000 → no penalty (SnackBar shows remaining Rp 20.000).
- [ ] Then Makan Rp 40.000 → hero −20 HP, monster +10; then Rp 10.000 → hero −10 (only new overage).
- [ ] Exactly the limit → no penalty; Rp 1 over → −1 HP; limits are per category.
- [ ] Live hint and warning in `AttackForm` match the actual HP loss.
- [ ] HP reaches 0 at Level ≥ 2 → dialog, level −1, EXP = `(level−1)*100`, HP full; at Level 1 → EXP reset to 0; one demotion per event.
- [ ] Editing limits persists, updates bars immediately, applies only to later expenses; invalid values show *Minimal Rp 1.000*.
- [ ] After the device date moves forward: today's spending resets and HP regenerates +25 per day (capped); resuming the app after midnight refreshes without restart.

### 15.5. History & CRUD (F4)
- [ ] Riwayat lists transactions newest first (max 100), with loading and empty states; tap opens Detail; back arrow works.
- [ ] Edit changes amount/description/category (category only for expenses); the list, Profile totals, and today's budget bars update immediately via `GameStore`; battle state is unchanged.
- [ ] Delete shows a confirmation; after confirming the item disappears, totals update, and **Urungkan** restores it with the same data.
- [ ] Editing/deleting works offline and syncs later; invalid edit amount shows the inline error.
- [ ] Deleting a transaction from its Detail screen does not throw while the screen closes; **Urungkan** restores it.

### 15.6. Daily Mission (F5)
- [ ] Headlines load via `ListView.builder`; "[Removed]" items hidden; images use `CachedNetworkImage`; articles without image render fine.
- [ ] Reader sheet's claim button is disabled for 10 s with a countdown; a claim gives +50, persists after restart, and works offline in battle (consumed after a real attack).
- [ ] Same article twice → "sudah diklaim"; 4th claim on the same day → daily-limit message; next day quota is available again; buff never exceeds +150.
- [ ] No internet → no-internet message + working **Coba Lagi**; wrong key → 401 message; switching tabs does not refetch.

### 15.7. Notifications & Permission
- [ ] Turning the reminder ON shows the explanation dialog, then the system permission dialog (Android 13+); granted → scheduled; the notification appears at the scheduled time (test by temporarily setting a near time).
- [ ] Denying the permission keeps the switch OFF with the message; the rest of the app works normally.
- [ ] Turning OFF cancels the notification; the reminder is rescheduled after a device reboot.

### 15.8. Layout, Theme & Performance
- [ ] No overflow when the keyboard opens (Login, Register, Arena, Edit, Budget sheet) on 360×640 and landscape.
- [ ] Screens look correct on a phone and a tablet emulator (content centered, max width 600).
- [ ] All colors/fonts/buttons come from `ThemeData` (both light and dark themes work cleanly); tab switching preserves state; tab labels are not truncated.
- [ ] Profile-mode run (`flutter run --profile`) shows no obvious jank in Arena and lists (DevTools check noted in the report).

### 15.9. Formatting
- [ ] Every money value shows like `Rp 10.000`; dates show Indonesian format with no `LocaleDataException`.
- [ ] Financial health label matches §8.7 for all three thresholds and the empty state.

### 15.10. Release (P15)
- [ ] Release build is signed and obfuscated; `version` bumped; applicationId matches Firebase.
- [ ] Release build tested on a real device: normal network, slow network, airplane mode.
- [ ] Distribution evidence prepared (App Distribution link, Play testing link, or APK/AAB) and approved by the lecturer.
- [ ] README contains run steps, structure, task division; demo script covers the full end-to-end flow (§1.3).

---

## 16. Risks, Known Limitations & Open Decisions

**Open decisions to confirm with the lecturer**
* **Backend choice:** Firebase Auth + Firestore is used to satisfy "API/Firebase" and secure session requirements, alongside NewsAPI (REST) for Quest. Confirm this with the lecturer; if a custom REST backend (e.g. Laravel + Sanctum token + `flutter_secure_storage`) is required instead, only §5–§6 change (`GameStore` and all UI screens stay intact!).
* **Store granularity:** one `GameStore` for the whole app is assumed (simple, matches the P12 layering). If the P12 slides show one store/ViewModel per feature and the rubric expects that, split `GameStore` into feature stores that share one repository; UI contracts and Firestore schema stay the same.
* **Distribution path:** Play testing (12 testers × 14 days) vs Firebase App Distribution/APK. Start the Play process by early December if Play is mandatory.
* **`go_router`** and the exact `data/` + `ui/` folder names are recommendations in the slides, not mandatory; confirm.

**Security & product risks**
* **NewsAPI key in the app:** the P14 checklist says "no secrets in the app", but a key passed via `--dart-define` can be extracted from the APK. Options: (a) accept and document it as the reported security finding, with an alternative keyless news source; (b) a small proxy (e.g. Firebase Cloud Function, which requires a billing-enabled plan) that holds the key server-side. NewsAPI's free plan is also development-use only and limited to 100 requests/day.
* **Client-computed game logic:** a modified client could write arbitrary HP/gold; Security Rules validate ownership and structure only. Acceptable for this assignment.
* **Users can raise their own limits** to dodge penalties (self-discipline app). Optional rule: increases take effect the next day.
* **Edit/delete does not roll back battle effects** (by design, to keep the game consistent).

**Technical limitations**
* One active device per account (last write wins); cached data of a previous account remains in the device cache after logout.
* Daily quota, budget days, and HP regeneration depend on the device clock.
* Reminder time zone fixed to WIB; exact alarms not used.
* `country=us` news (English); the article list requires internet.
* No in-app account deletion or password reset in the MVP (needed for Play publication; password reset is a P2 item).
* Firestore Spark-plan quotas are ample for a class project but finite.

**Balance risks (tune in `game_rules.dart` after playtesting):** 1 HP per Rp 1.000 of overage may be harsh; level-down discards progress inside the level; regeneration +25/day may feel too weak or too strong.

---

## 17. Build Order, Timeline & Team Division

Deadline: mid-to-late December. Keep the last 1–2 weeks as buffer for testing, release, and the report.

| Week | Scope | Slide milestone |
|---|---|---|
| 1 | Firebase project, `flutter create`, `flutterfire configure`, theme (`light` + `dark`), `ResponsiveBody`, models, `game_rules.dart`, formatters, validators; navigable screens with sample state | **P13 deliverable** (UI + wireframes + task division) |
| 2 | `AuthService`, `AuthGate`, Login/Register, error mapping | P14 |
| 3 | `GameRepository` (watch/save), `GameStore` (`ChangeNotifier`) + startup flow, `MainNavigationScreen`, Arena core (saving, hero HP) | P14 |
| 4 | Budget Survival: category input, overage, HP loss, level-down, Profile budgets, rollover/regen | P14 |
| 5 | History + Detail + Edit + Delete/Undo; Security Rules + `firestore.rules` | P14 |
| 6 | Quest (NewsAPI, reader sheet, claims), notifications + permission flow | P14 |
| 7 | Responsive/performance pass, unit tests (`game_rules_test.dart`), security checklist, full acceptance run (§15), offline tests | P15 |
| 8 | Signed obfuscated build, distribution, README, report, demo rehearsal, buffer | **P15 deliverable** |

**Cut list if time runs short (in order):** `NavigationRail`/tablet extras → sync chip → app-resume refresh → live budget hint → undo-delete → reader-sheet countdown → regeneration (replace with full heal on date change). **Never cut:** auth, `GameStore` (`provider`), Firestore persistence, CRUD, budget/HP core, notification demo, release evidence.

**Task division (fill in names; one Git branch per feature):**

| Feature / area | Main files | Owner | Branch |
|---|---|---|---|
| Foundation (theme, models, rules, utils) | `core/*`, `models/*`, `widgets/*` | _TBD_ | `feat/foundation` |
| F1 Auth | `services/auth_service.dart`, `screens/auth/*` | _TBD_ | `feat/auth` |
| Data layer + Store + Shell | `services/game_repository.dart`, `state/game_store.dart`, `main_navigation_screen.dart` | _TBD_ | `feat/data-store` |
| F2 Arena + F3 Budget | `screens/arena/*`, `screens/profile/*` | _TBD_ | `feat/arena-budget` |
| F4 History & CRUD | `screens/history/*` | _TBD_ | `feat/history-crud` |
| F5 Quest + Notifications | `screens/quest/*`, `services/news_service.dart`, `services/notification_service.dart` | _TBD_ | `feat/quest-notif` |
| Release, Tests, README, report | `android/*`, `test/*`, `README.md` | _TBD_ | `feat/release` |

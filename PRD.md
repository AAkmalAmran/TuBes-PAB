# Product Requirement Document (PRD) — v3.0 (Offline-First)

## FinQuest: Pahlawan Finansial (Mobile Application)

> **Revision summary (v2.0 → v3.0):** the app is now designed as a **real, usable, offline-first application**. Finance records and game progress are persisted in a local SQLite database (`sqflite` + `path`). Internet is required **only** for the Daily Mission (reading news articles). Changes: guardrails #2/#4 relaxed for `sqflite` + `path` (§2), new persistence layer (§5), async callbacks and crash-safe write-through (§6), real daily mission with persistent claims, daily quota and reading gate (§7.5, §8.5), profile totals via SQL aggregates, and new acceptance tests for persistence and offline behavior (§12). Data models in §4 remain **unchanged**.

---

## 1. Project Overview

* **Application Name:** FinQuest: Pahlawan Finansial
* **Platform:** Flutter (Target: Android & iOS)
* **Category:** Gamified Personal Finance & Financial Literacy
* **Objective:** Help university students and young adults manage expenses and build consistent saving habits through an RPG battle simulation against spendthrift habits ("Monster Boros"). Daily financial-news reading quests give attack buffs.
* **Offline-first principle:** logging savings/expenses, fighting monsters, and viewing the profile MUST work with **zero internet connectivity**. Only the **Quest** tab needs the network (to fetch articles). A network failure must never block or crash any other feature.
* **Persistence:** all user data survives app restarts and phone reboots (local SQLite).
* **Academic Context:** Mobile Programming Final Term Project (Tugas Besar). Assessment focuses on widget architecture, overflow-resilient layouts, asynchronous REST API consumption, local database usage, and Material 3.
* **Out of Scope (this version):** user accounts, cloud sync/backup, edit or delete of transactions, push notifications, web/desktop targets (`sqflite` supports Android/iOS only), multi-language switching.

---

## 2. Strict Guardrails & Constraints for AI Coding Assistants

> ⚠️ **CRITICAL DIRECTIVES FOR AI ASSISTANTS & VIBECODERS:**
>
> 1. **NO Third-Party State Management**
>    * **FORBIDDEN:** `bloc`, `flutter_bloc`, `provider`, `riverpod`, `get`, `mobx`.
>    * **REQUIRED:** vanilla Flutter only: `StatefulWidget` + `setState()` and constructor callbacks. Shared state is owned by `MainNavigationScreen` (§6).
>    * Also FORBIDDEN as shared-state mechanisms: `InheritedWidget`, `ChangeNotifier`, `ValueNotifier`, global mutable variables.
>
> 2. **Local Persistence: SQLite ONLY**
>    * **ALLOWED:** `sqflite` and `path`.
>    * **FORBIDDEN:** `hive`, `isar`, `drift`, `objectbox`, `sembast`, `shared_preferences`, `firebase_*`, `supabase_*`, or any other storage mechanism (including writing JSON/text files by hand).
>    * Only `lib/services/database_helper.dart` may import `sqflite`/`path`. Only `MainNavigationScreen` may call `DatabaseHelper`. Screens and widgets NEVER touch the database directly.
>    * `DatabaseHelper` may be a singleton (it is a connection holder, not shared game state).
>
> 3. **Strict Directory Adherence**
>    * Do NOT create files or directories outside the tree in §3.
>    * **Allowed exceptions (generated/platform files):** `android/`, `ios/`, `test/`, `.gitignore`, and editing `android/app/src/main/AndroidManifest.xml` (INTERNET permission only, §10).
>    * Never commit the generated `.db` file.
>
> 4. **Locked Dependencies**
>    * Only `flutter`, `http`, `intl`, `sqflite`, `path`. No extra packages without explicit request.
>    * SDK libraries (`dart:io`, `dart:async`, `dart:convert`, `package:flutter/services.dart`) are allowed.
>
> 5. **Zero Layout Overflow Policy**
>    * Any screen containing a `TextField` **MUST** be wrapped in a `SingleChildScrollView` (or other scrollable).
>    * Never place a `ListView`/`GridView` inside a `SingleChildScrollView` without `shrinkWrap: true` + `NeverScrollableScrollPhysics()` (or use a plain `Column`).
>    * Never place a scrollable inside a `Column` without `Expanded`/`SizedBox` bounds.
>
> 6. **Localization / UI Text Language**
>    * Code, comments, models, variable names, **and database table/column names** MUST be in English.
>    * User-facing UI labels, monster names, dialogs, SnackBars, and error messages MUST be in Indonesian (e.g. *"Monster Kopi Susu Mahal"*, *"Catat Tabungan"*, *"Rp "*).
>
> 7. **Do Not Change Contracts**
>    * Do NOT rename or alter models (§4), the database schema (§5.1), constructor signatures (§6.3), or constants (§7). If a change is needed, update this PRD first and notify the team.
>
> 8. **Secrets**
>    * NEVER commit a real API key. Use `--dart-define` (§10).
>
> 9. **Offline-First Rule**
>    * Only `QuestScreen` and `NewsService` may use the network. The app MUST start and be fully playable in airplane mode. Never `await` a network call during startup.
>
> 10. **Data Integrity Rule**
>     * Every change that touches more than one table MUST run inside a single `db.transaction(...)`.
>     * **Write-through order:** compute new values → `await` the database write → only then `setState()` to update memory. If the database write throws, memory and UI stay unchanged and a SnackBar *"Gagal menyimpan data. Coba lagi."* is shown.

### Official Dependencies (`pubspec.yaml`)

```yaml
name: finquest
description: "Gamified Personal Finance Application"
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0     # Local offline SQLite database
  path: ^1.9.0        # Builds the local database file path
  http: ^1.2.0        # REST API calls to NewsAPI (Quest only)
  intl: ^0.19.0       # Indonesian Rupiah currency and date formatting

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0   # If it conflicts with the team's Flutter SDK, use the version generated by `flutter create`

flutter:
  uses-material-design: true
  assets:
    - assets/images/
```

> If `flutter pub get` reports a version conflict (e.g. on `path`), use `flutter pub add sqflite path` to let Flutter pick compatible versions, then update this PRD.

---

## 3. Project Architecture & Directory Tree

```text
finquest/
├── android/                         # generated by `flutter create .`
├── ios/                             # generated by `flutter create .`
├── assets/
│   └── images/                      # PNG files MUST be committed to Git
│       ├── monster_kopi.png
│       ├── monster_belanja.png
│       └── monster_ongkir.png
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/
│   │   │   ├── api_endpoints.dart
│   │   │   ├── app_colors.dart
│   │   │   └── game_rules.dart
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── utils/
│   │       └── formatters.dart
│   ├── models/
│   │   ├── monster.dart
│   │   ├── character.dart
│   │   ├── transaction_record.dart
│   │   ├── article.dart
│   │   └── game_results.dart        # NEW: SavingResult, ArticleClaimResult
│   ├── services/
│   │   ├── database_helper.dart     # NEW: all SQLite access
│   │   └── news_service.dart
│   ├── screens/
│   │   ├── main_navigation_screen.dart
│   │   ├── arena/
│   │   │   ├── arena_screen.dart
│   │   │   └── widgets/
│   │   │       ├── monster_display.dart
│   │   │       └── attack_form.dart
│   │   ├── quest/
│   │   │   ├── quest_screen.dart
│   │   │   └── widgets/
│   │   │       ├── news_card.dart
│   │   │       └── article_reader_sheet.dart   # NEW: reading gate
│   │   └── profile/
│   │       └── profile_screen.dart
│   └── widgets/
│       └── hp_bar.dart
├── test/                            # optional, generated
└── pubspec.yaml
```

---

## 4. Data Contract & Model Definitions (UNCHANGED)

> Models stay plain Dart classes. **No `toMap`/`fromMap` inside models**: the mapping between models and database rows lives in `database_helper.dart` (§5.2).

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
class Character {
  final String name;
  int gold;
  int exp;
  int level;
  int attackBuff; // Damage modifier granted when reading news articles

  Character({
    required this.name,
    this.gold = 0,
    this.exp = 0,
    this.level = 1,
    this.attackBuff = 0,
  });
}
```

### 4.3. `lib/models/transaction_record.dart`

```dart
enum TransactionType { expense, saving }

class TransactionRecord {
  final String id;
  final String description;
  final double amount;
  final TransactionType type;
  final DateTime date;

  TransactionRecord({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
  });
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

### 4.5. `lib/models/game_results.dart` (NEW)

Result objects returned by parent callbacks so child screens can show the right feedback without touching shared state.

```dart
class SavingResult {
  final int damage;                    // total damage dealt (base + buff)
  final bool leveledUp;
  final int newLevel;
  final String? defeatedMonsterName;   // non-null if this attack defeated the monster
  final bool adventureCompleted;       // true if the defeated monster was the last one

  SavingResult({
    required this.damage,
    required this.leveledUp,
    required this.newLevel,
    this.defeatedMonsterName,
    this.adventureCompleted = false,
  });
}

enum ArticleClaimResult { granted, alreadyClaimed, dailyLimitReached, buffAtMax }
```

---

## 5. Persistence Layer (NEW)

### 5.1. Database schema (`finquest.db`, version 1)

All identifiers in English. Booleans are stored as `INTEGER` (0/1), dates as ISO-8601 `TEXT`.

```sql
CREATE TABLE character (
  id          INTEGER PRIMARY KEY CHECK (id = 1),   -- single row
  name        TEXT    NOT NULL,
  gold        INTEGER NOT NULL DEFAULT 0,
  exp         INTEGER NOT NULL DEFAULT 0,
  level       INTEGER NOT NULL DEFAULT 1,
  attack_buff INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE monsters (
  id                TEXT    PRIMARY KEY,              -- 'kopi' | 'belanja' | 'ongkir'
  name              TEXT    NOT NULL,
  max_hp            INTEGER NOT NULL,
  current_hp        INTEGER NOT NULL,
  asset_image_path  TEXT    NOT NULL,
  sort_order        INTEGER NOT NULL                  -- 0, 1, 2
);

CREATE TABLE game_state (
  id                      INTEGER PRIMARY KEY CHECK (id = 1),   -- single row
  current_monster_index   INTEGER NOT NULL DEFAULT 0,
  is_adventure_complete   INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE transactions (
  id           TEXT PRIMARY KEY,
  description  TEXT NOT NULL,
  amount       REAL NOT NULL,
  type         TEXT NOT NULL CHECK (type IN ('expense', 'saving')),
  date         TEXT NOT NULL                          -- ISO-8601
);
CREATE INDEX idx_transactions_date ON transactions (date DESC);

CREATE TABLE claimed_articles (
  url            TEXT PRIMARY KEY,                    -- an article can be claimed only once, ever
  claimed_date   TEXT NOT NULL                        -- local day 'yyyy-MM-dd', used for the daily quota
);
```

**Seeding (`onCreate`):** insert the character row (`name: 'Pahlawan Hemat'`, all zeros, level 1), the three monsters from `DatabaseHelper.defaultMonsters()` (§6.2), and `game_state` (`0`, `0`).

**Migrations:** `version: 1` with an `onUpgrade` stub. Any future schema change bumps the version and adds an `ALTER TABLE` step; never delete user data on upgrade.

> Note: v3.0 has no "category" column. `TransactionRecord` (locked in §4.3) has no category; adding one requires a PRD change to the model first.

### 5.2. `lib/services/database_helper.dart`

Responsibilities: open/create the DB, map rows ↔ models, and expose exactly these methods:

```dart
class GameSnapshot {
  final Character character;
  final List<Monster> monsters;               // ordered by sort_order
  final int currentMonsterIndex;
  final bool isAdventureComplete;
  final List<TransactionRecord> recentTransactions; // newest first, LIMIT 100
  final double totalSaving;                    // SQL SUM over ALL saving rows
  final double totalExpense;                   // SQL SUM over ALL expense rows
  final Map<String, String> claimedArticles;   // url -> claimed_date
  // constructor with all fields required
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  DatabaseHelper._();

  static List<Monster> defaultMonsters();                     // fresh monsters at full HP (table in §6.2)

  Future<GameSnapshot> loadSnapshot();

  // One transaction: update character row, update the given monster row,
  // update game_state, and insert [record].
  Future<void> persistTurn({
    required Character character,
    required Monster monster,
    required int currentMonsterIndex,
    required bool isAdventureComplete,
    required TransactionRecord record,
  });

  // One transaction: insert into claimed_articles and update character.attack_buff.
  Future<void> persistArticleClaim({
    required String url,
    required String claimedDate,
    required Character character,
  });

  // One transaction: reset all monsters to max_hp, reset game_state.
  // Character, transactions and claimed_articles are kept.
  Future<void> restartAdventure();
}
```

Implementation requirements:

* Open once and cache the `Future<Database>` (guard against concurrent opens): `join(await getDatabasesPath(), 'finquest.db')`.
* Use parameterized `db.insert/update/query` (or `?` placeholders). Never build SQL by string interpolation of user input (description text).
* `TransactionRecord.type` is stored as `type.name` and parsed with `TransactionType.values.byName`.
* Totals: `SELECT type, SUM(amount) AS total FROM transactions GROUP BY type`; missing type → `0`.
* Recent list: `ORDER BY date DESC LIMIT 100`.

### 5.3. Startup flow

1. `main()` → `WidgetsFlutterBinding.ensureInitialized()` → `await initializeDateFormatting('id_ID')` → `runApp`. No network calls.
2. `MainNavigationScreen.initState()` calls `_loadSnapshot()` (`DatabaseHelper.instance.loadSnapshot()`), starting with `_isLoading = true`.
3. While loading: `Scaffold` with centered `CircularProgressIndicator`.
4. On failure: centered message *"Gagal memuat data. Coba lagi."* + **"Coba Lagi"** button that re-runs `_loadSnapshot()`.
5. On success: fill the in-memory state (§6.2) and show the `NavigationBar` + `IndexedStack`.

---

## 6. State Ownership & Constructor Contracts

### 6.1. Principle

SQLite is the **source of truth**. `MainNavigationScreen` holds an **in-memory copy** (loaded at startup) and keeps it in sync through the write-through rule (guardrail #10). Child screens receive data via constructors and request changes via **async callbacks**; they never mutate shared objects and never call the database.

### 6.2. State owned by `_MainNavigationScreenState`

```dart
bool _isLoading = true;
bool _hasLoadError = false;
int _currentIndex = 0;

late Character _character;
late List<Monster> _monsters;
late int _monsterIndex;
late bool _isAdventureComplete;
late List<TransactionRecord> _recentTransactions; // newest first, max 100
late double _totalSaving;
late double _totalExpense;
late Map<String, String> _claimedArticles;        // url -> 'yyyy-MM-dd'
```

`DatabaseHelper.defaultMonsters()` (used for seeding and restart), in this fixed order:

| # | id | name (UI) | maxHp | asset |
|---|---|---|---|---|
| 1 | `kopi` | Monster Kopi Susu Mahal | 300 | `assets/images/monster_kopi.png` |
| 2 | `belanja` | Monster Belanja Impulsif | 800 | `assets/images/monster_belanja.png` |
| 3 | `ongkir` | Monster Ongkir Makanan | 1500 | `assets/images/monster_ongkir.png` |

`currentHp` starts equal to `maxHp`.

### 6.3. Constructor signatures (MUST be followed exactly)

```dart
// lib/screens/arena/arena_screen.dart  (StatelessWidget)
ArenaScreen({
  required Character character,
  required Monster monster,                  // current monster
  required bool isAdventureComplete,
  required Future<SavingResult?> Function(double amount, String description) onSaving,   // null = DB error
  required Future<int?> Function(double amount, String description) onExpense,           // HP healed, null = DB error
  required Future<void> Function() onRestartAdventure,
})

// lib/screens/arena/widgets/monster_display.dart  (StatelessWidget)
MonsterDisplay({ required Monster monster })

// lib/screens/arena/widgets/attack_form.dart  (StatefulWidget, owns TextEditingControllers)
AttackForm({
  required Future<void> Function(double amount, String description) onSaving,
  required Future<void> Function(double amount, String description) onExpense,
})

// lib/screens/quest/quest_screen.dart  (StatefulWidget, owns the cached Future)
QuestScreen({
  required Character character,
  required Set<String> claimedArticleUrls,
  required int claimsToday,                                   // claims made on the current local day
  required Future<ArticleClaimResult> Function(Article article) onArticleRead,
})

// lib/screens/quest/widgets/news_card.dart  (StatelessWidget)
NewsCard({ required Article article, required bool isClaimed, required VoidCallback onTap })

// lib/screens/quest/widgets/article_reader_sheet.dart  (StatefulWidget, owns the countdown Timer)
ArticleReaderSheet({
  required Article article,
  required bool isClaimed,
  required VoidCallback onClaim,
})

// lib/screens/profile/profile_screen.dart  (StatelessWidget)
ProfileScreen({
  required Character character,
  required List<TransactionRecord> recentTransactions,   // latest 100
  required double totalSaving,
  required double totalExpense,
})

// lib/widgets/hp_bar.dart  (StatelessWidget)
HpBar({ required int currentHp, required int maxHp })
```

Because `AttackForm` and the Arena callbacks are asynchronous, `AttackForm` MUST keep a `_isSubmitting` flag: both buttons are disabled while a callback is pending (prevents double-tap duplicates). After every `await`, check `mounted`/`context.mounted` before using `context`.

### 6.4. Parent callback logic (owned by `MainNavigationScreen`)

All callbacks follow: **compute on local copies → `await` DB → `if (!mounted) return` → `setState` to apply**. Wrap the DB call in `try/catch`; on error show the *"Gagal menyimpan data. Coba lagi."* SnackBar and return `null`.

* **`onSaving(amount, description)`**
  1. If `_isAdventureComplete`, do nothing and return `null`.
  2. Compute per §7.2: damage, new HP, gold, exp, level. If new HP is 0 → also apply victory bonus (§7.4) to gold/exp, recompute level, and decide the next state: `_monsterIndex + 1` if not last, otherwise `isAdventureComplete = true` (index stays at the last monster).
  3. Build `TransactionRecord(id: DateTime.now().microsecondsSinceEpoch.toString(), description, amount, type: saving, date: DateTime.now())`.
  4. `await DatabaseHelper.instance.persistTurn(...)`.
  5. `setState`: apply values to `_character` and the monster, set index/complete flag, `_recentTransactions.insert(0, record)` (trim to 100), `_totalSaving += amount`.
  6. Return `SavingResult` (with `defeatedMonsterName` and `adventureCompleted` when applicable).
* **`onExpense(amount, description)`**: same pattern with §7.3 (monster heals, character unchanged), `_totalExpense += amount`; returns HP healed. Ignored if `_isAdventureComplete`.
* **`onRestartAdventure()`**: `await restartAdventure()`, then `setState`: `_monsters = DatabaseHelper.defaultMonsters()`, `_monsterIndex = 0`, `_isAdventureComplete = false`.
* **`onArticleRead(article)`**, evaluated in this exact order:
  1. `today = DateFormat('yyyy-MM-dd').format(DateTime.now())`.
  2. URL already in `_claimedArticles` → `alreadyClaimed`.
  3. Claims with `claimed_date == today` ≥ `GameRules.dailyArticleQuota` → `dailyLimitReached`.
  4. `attackBuff >= GameRules.maxAttackBuff` → `buffAtMax`.
  5. Otherwise: `await persistArticleClaim(...)` (new buff = old + `articleBuff`), then `setState` (update buff, add to `_claimedArticles`) → `granted`.
* When building `QuestScreen`, pass `claimsToday` computed from `_claimedArticles` for today's date, and `claimedArticleUrls: _claimedArticles.keys.toSet()`.

---

## 7. Game Rules

All numbers live in `lib/core/constants/game_rules.dart` and MUST NOT be hardcoded elsewhere.

```dart
class GameRules {
  static const int rupiahPerDamage = 1000;   // Rp 1.000 saved = 1 damage
  static const int rupiahPerGold = 1000;     // Rp 1.000 saved = 1 gold
  static const int baseExpPerSaving = 10;    // flat EXP per saving record
  static const int rupiahPerBonusExp = 5000; // +1 EXP per Rp 5.000 saved
  static const int rupiahPerHeal = 2000;     // Rp 2.000 spent = 1 HP healed on monster
  static const int victoryGold = 50;
  static const int victoryExp = 50;
  static const int expPerLevel = 100;        // level = 1 + exp ~/ 100
  static const int articleBuff = 50;         // buff per newly claimed article
  static const int maxAttackBuff = 150;      // cap on stored buff
  static const int dailyArticleQuota = 3;    // max claims per local day
  static const int readSeconds = 10;         // reading gate before a claim is allowed
  static const int historyLimit = 100;       // transactions kept in memory / shown in Profile
}
```

### 7.1. Monsters
HP: Kopi Susu Mahal **300**, Belanja Impulsif **800**, Ongkir Makanan **1500**. Fixed order. `currentHp` is clamped to `0..maxHp`.

### 7.2. Saving ("Catat Tabungan"): player attacks
```
baseDamage = max(1, amount ~/ rupiahPerDamage)
damage     = baseDamage + character.attackBuff
newHp      = max(0, monster.currentHp - damage)
attackBuff = 0                                  // buff is consumed by this attack
gold      += amount ~/ rupiahPerGold
exp       += baseExpPerSaving + amount ~/ rupiahPerBonusExp
level      = 1 + exp ~/ expPerLevel
```
Feedback: SnackBar *"Serangan berhasil! Monster menerima {damage} damage."* plus, if leveled up, *"Naik level! Sekarang Level {level}."*

### 7.3. Expense ("Catat Pengeluaran"): monster counter-attacks
The hero has no HP; the counter-attack is the monster **healing**:
```
heal = max(1, amount ~/ rupiahPerHeal)
monster.currentHp = min(monster.maxHp, monster.currentHp + heal)
```
Gold, EXP, and buff are unchanged. Feedback: SnackBar *"Monster menyerang balik! HP monster pulih +{heal}."*

### 7.4. Victory & end of game
* Victory rewards (`victoryGold`, `victoryExp`) are applied **atomically in the same DB transaction** as the finishing blow (§6.4), so progress can never be lost if the app is closed while the dialog is showing.
* The Arena shows a victory dialog (`showDialog`, `barrierDismissible: false`) using `SavingResult.defeatedMonsterName`: *"Kamu mengalahkan {name}! Hadiah: +50 Gold, +50 EXP"*, button *"Lanjut"*. The monster display already shows the next monster after the dialog closes.
* After the last monster: the Arena shows the end-state card *"Semua Monster Boros Telah Dikalahkan!"* with **"Mulai Petualangan Baru"** → `onRestartAdventure()`. The attack form is hidden in this state.

### 7.5. Daily Mission (news)
* **Goal:** read up to **3 different articles per local day** (`dailyArticleQuota`). Each claimed article gives **+50** attack buff.
* An article (identified by `url`) can be claimed **only once, ever** (primary key in `claimed_articles`).
* Buff is stored in SQLite (`attack_buff`), stacks up to **+150**, persists across restarts, and is consumed by the next saving attack, so it works **offline**.
* The daily quota resets when the local calendar date changes. (Changing the phone clock can bypass this; accepted limitation, §13.)
* **Reading gate:** tapping an article opens `ArticleReaderSheet` showing title, source, date, and description. The **"Klaim Buff"** button is disabled for `readSeconds` (10 s) with a visible countdown (*"Baca dulu… 7 detik"*), then enabled. This is a lightweight proof-of-reading; true verification is not possible without a browser/WebView package.
* Feedback messages:

| Result | SnackBar (Indonesian) |
|---|---|
| `granted` | Misi harian tercapai! Kamu mendapatkan Buff Serangan +50! |
| `alreadyClaimed` | Artikel ini sudah kamu klaim. Cari artikel lain! |
| `dailyLimitReached` | Misi harian hari ini sudah selesai (3/3). Kembali lagi besok! |
| `buffAtMax` | Buff Serangan sudah maksimal (+150). Gunakan dulu untuk menyerang! |

### 7.6. Financial health status (Profile)
```
total = totalSaving + totalExpense
ratio = totalSaving / total
```

| Condition | Label (UI) |
|---|---|
| no transactions (`total == 0`) | Belum ada data |
| ratio ≥ 0.70 | Sehat 💚 |
| 0.40 ≤ ratio < 0.70 | Waspada 💛 |
| ratio < 0.40 | Boros ❤️ |

Totals come from the SQL aggregates (all-time), not from the 100-item history list.

---

## 8. Screen Specifications & Functional Requirements

### 8.1. Entry Point & Theme
* `main.dart`: as in §5.3 step 1. `MaterialApp(title: 'FinQuest', theme: AppTheme.light, debugShowCheckedModeBanner: false, home: MainNavigationScreen())`.
* `AppTheme.light`: `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary))`.
* `AppColors`: static `Color` constants only.

### 8.2. Formatters (`lib/core/utils/formatters.dart`)
```dart
String formatRupiah(num value);        // NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
String formatDate(String isoString);   // DateTime.tryParse -> .toLocal() -> DateFormat('d MMM yyyy, HH:mm', 'id_ID'); fallback '-'
String formatDateTime(DateTime date);  // same pattern, for transaction history
String todayKey();                     // DateFormat('yyyy-MM-dd').format(DateTime.now())
```
All Rupiah figures MUST go through `formatRupiah` (e.g. `Rp 10.000`, never `10000.0`).

### 8.3. Root Navigation (`main_navigation_screen.dart`)
* Material 3 `NavigationBar` (NOT `BottomNavigationBar`).

| Index | Label | Icon (fixed) |
|---|---|---|
| 0 | Arena | `Icons.shield` |
| 1 | Quest | `Icons.newspaper` |
| 2 | Profil | `Icons.person` |

* Body: loading/error states (§5.3), then `IndexedStack(index: _currentIndex, children: [ArenaScreen, QuestScreen, ProfileScreen])` to preserve state across tabs. The Quest future is therefore fetched once per session unless the user taps retry.
* Owns all shared state and callbacks (§6).

### 8.4. Battle Arena (`arena_screen.dart`)
* Body wrapped in `SingleChildScrollView` with padding.
* Layout: active-buff chip (*"Buff Serangan: +{attackBuff}"*, only if > 0), `MonsterDisplay`, `AttackForm` (or the end-state card, §7.4).
* **`MonsterDisplay`:** `Image.asset(..., height: 180, errorBuilder: ...)` with an icon placeholder on error; name as title; `Text('HP: ${monster.currentHp} / ${monster.maxHp}')`; `HpBar`.
* **`HpBar`:** `TweenAnimationBuilder<double>` (400 ms) feeding a `LinearProgressIndicator(value:, minHeight: 14)` with rounded corners; green > 50 %, orange 25–50 %, red < 25 %.
* **`AttackForm`:**
  * Amount `TextField`: `keyboardType: TextInputType.number`, `inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)]`, `InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.monetization_on), labelText: 'Nominal Transaksi')`.
  * Description `TextField` (label *"Deskripsi (opsional)"*; fallback *"Tabungan"* / *"Pengeluaran"* when empty).
  * Buttons **"Catat Tabungan"** (`FilledButton`) and **"Catat Pengeluaran"** (`OutlinedButton`), disabled while `_isSubmitting`.
  * Validation: empty or `<= 0` → inline `errorText` *"Masukkan nominal lebih dari 0"*; callbacks not called.
  * On success: clear controllers, `FocusScope.of(context).unfocus()`. Dispose controllers in `dispose()`.
* **Flow after saving:** `await onSaving` → if `null`, stop (parent already showed the error) → SnackBar (§7.2) → if `defeatedMonsterName != null`, show the victory dialog.
* **Flow after expense:** `await onExpense` → SnackBar (§7.3).
* The Arena works fully offline.

### 8.5. Quest & News Screen (`quest_screen.dart`): the only online screen
* `StatefulWidget` holding `late Future<List<Article>> _articlesFuture;` assigned in `initState()` (and re-assigned on retry/refresh). **Never call the service in `build()`** (NewsAPI free quota is 100 requests/day).
* **Mission header (works offline, built from props):** *"Misi Harian: {claimsToday}/3 artikel"*, a progress indicator, and current buff *"Buff Serangan: +{attackBuff}"*. A short note: *"Baca berita keuangan untuk mendapat Buff Serangan. Arena dan Profil tetap bisa dipakai tanpa internet."*
* `FutureBuilder<List<Article>>`:
  * `waiting` → centered `CircularProgressIndicator()`.
  * `hasError` → centered icon, Indonesian message (§9.3), and **"Coba Lagi"** button (`setState(() => _articlesFuture = NewsService().fetchFinancialNews())`).
  * Empty list → *"Belum ada berita saat ini."* + retry.
  * Data → `ListView.builder` of `NewsCard`, optionally inside `RefreshIndicator`.
* **`NewsCard`:** Material `Card`; thumbnail via `Image.network` only if `urlToImage != null` (with `errorBuilder`/`loadingBuilder` fallbacks); title (max 3 lines); source; date via `formatDate`; *"Sudah diklaim"* badge and dimmed style if `isClaimed`.
* **Tap handling:** tap → `showModalBottomSheet` with `ArticleReaderSheet`. When the user presses **"Klaim Buff"**: close the sheet, `await onArticleRead(article)`, hide any current SnackBar, then show the message for the returned `ArticleClaimResult` (§7.5).
* **`ArticleReaderSheet`:** scrollable content (title, source, date, description, and `SelectableText(article.url)` so the user can copy the full-article link). If `isClaimed`, the button is disabled with label *"Sudah Diklaim"*. Otherwise the countdown (`Timer.periodic`, cancelled in `dispose()`) runs from `readSeconds` to 0, then the button becomes enabled.
* Articles are not opened in an external browser (no `url_launcher`; locked dependencies). See §13 open decisions.

### 8.6. Profile & Summary Screen (`profile_screen.dart`)
* Body: `SingleChildScrollView` containing a `Column`.
* **Hero Stats (Card):** name, Level, Total Gold, EXP total plus *"{exp % 100} / 100 EXP menuju level berikutnya"*, Active Buff *"+{attackBuff}"*.
* **Financial Summary (Card):** Total Tabungan, Total Pengeluaran (`formatRupiah`), and the Financial Health label (§7.6).
* **Transaction History:** read-only, newest first, titled *"Riwayat Transaksi (100 terakhir)"*. Build with `Column(children: recentTransactions.map(...).toList())` or a `ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())`. Item: icon (saving = green up-arrow, expense = red down-arrow), description, `formatDateTime`, signed amount (`+Rp 10.000` / `-Rp 10.000`).
* Empty state: *"Belum ada transaksi. Mulai catat di Arena!"*.
* Works fully offline.

---

## 9. Network Service Specification (Quest only)

### 9.1. `lib/core/constants/api_endpoints.dart`
```dart
class ApiEndpoints {
  static const String apiKey = String.fromEnvironment('NEWS_API_KEY');
  static const String financialNewsUrl =
      'https://newsapi.org/v2/top-headlines?category=business&country=us&apiKey=$apiKey';
}
```
* `country=us` is a deliberate choice (the free tier returns little or nothing for `country=id`). Consequence: article text is in English while the UI is Indonesian.
* If `apiKey` is empty, the service throws a `NewsException` without calling the network.

### 9.2. `lib/services/news_service.dart`
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

### 9.3. Error → UI message mapping

| Situation | Message (Indonesian) |
|---|---|
| API key missing | API key belum diatur… |
| HTTP 401 | API key tidak valid… |
| HTTP 429 | Kuota NewsAPI hari ini habis… |
| Other non-200 | Gagal memuat berita (kode X)… |
| `SocketException` | Tidak ada koneksi internet… |
| `TimeoutException` | Koneksi terlalu lama… |
| `FormatException` | Data berita tidak dapat dibaca… |
| Any other exception | Terjadi kesalahan. Coba lagi. |

`QuestScreen` shows `error is NewsException ? error.message : 'Terjadi kesalahan. Coba lagi.'`.

---

## 10. Project Setup & Developer Onboarding

### 10.1. Clone & Navigate
```bash
git clone https://github.com/<your-username>/<repo-name>.git
cd <repo-name>
```

### 10.2. Generate Platform Folders (only if `android/` and `ios/` are missing)
```bash
flutter create . --project-name finquest --platforms=android,ios
```
This must NOT overwrite `lib/main.dart` or `pubspec.yaml` content; restore them from Git if replaced.

### 10.3. Scaffold Missing Directories (if starting clean)
* **macOS / Linux / Git Bash:**
  ```bash
  mkdir -p assets/images lib/core/constants lib/core/theme lib/core/utils lib/models lib/services lib/screens/arena/widgets lib/screens/quest/widgets lib/screens/profile lib/widgets
  ```
* **Windows PowerShell:**
  ```powershell
  New-Item -ItemType Directory -Force -Path assets/images, lib/core/constants, lib/core/theme, lib/core/utils, lib/models, lib/services, lib/screens/arena/widgets, lib/screens/quest/widgets, lib/screens/profile, lib/widgets
  ```

### 10.4. Assets
Commit the three monster PNGs (empty folders are not tracked by Git and a missing asset folder breaks the build). Recommended: ≤ 512×512 px, transparent background.

### 10.5. Android INTERNET Permission (required for release builds)
In `android/app/src/main/AndroidManifest.xml`, inside `<manifest>` and outside `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
iOS needs no extra configuration. `sqflite` needs no permissions.

### 10.6. Install Dependencies
```bash
flutter pub get
```

### 10.7. Configure API Key (never commit it)
```bash
flutter run --dart-define=NEWS_API_KEY=YOUR_ACTUAL_API_KEY
```
VS Code: put `"args": ["--dart-define=NEWS_API_KEY=YOUR_ACTUAL_API_KEY"]` in a **local, uncommitted** `launch.json` (add `.vscode/` to `.gitignore`). Android Studio: *Run → Edit Configurations → Additional run args*. Release build: `flutter build apk --dart-define=NEWS_API_KEY=...`.

### 10.8. Verify & Run
```bash
flutter doctor
flutter devices
flutter analyze
flutter run --dart-define=NEWS_API_KEY=YOUR_ACTUAL_API_KEY
```

### 10.9. Reset Local Data (during development)
Uninstall the app from the device/emulator, or *Settings → Apps → FinQuest → Storage → Clear data*. Do this after any schema change before the schema version is bumped properly.

### 10.10. Troubleshooting
```bash
flutter clean
flutter pub get
flutter run --dart-define=NEWS_API_KEY=YOUR_ACTUAL_API_KEY
```

---

## 11. AI Prompting Instructions for Teammates (Vibecoding Template)

Paste into your AI coding assistant (Cursor, Copilot, ChatGPT, Claude, Gemini) and attach this PRD:

```text
Context & Rules:
- Project: FinQuest (Flutter offline-first mobile app, college final project).
- Strictly obey PRD.md v3.0: models (section 4), SQLite schema (5.1), constructor contracts (6.3), game rules (7).
- FORBIDDEN: external state management (No Bloc, Riverpod, Provider, GetX). Use only StatefulWidget and setState().
- Persistence: ONLY sqflite + path, ONLY inside lib/services/database_helper.dart. FORBIDDEN: Hive, Isar, Drift, SharedPreferences, Firebase, JSON files.
- Only MainNavigationScreen calls DatabaseHelper. Child screens use constructor params and async callbacks exactly as in 6.3. Never mutate shared objects from child screens.
- Write-through order: compute -> await DB (single transaction for multi-table changes) -> setState. On DB error: SnackBar "Gagal menyimpan data. Coba lagi." and leave state unchanged.
- Offline-first: only QuestScreen/NewsService may use the network. Arena and Profile must work in airplane mode. Never await network at startup.
- Allowed packages: flutter, http, intl, sqflite, path. SDK libraries (dart:io, dart:async, flutter/services.dart) are fine.
- DO NOT rename or change model schemas, table/column names, constructor signatures, or folder structure.
- All game numbers come from lib/core/constants/game_rules.dart. All Rupiah text uses formatRupiah().
- Wrap any screen containing a TextField in SingleChildScrollView. Never put a ListView inside a SingleChildScrollView without shrinkWrap + NeverScrollableScrollPhysics.
- Never call NewsService inside build(); cache the Future in initState.
- Never hardcode the API key; use String.fromEnvironment('NEWS_API_KEY').
- Use parameterized SQL only. Use Material 3 (NavigationBar, FilledButton, ColorScheme.fromSeed).
- Check mounted / context.mounted after every await before using context or calling setState.
- Write code, comments, and DB identifiers in English, but keep ALL UI strings in Indonesian.
- Modify ONLY this file: [INSERT_TARGET_FILE_PATH, e.g., lib/services/database_helper.dart]
- If you need something from another file, assume it exists with the signature in the PRD; do not rewrite it.
```

---

## 12. Acceptance Criteria (Definition of Done)

### 12.1. Build & Quality
- [ ] `flutter run --dart-define=NEWS_API_KEY=...` builds and runs on at least one Android device/emulator (iOS if available).
- [ ] `flutter analyze` reports **0 errors and 0 warnings**.
- [ ] `pubspec.yaml` contains only `flutter`, `http`, `intl`, `sqflite`, `path` (plus dev dependencies).
- [ ] `sqflite`/`path` are imported only in `database_helper.dart`; `http` only in `news_service.dart`.
- [ ] No real API key and no `.db` file exist in the repository (`git grep`/`git ls-files` check).
- [ ] No file exists outside the tree in §3 (except allowed exceptions).

### 12.2. Layout & Navigation
- [ ] No overflow banner when the keyboard opens in Arena on a small screen (360×640) and in landscape.
- [ ] Switching tabs preserves state (Arena inputs/HP, Quest scroll position, Profile data).
- [ ] Tab labels are not truncated on a 360 px-wide screen.
- [ ] A loading indicator shows briefly at startup; a DB load failure shows the retry state instead of a crash.

### 12.3. Gameplay
- [ ] Saving Rp 10.000 with no buff deals exactly 10 damage; HP text and `HpBar` update with animation.
- [ ] Saving Rp 500 deals 1 damage (minimum); Gold/EXP/Level follow §7.2.
- [ ] Expense Rp 20.000 heals the monster by 10 HP (never above `maxHp`) and logs a transaction.
- [ ] Empty, `0`, or non-numeric amount is rejected with the inline error; letters cannot be typed.
- [ ] Tapping a button twice quickly creates only **one** transaction (buttons disabled while submitting).
- [ ] Defeating monster 1 shows the victory dialog and the next monster appears at full HP; +50 Gold/+50 EXP are applied.
- [ ] Defeating all three monsters shows the end-state card; "Mulai Petualangan Baru" resets monsters but keeps Gold, EXP, Level, history, and claims.

### 12.4. Persistence & Offline (NEW)
- [ ] After logging transactions, hurting a monster, and claiming a buff, **force-closing and reopening** the app restores all of it exactly (HP, gold, EXP, level, buff, history, current monster).
- [ ] Killing the app **while the victory dialog is open** leaves the rewards applied and the next monster active on relaunch.
- [ ] In **airplane mode from a fresh launch**, Arena and Profile work fully, and logging/attacks persist; Quest shows the no-internet message with a working **"Coba Lagi"** after reconnecting.
- [ ] A buff claimed online is usable in an attack while offline and is consumed (reset to 0) after the attack, also after restart.
- [ ] A simulated DB error (e.g. temporarily throwing in `persistTurn`) shows the error SnackBar and leaves UI state unchanged (no half-applied update).
- [ ] Profile totals match the sum of all records even when there are more than 100 transactions; only the latest 100 are listed.
- [ ] Transaction descriptions containing quotes or SQL characters (e.g. `'; DROP TABLE x; --`) are stored and displayed literally.

### 12.5. Daily Mission & Network
- [ ] Headlines load from NewsAPI and render via `ListView.builder`; "[Removed]" items are hidden.
- [ ] Tapping an article opens the reader sheet; the claim button is disabled for 10 seconds with a countdown, then enabled.
- [ ] A claim gives +50 buff and survives a restart; claiming the same article again shows the "sudah diklaim" message.
- [ ] The 4th claim on the same day shows the daily-limit message; after the device date moves to the next day, the quota is available again (claimed URLs stay claimed).
- [ ] Buff never exceeds +150.
- [ ] Wrong API key shows the 401 message; no crash occurs in any network error case.
- [ ] Switching tabs back and forth does NOT trigger a new API request.
- [ ] Articles without images render without errors.

### 12.6. Profile & Formatting
- [ ] Every money value displays like `Rp 10.000`.
- [ ] Dates display in Indonesian (e.g. `14 Okt 2026, 09:30`) with no `LocaleDataException`.
- [ ] Transaction history is newest first, shows the empty state initially, and causes no "unbounded height" error.
- [ ] Financial health label matches §7.6 for all three thresholds and the empty state.

---

## 13. Risks, Known Limitations & Open Decisions

**Known limitations**
* No cloud backup or sync: uninstalling the app or clearing its data erases all progress.
* No edit/delete of transactions (battle effects would need rollback rules; planned for a later version).
* Daily quota relies on the device clock; changing the phone date can bypass it.
* News content is English (`country=us`); the Quest tab needs internet and has no offline article cache.
* `sqflite` targets Android/iOS only.
* Hero HP does not exist; "counter-attack" is represented as the monster healing.

**Risks if the app is distributed to real users**
* **NewsAPI free (Developer) plan is licensed for development only** and is limited to 100 requests/day; real public use needs a paid plan or another news source.
* **An API key passed via `--dart-define` is still embedded in the app binary** and can be extracted. A truly secure setup needs a small backend proxy (out of scope for this assignment).
* **Course rules:** earlier PRD versions forbade local databases. Confirm with the lecturer that `sqflite` is acceptable for this assignment before submission.

**Open decisions for the team**
* Add `url_launcher` so users can open the full article in a browser (currently they only read title/description and copy the link)?
* Add a "Reset Data" action with confirmation in Profile?
* Allow the hero name to be edited (currently seeded as "Pahlawan Hemat")?
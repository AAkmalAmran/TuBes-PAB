# Product Requirement Document (PRD) — v4.0 (Offline-First + Budget Survival)

## FinQuest: Pahlawan Finansial (Mobile Application)

> **Revision summary (v3.0 → v4.0):** added the **Budget Survival** system. Users set a **daily spending limit per category** (e.g. Makan max Rp 50.000/day). Spending beyond a limit costs the **hero's HP** (the hero now has HP), and when HP reaches 0 the **hero's level drops**. Changes: `Character` gets `hp`/`maxHp`; `TransactionRecord` gets a fixed `category`; new `Budget` model, `budgets` table and `date_key` column; new rules for overage penalty, healing, daily regeneration and level-down (§7); new Arena hero status and category input (§8.4); budget progress and settings in Profile (§8.6); updated contracts (§6.3) and acceptance tests (§12). The database schema stays at **version 1** because the app is not released yet (clear app data on dev devices once).

---

## 1. Project Overview

* **Application Name:** FinQuest: Pahlawan Finansial
* **Platform:** Flutter (Target: Android & iOS)
* **Category:** Gamified Personal Finance & Financial Literacy
* **Objective:** Help university students and young adults manage expenses and build consistent saving habits through an RPG. Saving attacks "Monster Boros"; **overspending the user's own daily limits hurts the hero**. Daily financial-news reading quests give attack buffs.
* **Core loop:**
  1. The user sets daily limits per category (defaults provided).
  2. Saving money → damages the current monster, grants Gold/EXP, restores a little hero HP.
  3. Spending within the limit → just logged, no penalty.
  4. Spending **over** the limit → hero loses HP and the monster heals. At 0 HP the hero drops one level.
  5. Reading up to 3 news articles per day → attack buff for the next saving.
* **Offline-first principle:** logging, budgets, battles, and the profile MUST work with **zero internet connectivity**. Only the **Quest** tab needs the network. A network failure must never block or crash any other feature.
* **Persistence:** all user data survives app restarts (local SQLite).
* **Academic Context:** Mobile Programming Final Term Project (Tugas Besar, deadline mid-to-late December). Assessment focuses on widget architecture, overflow-resilient layouts, asynchronous REST API consumption, local database usage, and Material 3.
* **Out of Scope (this version):** user accounts, cloud sync/backup, edit or delete of transactions, custom (user-created) categories, push notifications, web/desktop targets (`sqflite` supports Android/iOS only), multi-language switching.

---

## 2. Strict Guardrails & Constraints for AI Coding Assistants

> ⚠️ **CRITICAL DIRECTIVES FOR AI ASSISTANTS & VIBECODERS:**
>
> 1. **NO Third-Party State Management**
>    * **FORBIDDEN:** `bloc`, `flutter_bloc`, `provider`, `riverpod`, `get`, `mobx`.
>    * **REQUIRED:** vanilla Flutter only: `StatefulWidget` + `setState()` and constructor callbacks. Shared state is owned by `MainNavigationScreen` (§6).
>    * Also FORBIDDEN as shared-state mechanisms: `InheritedWidget`, `ChangeNotifier`, `ValueNotifier`, global mutable variables.
>    * `WidgetsBindingObserver` is allowed only for app-resume refresh in `MainNavigationScreen` (§6.5).
>
> 2. **Local Persistence: SQLite ONLY**
>    * **ALLOWED:** `sqflite` and `path`.
>    * **FORBIDDEN:** `hive`, `isar`, `drift`, `objectbox`, `sembast`, `shared_preferences`, `firebase_*`, `supabase_*`, or any other storage mechanism (including hand-written JSON/text files).
>    * Only `lib/services/database_helper.dart` may import `sqflite`/`path`. Only `MainNavigationScreen` may call `DatabaseHelper`. Screens and widgets NEVER touch the database directly.
>    * `DatabaseHelper` may be a singleton (connection holder, not shared game state).
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
>    * Any screen or sheet containing a `TextField` **MUST** be scrollable (`SingleChildScrollView`). Bottom sheets with text fields MUST use `isScrollControlled: true` and bottom padding of `MediaQuery.of(context).viewInsets.bottom`.
>    * Never place a `ListView`/`GridView` inside a `SingleChildScrollView` without `shrinkWrap: true` + `NeverScrollableScrollPhysics()` (or use a plain `Column`).
>    * Never place a scrollable inside a `Column` without `Expanded`/`SizedBox` bounds.
>
> 6. **Localization / UI Text Language**
>    * Code, comments, models, variable names, enum values, **and database table/column names** MUST be in English.
>    * User-facing UI labels, monster names, category labels, dialogs, SnackBars, and error messages MUST be in Indonesian (e.g. *"Makan"*, *"Catat Tabungan"*, *"Rp "*).
>
> 7. **Do Not Change Contracts**
>    * Do NOT rename or alter models (§4), the database schema (§5.1), constructor signatures (§6.3), or constants/formulas (§7). If a change is needed, update this PRD first and notify the team.
>
> 8. **Secrets**
>    * NEVER commit a real API key. Use `--dart-define` (§10).
>
> 9. **Offline-First Rule**
>    * Only `QuestScreen` and `NewsService` may use the network. The app MUST start and be fully playable in airplane mode. Never `await` a network call during startup.
>
> 10. **Data Integrity Rule**
>     * Every change that touches more than one table or row MUST run inside a single `db.transaction(...)`.
>     * **Write-through order:** compute new values → `await` the database write → only then `setState()`. If the database write throws, memory and UI stay unchanged and a SnackBar *"Gagal menyimpan data. Coba lagi."* is shown.
>
> 11. **Single Source of Game Math**
>     * All game formulas (damage, overage, HP loss, healing, level-down) are implemented ONLY as static functions in `game_rules.dart` (§7.9) and reused by both the parent logic and the UI preview. No duplicated formulas in widgets.

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

> If `flutter pub get` reports a version conflict (e.g. on `path`), run `flutter pub add sqflite path` to let Flutter pick compatible versions, then update this PRD.

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
│   │   │   └── game_rules.dart      # constants + pure game-math functions
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── utils/
│   │       └── formatters.dart
│   ├── models/
│   │   ├── monster.dart
│   │   ├── character.dart           # CHANGED: hp, maxHp
│   │   ├── transaction_record.dart  # CHANGED: ExpenseCategory + category
│   │   ├── article.dart
│   │   ├── budget.dart              # NEW
│   │   └── game_results.dart        # CHANGED: SavingResult, ExpenseResult, ArticleClaimResult
│   ├── services/
│   │   ├── database_helper.dart
│   │   └── news_service.dart
│   ├── screens/
│   │   ├── main_navigation_screen.dart
│   │   ├── arena/
│   │   │   ├── arena_screen.dart
│   │   │   └── widgets/
│   │   │       ├── hero_status.dart        # NEW: hero level + HP bar + buff
│   │   │       ├── monster_display.dart
│   │   │       └── attack_form.dart
│   │   ├── quest/
│   │   │   ├── quest_screen.dart
│   │   │   └── widgets/
│   │   │       ├── news_card.dart
│   │   │       └── article_reader_sheet.dart
│   │   └── profile/
│   │       ├── profile_screen.dart
│   │       └── widgets/
│   │           └── budget_settings_sheet.dart   # NEW
│   └── widgets/
│       └── hp_bar.dart
├── test/                            # optional, generated
└── pubspec.yaml
```

---

## 4. Data Contract & Model Definitions

> Models are plain Dart classes. **No `toMap`/`fromMap` inside models**: row mapping lives in `database_helper.dart`.
> **Unchanged:** `Monster` (§4.1), `Article` (§4.4). **Changed:** `Character` (§4.2), `TransactionRecord` (§4.3). **New:** `Budget` (§4.5), result types (§4.6).

### 4.1. `lib/models/monster.dart` (UNCHANGED)

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

### 4.2. `lib/models/character.dart` (CHANGED: `hp`, `maxHp` added)

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

### 4.3. `lib/models/transaction_record.dart` (CHANGED: `ExpenseCategory`, `category` added)

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
  final String id;
  final String description;
  final double amount;
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

### 4.4. `lib/models/article.dart` (UNCHANGED)

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

### 4.5. `lib/models/budget.dart` (NEW)

```dart
import 'transaction_record.dart';

class Budget {
  final ExpenseCategory category;
  int dailyLimit; // whole Rupiah, GameRules.minDailyLimit .. 999999999

  Budget({required this.category, required this.dailyLimit});
}
```

### 4.6. `lib/models/game_results.dart` (CHANGED)

Result objects returned by parent callbacks so child screens can show feedback without touching shared state.

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
  final bool exceededLimit;            // true if this expense pushed spending further over the limit
  final int hpLost;                    // hero HP lost (0 if within limit)
  final int monsterHealed;             // monster HP healed (0 if within limit or adventure complete)
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

---

## 5. Persistence Layer

### 5.1. Database schema (`finquest.db`, version 1)

All identifiers in English. Booleans are `INTEGER` (0/1). Timestamps are ISO-8601 `TEXT`. Day keys are local dates formatted `'yyyy-MM-dd'`. Category values are the enum names (`food`, `transport`, `entertainment`, `shopping`, `other`).

```sql
CREATE TABLE character (
  id          INTEGER PRIMARY KEY CHECK (id = 1),   -- single row
  name        TEXT    NOT NULL,
  gold        INTEGER NOT NULL DEFAULT 0,
  exp         INTEGER NOT NULL DEFAULT 0,
  level       INTEGER NOT NULL DEFAULT 1,
  attack_buff INTEGER NOT NULL DEFAULT 0,
  hp          INTEGER NOT NULL DEFAULT 100,         -- NEW
  max_hp      INTEGER NOT NULL DEFAULT 100          -- NEW
);

CREATE TABLE monsters (
  id                TEXT    PRIMARY KEY,            -- 'kopi' | 'belanja' | 'ongkir'
  name              TEXT    NOT NULL,
  max_hp            INTEGER NOT NULL,
  current_hp        INTEGER NOT NULL,
  asset_image_path  TEXT    NOT NULL,
  sort_order        INTEGER NOT NULL                -- 0, 1, 2
);

CREATE TABLE game_state (
  id                      INTEGER PRIMARY KEY CHECK (id = 1),   -- single row
  current_monster_index   INTEGER NOT NULL DEFAULT 0,
  is_adventure_complete   INTEGER NOT NULL DEFAULT 0,
  last_regen_date         TEXT    NOT NULL                       -- NEW: 'yyyy-MM-dd' of last daily HP regen
);

CREATE TABLE transactions (
  id           TEXT PRIMARY KEY,
  description  TEXT NOT NULL,
  amount       REAL NOT NULL,
  type         TEXT NOT NULL CHECK (type IN ('expense', 'saving')),
  category     TEXT,                                -- NEW: null for saving
  date         TEXT NOT NULL,                       -- ISO-8601 (local time)
  date_key     TEXT NOT NULL,                       -- NEW: 'yyyy-MM-dd' (local), for daily aggregation
  CHECK (category IS NULL OR category IN ('food','transport','entertainment','shopping','other')),
  CHECK ((type = 'expense' AND category IS NOT NULL) OR (type = 'saving' AND category IS NULL))
);
CREATE INDEX idx_transactions_date ON transactions (date DESC);
CREATE INDEX idx_transactions_daily ON transactions (date_key, category);   -- NEW

CREATE TABLE budgets (                              -- NEW
  category      TEXT    PRIMARY KEY CHECK (category IN ('food','transport','entertainment','shopping','other')),
  daily_limit   INTEGER NOT NULL CHECK (daily_limit >= 1000)
);

CREATE TABLE claimed_articles (
  url            TEXT PRIMARY KEY,                  -- an article can be claimed only once, ever
  claimed_date   TEXT NOT NULL                      -- local day 'yyyy-MM-dd', used for the daily quota
);
```

**Seeding (`onCreate`):**
* `character`: `name: 'Pahlawan Hemat'`, gold/exp 0, level 1, buff 0, `hp = max_hp = GameRules.heroMaxHp`.
* `monsters`: from `DatabaseHelper.defaultMonsters()` (§6.2).
* `game_state`: index `0`, complete `0`, `last_regen_date = todayKey()`.
* `budgets`: one row per category from `GameRules.defaultDailyLimits` (§7). **Every category always has a limit row** (limits can be edited but not removed).

**Migrations:** keep `version: 1` with an `onUpgrade` stub until the **first public release**. Because the schema changed after v3.0, developers must clear app data once (§10.9). From the first release onward, every schema change bumps the version and adds an `ALTER TABLE` step; never delete user data on upgrade.

### 5.2. `lib/services/database_helper.dart`

Responsibilities: open/create the DB, map rows ↔ models, and expose exactly these methods:

```dart
class GameSnapshot {
  final Character character;
  final List<Monster> monsters;                      // ordered by sort_order
  final int currentMonsterIndex;
  final bool isAdventureComplete;
  final String lastRegenDate;                        // 'yyyy-MM-dd'
  final List<TransactionRecord> recentTransactions;  // newest first, LIMIT GameRules.historyLimit
  final double totalSaving;                          // SQL SUM over ALL saving rows
  final double totalExpense;                         // SQL SUM over ALL expense rows
  final Map<ExpenseCategory, int> budgets;           // daily limit per category (all 5 present)
  final Map<ExpenseCategory, double> todaySpent;     // SUM of today's expenses per category (missing = 0)
  final Map<String, String> claimedArticles;         // url -> claimed_date
  // constructor with all fields required
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  DatabaseHelper._();

  static List<Monster> defaultMonsters();            // fresh monsters at full HP (§6.2)

  Future<GameSnapshot> loadSnapshot();

  // One transaction: update character row, update the given monster row,
  // update game_state (index, complete flag, last_regen_date), insert [record]
  // (date_key is derived from record.date).
  Future<void> persistTurn({
    required Character character,
    required Monster monster,
    required int currentMonsterIndex,
    required bool isAdventureComplete,
    required String lastRegenDate,
    required TransactionRecord record,
  });

  // One transaction: update character.hp and game_state.last_regen_date.
  Future<void> persistRegen({required Character character, required String lastRegenDate});

  // One transaction: insert into claimed_articles and update character.attack_buff.
  Future<void> persistArticleClaim({
    required String url,
    required String claimedDate,
    required Character character,
  });

  // One transaction: upsert all given budgets.
  Future<void> updateBudgets(Map<ExpenseCategory, int> budgets);

  // One transaction: reset all monsters to max_hp, reset current index/complete flag.
  // Character, transactions, budgets and claimed_articles are kept.
  Future<void> restartAdventure();
}
```

Implementation requirements:

* Open once and cache the `Future<Database>` (guard against concurrent opens): `join(await getDatabasesPath(), 'finquest.db')`.
* Parameterized `db.insert/update/query` or `?` placeholders only. Never interpolate user text into SQL.
* `TransactionRecord.type` stored as `type.name`; `category` as `category?.name`; parse with `Enum.values.byName`.
* `date_key` is produced with `dateKey(record.date)` from `formatters.dart`.
* Totals: `SELECT type, SUM(amount) AS total FROM transactions GROUP BY type`; missing type → `0`.
* Today's spending: `SELECT category, SUM(amount) FROM transactions WHERE type = 'expense' AND date_key = ? GROUP BY category` with `todayKey()`.
* Recent list: `ORDER BY date DESC LIMIT ?`.

### 5.3. Startup flow

1. `main()` → `WidgetsFlutterBinding.ensureInitialized()` → `await initializeDateFormatting('id_ID')` → `runApp`. No network calls.
2. `MainNavigationScreen.initState()` calls `_loadSnapshot()` with `_isLoading = true`.
3. While loading: `Scaffold` with centered `CircularProgressIndicator`.
4. On failure: centered *"Gagal memuat data. Coba lagi."* + **"Coba Lagi"** button re-running `_loadSnapshot()`.
5. On success: fill the in-memory state (§6.2), then run the **daily rollover** (§6.5). If hero HP was regenerated, persist it with `persistRegen` (on failure: skip silently; it is retried on the next action).
6. Show the `NavigationBar` + `IndexedStack`.

---

## 6. State Ownership & Constructor Contracts

### 6.1. Principle

SQLite is the **source of truth**. `MainNavigationScreen` holds an **in-memory copy** (loaded at startup) and keeps it in sync via the write-through rule (guardrail #10). Child screens receive data via constructors and request changes via **async callbacks**; they never mutate shared objects and never call the database.

### 6.2. State owned by `_MainNavigationScreenState`

```dart
bool _isLoading = true;
bool _hasLoadError = false;
int _currentIndex = 0;

late Character _character;
late List<Monster> _monsters;
late int _monsterIndex;
late bool _isAdventureComplete;
late String _lastRegenDate;                         // 'yyyy-MM-dd'
late List<TransactionRecord> _recentTransactions;   // newest first, max GameRules.historyLimit
late double _totalSaving;
late double _totalExpense;
late Map<ExpenseCategory, int> _budgets;            // daily limit per category
late Map<ExpenseCategory, double> _todaySpent;      // today's spending per category
late String _spentDayKey;                           // the day that _todaySpent belongs to
late Map<String, String> _claimedArticles;          // url -> 'yyyy-MM-dd'
```

`DatabaseHelper.defaultMonsters()` (seeding and restart), fixed order:

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
  required Monster monster,                                   // current monster
  required bool isAdventureComplete,
  required Map<ExpenseCategory, int> budgets,
  required Map<ExpenseCategory, double> todaySpent,
  required Future<SavingResult?> Function(double amount, String description) onSaving,            // null = DB error
  required Future<ExpenseResult?> Function(double amount, String description, ExpenseCategory category) onExpense, // null = DB error
  required Future<void> Function() onRestartAdventure,
})

// lib/screens/arena/widgets/hero_status.dart  (StatelessWidget)
HeroStatus({ required Character character })

// lib/screens/arena/widgets/monster_display.dart  (StatelessWidget)
MonsterDisplay({ required Monster monster })

// lib/screens/arena/widgets/attack_form.dart  (StatefulWidget, owns TextEditingControllers)
AttackForm({
  required Map<ExpenseCategory, int> budgets,                 // for the live limit hint / preview
  required Map<ExpenseCategory, double> todaySpent,
  required Future<void> Function(double amount, String description) onSaving,
  required Future<void> Function(double amount, String description, ExpenseCategory category) onExpense,
})

// lib/screens/quest/quest_screen.dart  (StatefulWidget, owns the cached Future)
QuestScreen({
  required Character character,
  required Set<String> claimedArticleUrls,
  required int claimsToday,
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
  required List<TransactionRecord> recentTransactions,        // latest 100
  required double totalSaving,
  required double totalExpense,
  required Map<ExpenseCategory, int> budgets,
  required Map<ExpenseCategory, double> todaySpent,
  required Future<bool> Function(Map<ExpenseCategory, int> newBudgets) onUpdateBudgets,   // false = DB error
})

// lib/screens/profile/widgets/budget_settings_sheet.dart  (StatefulWidget, owns TextEditingControllers)
BudgetSettingsSheet({
  required Map<ExpenseCategory, int> budgets,
  required Future<bool> Function(Map<ExpenseCategory, int> newBudgets) onSave,
})

// lib/widgets/hp_bar.dart  (StatelessWidget; reused for monster HP and hero HP)
HpBar({ required int currentHp, required int maxHp })
```

Because `AttackForm` callbacks are asynchronous, it MUST keep a `_isSubmitting` flag: both buttons are disabled while a callback is pending (prevents double-tap duplicates). After every `await`, check `mounted`/`context.mounted` before using `context`.

### 6.4. Parent callback logic (owned by `MainNavigationScreen`)

All callbacks follow: **rollover check → compute on local copies → `await` DB → `if (!mounted) return` → `setState` to apply**. Wrap DB calls in `try/catch`; on error show the *"Gagal menyimpan data. Coba lagi."* SnackBar and return `null`/`false`. All game math uses **integer Rupiah** (`amount.round()`).

* **`onSaving(amount, description)`**
  1. Run the daily rollover (§6.5) on local copies.
  2. Compute per §7.2: damage (0 if `_isAdventureComplete`; the buff is then **not** consumed), gold, exp, level, hero HP restore (§7.4). If new monster HP is 0 → apply the victory bonus (§7.5), recompute level, decide next state (`_monsterIndex + 1`, or `isAdventureComplete = true` with the index staying on the last monster).
  3. Build `TransactionRecord(type: saving, category: null, id: DateTime.now().microsecondsSinceEpoch.toString(), date: DateTime.now())`.
  4. `await persistTurn(...)`.
  5. `setState`: apply to `_character`, the monster, index/complete flag, `_lastRegenDate`, `_recentTransactions.insert(0, record)` (trim to limit), `_totalSaving += amount`.
  6. Return `SavingResult`.
* **`onExpense(amount, description, category)`**
  1. Run the daily rollover (§6.5) on local copies.
  2. `limit = _budgets[category]`, `spentBefore = (_todaySpent[category] ?? 0).round()`, then `newOverage = GameRules.newOverage(limit, spentBefore, amountInt)` (§7.9).
  3. If `newOverage == 0`: **no gameplay effect** (record only). Otherwise: `hpLost = GameRules.hpLoss(newOverage)`; `monsterHealed = _isAdventureComplete ? 0 : GameRules.monsterHeal(newOverage)` (clamped to the monster's `maxHp`).
  4. Apply `hpLost` to hero HP. If HP ≤ 0 → level-down rule (§7.4) and HP refilled to `maxHp`.
  5. Build the `TransactionRecord(type: expense, category: category, ...)`, `await persistTurn(...)` (monster row is rewritten even if unchanged).
  6. `setState`: apply values, `_todaySpent[category] = spentBefore + amountInt`, add the record, `_totalExpense += amount`.
  7. Return `ExpenseResult`.
* **`onRestartAdventure()`**: `await restartAdventure()`, then `setState`: `_monsters = DatabaseHelper.defaultMonsters()`, `_monsterIndex = 0`, `_isAdventureComplete = false`.
* **`onArticleRead(article)`**, evaluated in this exact order:
  1. `today = todayKey()`.
  2. URL already in `_claimedArticles` → `alreadyClaimed`.
  3. Claims with `claimed_date == today` ≥ `GameRules.dailyArticleQuota` → `dailyLimitReached`.
  4. `attackBuff >= GameRules.maxAttackBuff` → `buffAtMax`.
  5. Otherwise `await persistArticleClaim(...)` (new buff = old + `articleBuff`), then `setState` → `granted`.
* **`onUpdateBudgets(newBudgets)`**: validate (each value ≥ `minDailyLimit`), `await updateBudgets(...)`, `setState(() => _budgets = {...newBudgets})`, return `true`; on error show the error SnackBar and return `false`. **Limit changes apply only to expenses logged afterwards** (no retroactive penalty or refund).
* When building `QuestScreen`, pass `claimsToday` computed from `_claimedArticles` for today's key and `claimedArticleUrls: _claimedArticles.keys.toSet()`.

### 6.5. Daily rollover (`_rolloverIfNeeded`)

Runs at startup (after load), at the beginning of `onSaving`/`onExpense`, and when the app resumes from background (`WidgetsBindingObserver.didChangeAppLifecycleState` → `resumed`; register in `initState`, remove in `dispose`).

```
today = todayKey()
if _spentDayKey != today:
    _todaySpent = {}            // new day, nothing spent yet
    _spentDayKey = today
if _lastRegenDate < today:      // string compare works for 'yyyy-MM-dd'
    days = DateTime.parse(today).difference(DateTime.parse(_lastRegenDate)).inDays
    hp = min(maxHp, hp + days * GameRules.dailyHpRegen)
    _lastRegenDate = today
```
If the device date moves backward (`_lastRegenDate > today`), do nothing. On resume, if anything changed, persist with `persistRegen` and call `setState`.

---

## 7. Game Rules

All numbers live in `lib/core/constants/game_rules.dart`; no magic numbers elsewhere.

```dart
import '../../models/transaction_record.dart';

class GameRules {
  // --- Monster battle ---
  static const int rupiahPerDamage = 1000;   // Rp 1.000 saved = 1 damage
  static const int rupiahPerGold = 1000;     // Rp 1.000 saved = 1 gold
  static const int baseExpPerSaving = 10;    // flat EXP per saving record
  static const int rupiahPerBonusExp = 5000; // +1 EXP per Rp 5.000 saved
  static const int rupiahPerHeal = 2000;     // Rp 2.000 of NEW overage = 1 HP healed on the monster
  static const int victoryGold = 50;
  static const int victoryExp = 50;
  static const int expPerLevel = 100;        // level = 1 + exp ~/ 100

  // --- Hero HP & budgets ---
  static const int heroMaxHp = 100;
  static const int rupiahPerHpLoss = 1000;   // Rp 1.000 of NEW overage = 1 hero HP lost (min 1)
  static const int rupiahPerHpHeal = 5000;   // Rp 5.000 saved = 1 hero HP restored (min 1)
  static const int dailyHpRegen = 25;        // hero HP regained per calendar day (lazy, §6.5)
  static const int minDailyLimit = 1000;     // minimum allowed daily limit
  static const Map<ExpenseCategory, int> defaultDailyLimits = {
    ExpenseCategory.food: 50000,
    ExpenseCategory.transport: 20000,
    ExpenseCategory.entertainment: 30000,
    ExpenseCategory.shopping: 50000,
    ExpenseCategory.other: 30000,
  };

  // --- Daily mission ---
  static const int articleBuff = 50;         // buff per newly claimed article
  static const int maxAttackBuff = 150;      // cap on stored buff
  static const int dailyArticleQuota = 3;    // max claims per local day
  static const int readSeconds = 10;         // reading gate before a claim is allowed

  // --- Misc ---
  static const int historyLimit = 100;       // transactions kept in memory / shown in Profile

  // Pure functions: see §7.9
}
```

### 7.1. Monsters
HP: Kopi Susu Mahal **300**, Belanja Impulsif **800**, Ongkir Makanan **1500**. Fixed order. `currentHp` is clamped to `0..maxHp`.

### 7.2. Saving ("Catat Tabungan"): player attacks
```
baseDamage = max(1, amount ~/ rupiahPerDamage)
damage     = isAdventureComplete ? 0 : baseDamage + attackBuff
newHp      = max(0, monster.currentHp - damage)          // skipped if complete
attackBuff = isAdventureComplete ? attackBuff : 0        // buff is consumed by a real attack only
gold      += amount ~/ rupiahPerGold
exp       += baseExpPerSaving + amount ~/ rupiahPerBonusExp
level      = 1 + exp ~/ expPerLevel
heroHp     = min(maxHp, heroHp + max(1, amount ~/ rupiahPerHpHeal))   // §7.4
```
Feedback: SnackBar *"Serangan berhasil! Monster menerima {damage} damage."*, plus *" HP +{hpRestored}."* when `hpRestored > 0`, plus *" Naik level! Sekarang Level {level}."* if leveled up. If the adventure is complete: *"Tabungan tercatat! Semua monster sudah kalah."*

### 7.3. Expense ("Catat Pengeluaran") and the daily budget
A user-defined daily limit exists per category (`budgets`). "Over the limit" means **strictly greater** than the limit (spending exactly the limit is fine).

```
spentBefore = today's total for this category, before this expense
overBefore  = max(0, spentBefore - limit)
overAfter   = max(0, spentBefore + amount - limit)
newOverage  = overAfter - overBefore          // ONLY the newly exceeded part; never double-counted
```

| Case | Effect |
|---|---|
| `newOverage == 0` (within limit) | Logged only. No HP loss, no monster heal, no gold/EXP change |
| `newOverage > 0` | Hero loses `max(1, newOverage ~/ rupiahPerHpLoss)` HP; monster heals `max(1, newOverage ~/ rupiahPerHeal)` HP (0 if adventure complete) |

Examples with the Makan limit of Rp 50.000:
* Rp 30.000 → within limit (remaining Rp 20.000).
* Then Rp 40.000 → total 70.000, `newOverage` = 20.000 → hero −20 HP, monster +10 HP.
* Then Rp 10.000 → `newOverage` = 10.000 (not 30.000) → hero −10 HP, monster +5 HP.

Feedback:
* Within limit: SnackBar *"Pengeluaran {category.label} tercatat. Sisa batas hari ini: {formatRupiah(remainingToday)}."*
* Over limit: SnackBar *"Batas {category.label} harian terlampaui! HP kamu −{hpLost}, monster pulih +{monsterHealed}."* (omit the monster part when 0).
* HP depleted: `showDialog` (§7.4).

### 7.4. Hero HP, healing, regeneration & level-down
* Hero HP range is `0..maxHp` (default 100/100).
* **Healing sources:** saving records (§7.2) and daily regeneration (+`dailyHpRegen` per calendar day, lazy, capped at `maxHp`, §6.5).
* **Level-down trigger:** after applying `hpLost`, if `hp <= 0`:
  ```
  if level > 1:
      level = level - 1
      exp   = (level - 1) * expPerLevel      // floor of the NEW (lower) level; progress inside the old level is lost
      leveledDown = true
  else:                                       // already Level 1
      exp = 0
      leveledDown = false
  hp = maxHp                                  // full refill: prevents chained demotions in one day
  hpDepleted = true
  ```
  Gold, monster progress, and attack buff are not affected. The invariant `level == 1 + exp ~/ expPerLevel` always holds.
* **HP-depleted dialog** (`showDialog`, `barrierDismissible: false`, button *"Mengerti"*):
  * Level dropped: *"HP kamu habis! Level turun ke Level {newLevel}. HP dipulihkan penuh."*
  * Already Level 1: *"HP kamu habis! Kamu sudah di Level 1, jadi EXP direset ke 0. HP dipulihkan penuh."*
* Overage damage left over after reaching 0 HP is discarded (HP is refilled to full).

### 7.5. Victory & end of game
* Victory rewards (`victoryGold`, `victoryExp`) are applied **atomically in the same DB transaction** as the finishing blow, so progress is never lost if the app closes while the dialog is showing.
* The Arena shows a victory dialog (`showDialog`, `barrierDismissible: false`) using `SavingResult.defeatedMonsterName`: *"Kamu mengalahkan {name}! Hadiah: +50 Gold, +50 EXP"*, button *"Lanjut"*.
* After the last monster, the Arena shows the end-state card *"Semua Monster Boros Telah Dikalahkan!"* with **"Mulai Petualangan Baru"** (`onRestartAdventure`). **The attack form stays visible** in this state: budget tracking must keep working (saving still gives Gold/EXP/HP, deals no damage; expenses still cost HP, no monster heal).

### 7.6. Daily Mission (news)
* **Goal:** read up to **3 different articles per local day** (`dailyArticleQuota`); each claim gives **+50** attack buff.
* An article (identified by `url`) can be claimed **only once, ever** (`claimed_articles` primary key).
* Buff is stored in SQLite, stacks up to **+150**, persists across restarts, and is consumed by the next real saving attack, so it works **offline**.
* The daily quota resets when the local date changes (changing the phone clock can bypass it; accepted, §13).
* **Reading gate:** tapping an article opens `ArticleReaderSheet`; **"Klaim Buff"** is disabled for `readSeconds` (10 s) with a visible countdown (*"Baca dulu… 7 detik"*), then enabled.
* Feedback messages:

| Result | SnackBar (Indonesian) |
|---|---|
| `granted` | Misi harian tercapai! Kamu mendapatkan Buff Serangan +50! |
| `alreadyClaimed` | Artikel ini sudah kamu klaim. Cari artikel lain! |
| `dailyLimitReached` | Misi harian hari ini sudah selesai (3/3). Kembali lagi besok! |
| `buffAtMax` | Buff Serangan sudah maksimal (+150). Gunakan dulu untuk menyerang! |

### 7.7. Financial health status (Profile)
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

Totals come from SQL aggregates (all-time), not from the 100-item list.

### 7.8. Level and EXP display
`level = 1 + exp ~/ expPerLevel`. The Profile shows *"{exp % 100} / 100 EXP menuju level berikutnya"*.

### 7.9. Pure functions in `game_rules.dart` (single source of game math)

```dart
class GameRules {
  // ... constants above ...

  /// Only the newly exceeded part of today's budget for this expense.
  static int newOverage(int limit, int spentBefore, int amount) {
    final overBefore = (spentBefore - limit) > 0 ? spentBefore - limit : 0;
    final overAfter = (spentBefore + amount - limit) > 0 ? spentBefore + amount - limit : 0;
    return overAfter - overBefore;
  }

  /// Hero HP lost for a given new overage (0 if none).
  static int hpLoss(int newOverage) =>
      newOverage <= 0 ? 0 : (newOverage ~/ rupiahPerHpLoss < 1 ? 1 : newOverage ~/ rupiahPerHpLoss);

  /// Monster HP healed for a given new overage (0 if none).
  static int monsterHeal(int newOverage) =>
      newOverage <= 0 ? 0 : (newOverage ~/ rupiahPerHeal < 1 ? 1 : newOverage ~/ rupiahPerHeal);

  /// Hero HP restored by a saving (before clamping to maxHp).
  static int heroHpRestore(int amount) =>
      (amount ~/ rupiahPerHpHeal) < 1 ? 1 : amount ~/ rupiahPerHpHeal;
}
```

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
String dateKey(DateTime date);         // DateFormat('yyyy-MM-dd').format(date) (local date)
String todayKey();                     // dateKey(DateTime.now())
```
All Rupiah figures MUST go through `formatRupiah` (e.g. `Rp 10.000`, never `10000.0`).

### 8.3. Root Navigation (`main_navigation_screen.dart`)
* Material 3 `NavigationBar` (NOT `BottomNavigationBar`).

| Index | Label | Icon (fixed) |
|---|---|---|
| 0 | Arena | `Icons.shield` |
| 1 | Quest | `Icons.newspaper` |
| 2 | Profil | `Icons.person` |

* Body: loading/error states (§5.3), then `IndexedStack(index: _currentIndex, children: [ArenaScreen, QuestScreen, ProfileScreen])` to preserve state across tabs. The Quest future is fetched once per session unless the user taps retry.
* Owns all shared state, callbacks (§6.4), and the daily rollover (§6.5).

### 8.4. Battle Arena (`arena_screen.dart`)
* Body wrapped in `SingleChildScrollView` with padding.
* Layout (top to bottom): `HeroStatus`, `MonsterDisplay`, end-state card (only if `isAdventureComplete`), `AttackForm`.
* **`HeroStatus`:** hero name, *"Level {level}"*, *"HP Hero: {hp} / {maxHp}"* with `HpBar`, and a buff chip *"Buff Serangan: +{attackBuff}"* (only if > 0). Use a distinct bar color from the monster's if desired (still via `HpBar`).
* **`MonsterDisplay`:** `Image.asset(..., height: 180, errorBuilder: ...)` with an icon placeholder on error; name as title; `Text('HP: ${monster.currentHp} / ${monster.maxHp}')`; `HpBar`.
* **`HpBar`:** `TweenAnimationBuilder<double>` (400 ms) feeding a `LinearProgressIndicator(value:, minHeight: 14)` with rounded corners; green > 50 %, orange 25–50 %, red < 25 %.
* **`AttackForm`:**
  * Amount `TextField`: `keyboardType: TextInputType.number`, `inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)]`, `InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.monetization_on), labelText: 'Nominal Transaksi')`.
  * **Category selector** (label *"Kategori Pengeluaran"*): Material 3 `DropdownMenu<ExpenseCategory>` or `DropdownButtonFormField`, options = all five categories with `label`, default `ExpenseCategory.food`. Used only by "Catat Pengeluaran".
  * **Live budget hint** under the selector: *"Terpakai hari ini: {formatRupiah(spent)} / {formatRupiah(limit)}"*. If the typed amount would exceed the limit, show a red warning *"Melebihi batas! Perkiraan HP −{hpLoss}"* computed with `GameRules.newOverage`/`hpLoss`.
  * Description `TextField` (label *"Deskripsi (opsional)"*; fallback *"Tabungan"* / *"Pengeluaran"* when empty).
  * Buttons **"Catat Tabungan"** (`FilledButton`) and **"Catat Pengeluaran"** (`OutlinedButton`), disabled while `_isSubmitting`.
  * Validation: empty or `<= 0` → inline `errorText` *"Masukkan nominal lebih dari 0"*; callbacks not called.
  * On success: clear amount/description (keep the selected category), `FocusScope.of(context).unfocus()`. Dispose controllers in `dispose()`.
* **Flow after saving:** `await onSaving` → if `null`, stop → SnackBar (§7.2) → if `defeatedMonsterName != null`, show the victory dialog.
* **Flow after expense:** `await onExpense` → if `null`, stop → SnackBar (§7.3) → if `hpDepleted`, show the HP-depleted dialog (§7.4).
* The Arena works fully offline.

### 8.5. Quest & News Screen (`quest_screen.dart`): the only online screen
* `StatefulWidget` holding `late Future<List<Article>> _articlesFuture;` assigned in `initState()` (and re-assigned on retry/refresh). **Never call the service in `build()`** (NewsAPI free quota is 100 requests/day).
* **Mission header (works offline, built from props):** *"Misi Harian: {claimsToday}/3 artikel"*, a progress indicator, and current buff *"Buff Serangan: +{attackBuff}"*. Note: *"Baca berita keuangan untuk mendapat Buff Serangan. Arena dan Profil tetap bisa dipakai tanpa internet."*
* `FutureBuilder<List<Article>>`:
  * `waiting` → centered `CircularProgressIndicator()`.
  * `hasError` → centered icon, Indonesian message (§9.3), and **"Coba Lagi"** button (`setState(() => _articlesFuture = NewsService().fetchFinancialNews())`).
  * Empty list → *"Belum ada berita saat ini."* + retry.
  * Data → `ListView.builder` of `NewsCard`, optionally inside `RefreshIndicator`.
* **`NewsCard`:** Material `Card`; thumbnail via `Image.network` only if `urlToImage != null` (with `errorBuilder`/`loadingBuilder` fallbacks); title (max 3 lines); source; date via `formatDate`; *"Sudah diklaim"* badge and dimmed style if `isClaimed`.
* **Tap handling:** tap → `showModalBottomSheet` with `ArticleReaderSheet`. On **"Klaim Buff"**: close the sheet, `await onArticleRead(article)`, hide any current SnackBar, then show the message for the returned `ArticleClaimResult` (§7.6).
* **`ArticleReaderSheet`:** scrollable content (title, source, date, description, `SelectableText(article.url)` so the link can be copied). If `isClaimed`, the button is disabled with label *"Sudah Diklaim"*. Otherwise the countdown (`Timer.periodic`, cancelled in `dispose()`) runs from `readSeconds` to 0, then the button is enabled.
* Articles are not opened in an external browser (no `url_launcher`; locked dependencies). See §13.

### 8.6. Profile & Summary Screen (`profile_screen.dart`)
* Body: `SingleChildScrollView` containing a `Column`.
* **Hero Stats (Card):** name, Level, **HP (`{hp} / {maxHp}` with `HpBar`)**, Total Gold, EXP total plus *"{exp % 100} / 100 EXP menuju level berikutnya"*, Active Buff *"+{attackBuff}"*.
* **Daily Budget (Card), title *"Anggaran Harian"*:** one row per category: label, *"{formatRupiah(spent)} / {formatRupiah(limit)}"*, and a `LinearProgressIndicator` (`value` clamped to 0–1; green below 80 %, orange 80–100 %, red when spent > limit). A button **"Atur Batas Harian"** opens `BudgetSettingsSheet` via `showModalBottomSheet(isScrollControlled: true)`.
* **`BudgetSettingsSheet`:** wrapped in `SingleChildScrollView`, bottom padding `viewInsets.bottom`. Five numeric `TextField`s (prefix *"Rp "*, `digitsOnly`, max 9 digits, initial value = current limit), one per category. Validation: empty or `< GameRules.minDailyLimit` → *"Minimal Rp 1.000"*. A **"Simpan"** button calls `onSave` with all five values (disabled while saving); on `true` close the sheet and show SnackBar *"Batas harian diperbarui. Berlaku untuk pengeluaran berikutnya."*; on `false` stay open. Dispose controllers in `dispose()`.
* **Financial Summary (Card):** Total Tabungan, Total Pengeluaran (`formatRupiah`), and the Financial Health label (§7.7).
* **Transaction History:** read-only, newest first, titled *"Riwayat Transaksi (100 terakhir)"*. Build with `Column(children: recentTransactions.map(...).toList())` or `ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())`. Item: icon (saving = green up-arrow, expense = red down-arrow), description, **category label for expenses**, `formatDateTime`, signed amount (`+Rp 10.000` / `-Rp 10.000`).
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
  mkdir -p assets/images lib/core/constants lib/core/theme lib/core/utils lib/models lib/services lib/screens/arena/widgets lib/screens/quest/widgets lib/screens/profile/widgets lib/widgets
  ```
* **Windows PowerShell:**
  ```powershell
  New-Item -ItemType Directory -Force -Path assets/images, lib/core/constants, lib/core/theme, lib/core/utils, lib/models, lib/services, lib/screens/arena/widgets, lib/screens/quest/widgets, lib/screens/profile/widgets, lib/widgets
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

### 10.9. Reset Local Data (REQUIRED once after pulling schema changes)
The schema changed (v4.0) while the DB version is still 1, so an older `finquest.db` will crash on missing columns/tables. Uninstall the app from the device/emulator, or *Settings → Apps → FinQuest → Storage → Clear data*. Repeat whenever the schema in §5.1 changes before the first release.

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
- Strictly obey PRD.md v4.0: models (section 4), SQLite schema (5.1), constructor contracts (6.3), game rules (7).
- FORBIDDEN: external state management (No Bloc, Riverpod, Provider, GetX). Use only StatefulWidget and setState().
- Persistence: ONLY sqflite + path, ONLY inside lib/services/database_helper.dart. FORBIDDEN: Hive, Isar, Drift, SharedPreferences, Firebase, JSON files.
- Only MainNavigationScreen calls DatabaseHelper. Child screens use constructor params and async callbacks exactly as in 6.3. Never mutate shared objects from child screens.
- Write-through order: compute -> await DB (single transaction for multi-row changes) -> setState. On DB error: SnackBar "Gagal menyimpan data. Coba lagi." and leave state unchanged.
- Game math (damage, overage, HP loss, heal, level-down) lives ONLY in lib/core/constants/game_rules.dart (static constants + pure functions). Never duplicate formulas in widgets.
- Budget rule: only the NEWLY exceeded part of the daily limit is penalized (GameRules.newOverage). Within-limit expenses have no gameplay effect.
- Offline-first: only QuestScreen/NewsService may use the network. Arena and Profile must work in airplane mode. Never await network at startup.
- Allowed packages: flutter, http, intl, sqflite, path. SDK libraries (dart:io, dart:async, flutter/services.dart) are fine.
- DO NOT rename or change model schemas, table/column names, constructor signatures, or folder structure.
- All Rupiah text uses formatRupiah(). Dates use dateKey()/todayKey() for day keys.
- Wrap any screen or bottom sheet containing a TextField in SingleChildScrollView (sheets: isScrollControlled + viewInsets padding). Never put a ListView inside a SingleChildScrollView without shrinkWrap + NeverScrollableScrollPhysics.
- Never call NewsService inside build(); cache the Future in initState.
- Never hardcode the API key; use String.fromEnvironment('NEWS_API_KEY').
- Use parameterized SQL only. Use Material 3 (NavigationBar, FilledButton, ColorScheme.fromSeed).
- Check mounted / context.mounted after every await before using context or calling setState.
- Write code, comments, enum values, and DB identifiers in English, but keep ALL UI strings in Indonesian.
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
- [ ] Game formulas exist only in `game_rules.dart` (grep for `~/` in widgets/screens finds no game math).

### 12.2. Layout & Navigation
- [ ] No overflow banner when the keyboard opens in Arena and in the budget settings sheet, on a small screen (360×640) and in landscape.
- [ ] Switching tabs preserves state (Arena inputs/HP, Quest scroll position, Profile data).
- [ ] Tab labels are not truncated on a 360 px-wide screen.
- [ ] A loading indicator shows briefly at startup; a DB load failure shows the retry state instead of a crash.

### 12.3. Battle & Hero HP
- [ ] Saving Rp 10.000 with no buff deals exactly 10 damage and restores 2 hero HP (if below max); HP text and `HpBar` update with animation.
- [ ] Saving Rp 500 deals 1 damage and restores 1 hero HP (minimums); Gold/EXP/Level follow §7.2.
- [ ] Empty, `0`, or non-numeric amount is rejected with the inline error; letters cannot be typed.
- [ ] Tapping a button twice quickly creates only **one** transaction.
- [ ] Defeating monster 1 shows the victory dialog; the next monster appears at full HP; +50 Gold/+50 EXP are applied.
- [ ] Defeating all three monsters shows the end-state card; the attack form is still visible; saving then deals no damage and does not consume the buff; "Mulai Petualangan Baru" resets monsters but keeps hero stats, history, budgets, and claims.

### 12.4. Budget Survival (NEW)
- [ ] First launch shows default limits (Makan Rp 50.000, Transportasi Rp 20.000, Hiburan Rp 30.000, Belanja Rp 50.000, Lainnya Rp 30.000).
- [ ] Makan Rp 30.000 → no HP change, no monster heal, SnackBar shows remaining Rp 20.000; the transaction is logged with category *Makan*.
- [ ] Then Makan Rp 40.000 → hero −20 HP, monster +10 HP, warning SnackBar.
- [ ] Then Makan Rp 10.000 → hero −10 HP (only the new overage is penalized, **not** 30).
- [ ] Spending exactly the limit causes no penalty; Rp 1 over causes −1 HP.
- [ ] Limits are per category: overspending Hiburan does not affect Makan's remaining budget.
- [ ] The live hint in `AttackForm` shows spent/limit and the red "Melebihi batas! Perkiraan HP −N" warning matches the actual HP loss afterwards.
- [ ] When hero HP reaches 0 at Level ≥ 2: dialog appears, level −1, EXP = floor of the new level (`(level-1)*100`), HP = full, gold unchanged.
- [ ] At Level 1: HP reaches 0 → EXP reset to 0, level stays 1, HP = full, correct dialog text.
- [ ] Only one demotion per depletion event (no chained level drops).
- [ ] Editing limits in Profile (valid values) updates the bars immediately, persists after restart, and applies only to later expenses; a value below Rp 1.000 or empty shows the validation error and does not save.
- [ ] After the device date moves to the next day: today's spending resets to 0 and hero HP regenerates +25 (capped at max); skipping 2 days gives +50.
- [ ] Resuming the app from background after midnight refreshes the budget bars and regen without restarting.
- [ ] Expense logging, budget penalties, and level-down all work with the adventure complete (no monster heal).

### 12.5. Persistence & Offline
- [ ] After logging transactions, hurting a monster, changing a limit, and claiming a buff, **force-closing and reopening** the app restores everything exactly (monster HP, hero HP, gold, EXP, level, buff, history, today's spending, limits, current monster).
- [ ] Killing the app **while a victory or HP-depleted dialog is open** leaves all consequences applied on relaunch.
- [ ] In **airplane mode from a fresh launch**, Arena, budgets, and Profile work fully and persist; Quest shows the no-internet message with a working **"Coba Lagi"** after reconnecting.
- [ ] A buff claimed online is usable offline and is consumed after a real attack, also after restart.
- [ ] A simulated DB error (temporarily throwing in `persistTurn`) shows the error SnackBar and leaves UI state unchanged (no half-applied HP/level/transaction).
- [ ] Profile totals match the sum of all records even with more than 100 transactions; only the latest 100 are listed.
- [ ] Descriptions containing quotes or SQL characters (e.g. `'; DROP TABLE x; --`) are stored and displayed literally.
- [ ] The database rejects an expense without category and a saving with a category (CHECK constraints).

### 12.6. Daily Mission & Network
- [ ] Headlines load from NewsAPI and render via `ListView.builder`; "[Removed]" items are hidden.
- [ ] Tapping an article opens the reader sheet; the claim button is disabled for 10 seconds with a countdown, then enabled.
- [ ] A claim gives +50 buff and survives a restart; claiming the same article again shows the "sudah diklaim" message.
- [ ] The 4th claim on the same day shows the daily-limit message; after the date changes the quota is available again (claimed URLs stay claimed).
- [ ] Buff never exceeds +150.
- [ ] Wrong API key shows the 401 message; no crash in any network error case.
- [ ] Switching tabs back and forth does NOT trigger a new API request.
- [ ] Articles without images render without errors.

### 12.7. Profile & Formatting
- [ ] Every money value displays like `Rp 10.000`.
- [ ] Dates display in Indonesian (e.g. `14 Okt 2026, 09:30`) with no `LocaleDataException`.
- [ ] Transaction history is newest first, shows category for expenses, shows the empty state initially, and causes no "unbounded height" error.
- [ ] Financial health label matches §7.7 for all three thresholds and the empty state.
- [ ] Budget progress bars are green/orange/red at <80 % / 80–100 % / >100 % of the limit.

---

## 13. Risks, Known Limitations & Open Decisions

**Known limitations**
* No cloud backup or sync: uninstalling the app or clearing its data erases all progress.
* No edit/delete of transactions (a wrong entry cannot be undone because it already affected HP/monster; planned for later).
* The daily quota, budget day boundaries, and HP regeneration rely on the device clock; changing the phone date can bypass them.
* **Users set their own limits, so they can raise a limit to avoid a penalty.** This is a self-discipline app; there is no anti-cheat.
* News content is English (`country=us`); the Quest tab needs internet and has no offline article cache.
* `sqflite` targets Android/iOS only.
* Categories are a fixed list of five (no custom categories).

**Balance risks (tune in `game_rules.dart` after playtesting)**
* 1 HP per Rp 1.000 of overage may feel too harsh or too lenient; at a Rp 50.000 limit, a Rp 100.000 meal costs 50 HP.
* Level-down discards progress inside the current level; if testers find it demotivating, consider keeping a share of EXP.
* Daily regen +25 means about 4 days to fully heal; adjust `dailyHpRegen` if the hero feels permanently weak or invincible.

**Risks if the app is distributed to real users**
* **NewsAPI free (Developer) plan is licensed for development only** and limited to 100 requests/day; real public use needs a paid plan or another news source.
* **An API key passed via `--dart-define` is still embedded in the app binary** and can be extracted. A truly secure setup needs a small backend proxy (out of scope).
* **Course rules:** earlier PRD versions forbade local databases. Confirm with the lecturer that `sqflite` is acceptable before submission.

**Open decisions for the team**
* Should a limit **increase** only take effect from the next day, to reduce "raise the limit to dodge the penalty" behavior?
* Add `url_launcher` so users can open the full article in a browser (currently they read title/description and copy the link)?
* Add a "Reset Data" action with confirmation in Profile?
* Allow the hero name to be edited (currently seeded as "Pahlawan Hemat")?

---

## 14. Suggested Build Order (deadline: mid-to-late December)

Work backwards from the deadline and keep the last 1–2 weeks as buffer for testing and the report.

| Phase | Scope | Priority |
|---|---|---|
| 1 | Project setup, `pubspec`, models (§4), `game_rules.dart` (constants + pure functions), formatters, theme | P0 |
| 2 | `database_helper.dart` (schema, seeding, `loadSnapshot`, `persistTurn`) + `MainNavigationScreen` shell with loading/error states | P0 |
| 3 | Arena: `HeroStatus`, `MonsterDisplay`, `HpBar`, `AttackForm` with category selector; saving + expense callbacks with HP/level-down | P0 |
| 4 | Profile: stats, financial summary, history; budget progress + `BudgetSettingsSheet` | P0 |
| 5 | Quest: `NewsService`, `FutureBuilder`, `NewsCard`, reader sheet, claim logic (`persistArticleClaim`) | P0 |
| 6 | Daily rollover + HP regeneration + app-resume refresh (§6.5), live budget hint in `AttackForm` | P1 |
| 7 | Full acceptance run (§12), airplane-mode and kill-app tests, balance tuning, bug fixes | P0 |
| 8 | Buffer, report, demo script (demo tip: start the demo with a limit you can exceed quickly, e.g. Makan Rp 20.000, to show the HP loss and level-down live) | — |

**Cut list if time runs short (in this order):** app-resume refresh → live budget hint preview → regeneration (replace with full heal on date change) → reading-gate countdown. Do **not** cut persistence, the write-through rule, or the budget/HP core.
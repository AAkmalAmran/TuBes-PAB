# DESIGN.md

Design system for FinQuest: Pahlawan Finansial. All team members must follow this document so the UI stays consistent. If something here conflicts with `PRD.md`, flag it and update both in the same change. Code rules (architecture, naming, language) live in `AGENTS.md`.

## 1. Principles

1. Finance side feels stable and trustworthy: deep green, calm surfaces, clear numbers.
2. Game side feels rewarding: gold for coins, EXP, and buffs, used sparingly so it stays special.
3. Material 3 first. Use standard M3 components and customize through the theme, not per widget.
4. Light and dark themes are both required and share one definition.
5. UI text is Indonesian. Code, identifiers, and comments are English.

## 2. Brand Palette

| Name | Hex | Role |
| --- | --- | --- |
| Forest | `#2F6B3F` | Primary, seed color |
| Sage | `#7FB77E` | Secondary container, neutral status |
| Gold | `#F7C85C` | Tertiary, reward accent |
| Cream | `#FFF6C0` | Quest and victory tint |

Palette source: Color Hunt palette `2f6b3f7fb77ef7c85cfff6c0`.

## 3. Mapping To Material 3

| Palette color | Theme slot | Use for |
| --- | --- | --- |
| Forest `#2F6B3F` | `primary`, and the `seedColor` | Main button (Catat Tabungan), app bar and headers, active tab, FAB, key links |
| Sage `#7FB77E` | `secondaryContainer` | Status chips, monster progress indicator, neutral badges |
| Gold `#F7C85C` | `tertiary` | Gold coin icon, EXP bar, attack buff highlight |
| Cream `#FFF6C0` | Custom `questCard` color (see 5.2) | Quest mission card background, victory dialog accent |

Paired "on" colors (text and icons placed on top):

| Slot | Light mode on-color | Hex |
| --- | --- | --- |
| `primary` | `onPrimary` | `#FFFFFF` |
| `secondaryContainer` | `onSecondaryContainer` | `#102A18` |
| `tertiary` | `onTertiary` | `#3A2A00` |
| Cream `questCard` | `onQuestCard` | `#1B1C18` |

## 4. Contrast Rules (Measured, WCAG)

Ratios below were calculated from the hex values. Normal text needs 4.5:1 or more, large text and UI components need 3:1 or more.

| Pair | Ratio | Verdict |
| --- | --- | --- |
| White on Forest | 6.37 | OK for all text |
| `#102A18` on Sage | 6.57 | OK for all text |
| `#3A2A00` on Gold | 8.85 | OK for all text |
| `#3A2A00` on Cream | 12.70 | OK for all text |
| `#1B1C18` on Cream | 15.66 | OK for all text |
| Forest on Cream | 5.82 | OK for all text |
| Gold on Forest | 4.06 | Large text and icons only |
| White on Sage | 2.34 | FAIL, never use |
| Gold on white | 1.57 | FAIL, never use for text or icons on a light surface |
| Forest on `#121212` | 2.94 | FAIL, do not use raw Forest as primary in dark mode |
| Gold on `#121212` | 11.93 | OK |
| Sage on `#121212` | 8.01 | OK |

Rules that follow from this:
1. Never put white text on Sage. Use `onSecondaryContainer`.
2. Never draw a Gold icon or text directly on a white or light surface. Place it on a dark or Forest background, or put dark text on a Gold fill.
3. Gold on Forest is allowed only for icons and large text (for example a coin icon in the app bar).
4. In dark mode, do not use raw Forest as `primary` (see 5.1).

## 5. Theme Implementation

All theming lives in one file: `lib/theme/app_theme.dart`. No other file may define colors or text styles.

### 5.1 Light and dark schemes

1. Light mode: generate the scheme from the Forest seed, then pin the brand colors so they match the palette exactly.
2. Dark mode: generate the scheme from the same seed and do NOT pin Forest. `fromSeed` produces a lighter green primary that is readable on dark surfaces. Pin only Gold as tertiary, because Gold already has strong contrast on dark.

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const forest = Color(0xFF2F6B3F);
  static const sage = Color(0xFF7FB77E);
  static const gold = Color(0xFFF7C85C);
  static const cream = Color(0xFFFFF6C0);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.forest,
      onPrimary: Colors.white,
      secondaryContainer: AppColors.sage,
      onSecondaryContainer: const Color(0xFF102A18),
      tertiary: AppColors.gold,
      onTertiary: const Color(0xFF3A2A00),
    );
    return _build(scheme, const GameColors.light());
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      brightness: Brightness.dark,
    ).copyWith(
      tertiary: AppColors.gold,
      onTertiary: const Color(0xFF3A2A00),
    );
    return _build(scheme, const GameColors.dark());
  }

  static ThemeData _build(ColorScheme scheme, GameColors game) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[game],
    );
  }
}
```

### 5.2 Game-specific colors (theme extension)

Colors that have no Material slot (quest card, EXP bar, coin) go in a `ThemeExtension`, so widgets never hardcode them.

```dart
@immutable
class GameColors extends ThemeExtension<GameColors> {
  const GameColors({
    required this.questCard,
    required this.onQuestCard,
    required this.expBar,
    required this.coin,
  });

  const GameColors.light()
      : questCard = AppColors.cream,
        onQuestCard = const Color(0xFF1B1C18),
        expBar = AppColors.gold,
        coin = AppColors.gold;

  const GameColors.dark()
      : questCard = const Color(0xFF3A3520),
        onQuestCard = const Color(0xFFF2EBC8),
        expBar = AppColors.gold,
        coin = AppColors.gold;

  final Color questCard;
  final Color onQuestCard;
  final Color expBar;
  final Color coin;

  @override
  GameColors copyWith({
    Color? questCard,
    Color? onQuestCard,
    Color? expBar,
    Color? coin,
  }) {
    return GameColors(
      questCard: questCard ?? this.questCard,
      onQuestCard: onQuestCard ?? this.onQuestCard,
      expBar: expBar ?? this.expBar,
      coin: coin ?? this.coin,
    );
  }

  @override
  GameColors lerp(ThemeExtension<GameColors>? other, double t) {
    if (other is! GameColors) return this;
    return GameColors(
      questCard: Color.lerp(questCard, other.questCard, t)!,
      onQuestCard: Color.lerp(onQuestCard, other.onQuestCard, t)!,
      expBar: Color.lerp(expBar, other.expBar, t)!,
      coin: Color.lerp(coin, other.coin, t)!,
    );
  }
}
```

Access from a widget:

```dart
final game = Theme.of(context).extension<GameColors>()!;
final scheme = Theme.of(context).colorScheme;
```

The dark values for `questCard` and `onQuestCard` above are a proposal (a muted cream-tinted dark). Check them on a device and adjust here only, after agreeing as a team.

### 5.3 Wiring in the app

```dart
MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.system, // or the user's saved choice
  // ...
);
```

## 6. Usage Rules

1. Never write `Color(0xFF...)` or `Colors.xyz` inside a widget. Use `Theme.of(context).colorScheme`, `GameColors`, or `AppColors` only inside `app_theme.dart`.
2. Never hardcode `TextStyle` colors. Use `Theme.of(context).textTheme` and let it inherit the right on-color.
3. Use the semantic slot, not the raw color. Example: `colorScheme.primary`, not `AppColors.forest`.
4. Do not invent new brand colors. If a new color is needed, propose it by editing this file and `app_theme.dart` in the same change.
5. Error states use `colorScheme.error` and `onError`. Do not use gold or sage for errors.
6. Do not rely on color alone to convey meaning (for example overspend vs safe). Add an icon or label.

## 7. Component Guidelines

| Component | Style |
| --- | --- |
| Main button (Catat Tabungan) | `FilledButton`, primary background, `onPrimary` text |
| Secondary action | `OutlinedButton` or `FilledButton.tonal` |
| App bar and headers | Primary or surface per M3 default; title in `onPrimary` when on primary |
| Active tab and nav | Primary indicator per M3 `NavigationBar` and `TabBar` defaults |
| Status chip, neutral badge | `secondaryContainer` background with `onSecondaryContainer` text |
| Monster progress indicator | `secondaryContainer` track with a primary or sage fill, with a visible label |
| EXP bar | `GameColors.expBar` fill on a muted track, with level and XP numbers as text |
| Gold coin icon | `GameColors.coin`, placed on a dark or Forest background only |
| Attack buff badge | Tertiary container with `onTertiary` text |
| Quest mission card | `Card` with `GameColors.questCard` background and `onQuestCard` text |
| Victory dialog | Cream (`questCard`) accent area, Forest title, Gold coin or star icon |
| HP bar | Use `colorScheme.error` shades for low HP so loss reads as a warning, plus numeric HP |

## 8. Typography And Spacing

1. Use M3 `textTheme` roles (`headlineMedium`, `titleMedium`, `bodyMedium`, `labelLarge`). Do not set arbitrary font sizes.
2. Use the default M3 font unless the team agrees on a single custom font; if one is added, register it only in `app_theme.dart`.
3. Spacing uses multiples of 4 (4, 8, 12, 16, 24, 32). Standard screen padding is 16.
4. Money is displayed as `Rp 50.000` (rupiah, `id_ID` locale), right-aligned in lists where practical.
5. Keep touch targets at least 48 by 48 logical pixels.

## 9. Motion And Feedback

1. Game events (XP gain, level up, HP loss, coin earned) get short feedback, 150 to 400 ms, non-blocking.
2. Level up and mission complete may use the victory dialog with the Cream accent. Do not stack multiple dialogs.
3. Respect the system reduce-motion setting where practical.

## 10. States

Every screen must define these states, with short Indonesian copy:

| State | Requirement |
| --- | --- |
| Loading | Progress indicator, UI stays responsive |
| Empty | Friendly message with a next action (for example "Belum ada transaksi. Catat sekarang") |
| Error | Short message plus a retry action, never a stack trace |

## 11. Review Checklist (Before Merging UI Work)

1. No hardcoded colors or text styles in widgets.
2. Looks correct in both light and dark mode.
3. All text and icon pairs meet the contrast table in section 4.
4. Gold is not used on a light surface for text or icons.
5. Loading, empty, and error states exist.
6. UI strings are Indonesian and centralized per `AGENTS.md`.
7. Works at larger text scale without overflow, and on a small phone width.

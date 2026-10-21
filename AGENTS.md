# AGENTS.md

## Section 1: Agent Operational Workflow

### 1.1 Startup Workflow
Before writing any code, the agent must complete these steps:
1. Confirm the working directory using `pwd`.
2. Read `progress.md` for the latest verified state and the next required step.
3. Read `feature_list.json` and select the highest-priority unfinished feature.
4. Review recent repository history by checking the last 5 commits using `git log --oneline -5`.
5. Run the initialization script via `./init.sh` (runs `flutter pub get`, `flutter analyze`, and `flutter test`).
6. Run the required smoke verification before starting new work. If baseline verification fails, fix that issue first before stacking new feature work on top of a broken starting state.

### 1.2 Working Rules
1. Focus entirely on one feature at a time.
2. Do not mark a feature complete just because code was added.
3. Keep all changes within the selected feature scope unless a critical blocker forces a narrow supporting fix.
4. Do not silently alter verification rules during implementation.
5. Prefer durable repository artifacts over transient chat summaries.
6. `PRD.md` is the product source of truth. If a requested change conflicts with it, flag the conflict and propose a PRD update instead of silently diverging.

### 1.3 Required Artifacts
1. `feature_list.json`: The absolute source of truth for tracking feature states.
2. `progress.md`: The continuous session log and current verified status.
3. `init.sh`: The standardized repository startup and verification path.
4. `session-handoff.md`: An optional, compact handoff document reserved for larger development sessions.

### 1.4 Definition Of Done
A feature achieves the status of completed only when all of the following conditions are met:
1. The target behavior is fully implemented.
2. `flutter analyze` reports no issues and `flutter test` passes.
3. The feature has been run on an emulator or device, and direct evidence of verification is explicitly recorded in `feature_list.json` or `progress.md`.
4. The repository remains completely restartable from the standard startup path using `./init.sh`.

### 1.5 End Of Session Workflow
Before ending a session, the agent must perform these tasks:
1. Update the contents of `progress.md`.
2. Update the tracking states within `feature_list.json`.
3. Explicitly record any unresolved risk, technical debt, or workflow blocker.
4. Commit the changes with a descriptive message adhering to the Conventional Commits specification once the work is in a safe state.
5. Leave the repository clean enough for the next session to execute `./init.sh` immediately.

## Section 2: General Project Rules

### 2.1 Framework & Stack
1. This project is a Flutter mobile app, "FinQuest: Pahlawan Finansial", a gamified personal finance tracker built as a team final project (Tugas Besar).
2. Core stack: Flutter, `provider` (ChangeNotifier) for state management, `sqflite` + `path` for local storage, `http` for networking, and `intl` for number and date formatting.
3. Online data: NewsAPI is used for the daily mission of reading articles. Authentication and the main-feature data source follow the current PRD (API or Firebase, as decided there).
4. Do not add packages beyond those required by `PRD.md` and the lecturer's rubric (for example secure token storage and local notifications) without explicit approval.

### 2.2 Privacy & Security
1. Do not hardcode personal user data in the source code, comments, test fixtures, or documentation. Use generic names (for example "Test User", "test@example.com").
2. API keys (NewsAPI and any backend keys) must never appear in source code. Inject them at build time (for example `--dart-define`) or load them from an untracked config file, and add placeholder entries to a committed example file immediately.
3. Authentication tokens must be stored with secure storage, never in plain `SharedPreferences`, SQLite, or logs.
4. Use parameterized queries (`whereArgs`, `?` placeholders) for every SQLite statement. Never build SQL by string interpolation of user input.
5. Do not log tokens, passwords, or full API responses containing user data.

### 2.3 Language & Naming Conventions
1. All code (identifiers, files, classes, database tables and columns, comments) must be in English.
2. All user-facing UI text must be in Indonesian. Keep UI strings centralized (for example a single constants file) so they are easy to review and change.
3. Money is stored as integer rupiah (never `double`). Format for display only, via `intl` with the `id_ID` locale (for example `Rp 50.000`).
4. Dart naming: `UpperCamelCase` for types, `lowerCamelCase` for members, `snake_case` for file names and database columns.

### 2.4 Authentication & Access
1. The app requires login. Unauthenticated users must only reach the login (and registration, if present) screens.
2. The session token is read at startup to decide the initial route, and is cleared completely on logout.
3. Expired or invalid tokens must route the user back to login with a clear Indonesian message, not crash or show a blank screen.

### 2.5 Game Domain Rules
1. The hero has a level, XP, and HP. Finance activity drives game progress: logging transactions and completing the daily mission earn XP, and overspending reduces HP.
2. Users define daily spending limits per category (for example food max Rp 50.000 per day). Exceeding a limit reduces hero HP.
3. When HP reaches 0, the hero's level drops by one and HP is restored according to the PRD.
4. Game rules (XP amounts, HP penalties, level thresholds) live in one place in the domain layer, not scattered across widgets. Treat the PRD as the authority for the exact numbers.
5. Transactions carry a category. Budgets are stored in their own table keyed by category.

### 2.6 Core User Flow (Final Demo Rubric)
The final demo must work end to end in this order: login, list, detail, add, edit, delete, local notification.
1. All main features must read and write real data through the API or Firebase, with login and a securely stored token.
2. Full CRUD (create, read, update, delete) must be available for the main entity, including edit and delete.
3. Local notifications must be triggered by a meaningful event (for example a daily mission reminder or a budget warning).
4. Every screen must handle loading, empty, and error states explicitly.

### 2.7 Offline-First Behavior
1. Finance records and game progress are stored locally in SQLite and must remain usable without a network connection.
2. The network is required only for authentication, the NewsAPI daily mission, and any data the PRD assigns to the backend. Network failures must degrade gracefully with a user-friendly Indonesian message.
3. Never block the main UI thread on database or network work. Use `async`/`await` and show loading states.

### 2.8 Aesthetics & UI
1. Use Material 3 with a consistent theme defined in one place. Provide both light and dark themes, with the choice applied app-wide.
2. Never hardcode colors or text styles inside widgets. Read them from `Theme.of(context)` or from the shared theme definition.
3. Keep layouts responsive across common phone sizes and handle text scaling without overflow.
4. Add subtle, purposeful feedback for game events (XP gain, level up, HP loss), and keep animations short and non-blocking.

## Section 3: Technical & Data Specifications

### 3.1 Architecture (Layered)
1. Follow the layered architecture taught in the course: `models`, `services` (API and database access), `providers` (ChangeNotifier stores), and `screens`/`widgets` (UI only).
2. Widgets must not call `sqflite` or `http` directly. They read state from the provider and call store methods.
3. State management uses `ChangeNotifier` with `provider`. The single `GameStore` owns game and finance state, and widgets rebuild through `context.watch`, `context.select`, or `Consumer`. Use `context.read` for one-off actions in callbacks.
4. Business logic (XP, HP, budget checks) must live in the store or domain classes so it can be unit tested without a widget tree.

### 3.2 Database Schema & Migrations
1. The database is versioned through `sqflite` `onCreate` and `onUpgrade`. The budgets table and hero HP arrived with database version 2, so upgrade paths must preserve existing user data.
2. Never edit a released migration step. Add a new version with its own upgrade logic.
3. Wrap multi-statement mutations (for example saving a transaction, applying HP loss, and updating level) in a single `db.transaction(...)`.
4. Keep table and column names in English `snake_case`, and define them as constants rather than repeated string literals.

### 3.3 Structured Error Handling
1. Catch exceptions at the service boundary and convert them into typed failures or clear results. Do not let raw exceptions reach widgets.
2. Log caught errors with enough context (operation name and relevant ids) using `debugPrint` or a logger, without sensitive data.
3. Surface errors to the user as short Indonesian messages, never as stack traces.

### 3.4 Testing
1. Unit-test game rules (XP, HP loss, level drop at 0 HP, budget overspend detection) and store logic.
2. Test database services against an in-memory or temporary database, including the version 1 to version 2 migration.
3. Add widget tests for the login screen and for the list, add, edit, and delete flow of the main entity.
4. All new features must include tests for their core rules, and `flutter test` must pass before a feature is marked complete.

### 3.5 Networking
1. All HTTP calls go through a single service layer with timeouts and consistent error mapping.
2. Parse JSON into typed models. Never pass raw `Map<String, dynamic>` into the UI.
3. Cache what the offline-first design requires (for example today's mission state) locally so the app does not re-fetch needlessly.

## Section 4: Development, Coding, & DevOps Best Practices

### 4.1 Code Modularity
1. Keep widgets small and focused. Extract a widget when a `build` method grows past roughly 100 lines or when a block is reused.
2. Prefer `const` constructors and widgets wherever possible.
3. Avoid business logic in `build`. Compute derived values in the store or in small helpers.
4. One public class per file for screens, stores, and services, with file names matching the class in `snake_case`.

### 4.2 Environment Variables & Secrets
1. Never commit real keys, tokens, signing keystores, or `key.properties`. Verify they are listed in `.gitignore`.
2. When introducing a new configuration value, add a placeholder entry to the committed example config in the same change.

### 4.3 Coding Standards & Formatting
1. Run `dart format` and keep `flutter analyze` clean. Follow the lints configured in `analysis_options.yaml`.
2. Use 2 spaces for indentation in Dart, YAML, and Markdown.
3. Use explicit types on public APIs, prefer `final`, and avoid `dynamic` and force-unwrapping (`!`) unless the invariant is documented.
4. Always check `mounted` before using a `BuildContext` after an `await`.
5. Dispose controllers, focus nodes, and subscriptions in `dispose`.

### 4.4 Dependency Management
1. Avoid installing external packages unless explicitly requested or absolutely necessary. Rely on Flutter, the Dart SDK, and the packages already listed in the PRD.
2. When dependencies are added or updated, commit `pubspec.yaml` and `pubspec.lock` together.
3. Check that a new package supports the project's Flutter and Dart SDK versions and works on Android before adding it.

### 4.5 Release & Distribution
1. A signed release build must be produced and distributed (Google Play testing track or a lecturer-approved alternative).
2. Release builds use code obfuscation and split debug info (`flutter build apk --release --obfuscate --split-debug-info=<dir>` or the equivalent app bundle command). Keep the debug-info directory out of the repository but retained for stack trace symbolication.
3. Signing configuration is read from untracked files. Never commit keystores or passwords.
4. Verify the release build on a real device before the demo: login, the full CRUD flow, and the local notification.

### 4.6 Git Commit Conventions
1. All git commit messages generated by the agent must strictly follow the Conventional Commits specification (for example `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`).
2. Keep commits small and scoped to one feature or fix. Do not mix refactors with feature work.

### 4.7 Workflow Instructions
1. Assume the project is developed on a local Flutter SDK with an Android emulator or a physical device. Propose commands such as `flutter run`, `flutter analyze`, and `flutter test` explicitly.
2. Avoid proposing `sudo` or interactive command prompts unless requested.
3. Documentation style: Do NOT use emojis in code, commit messages, or documentation. Technical guides must provide complete, end-to-end steps for both setup and usage.
4. When the PRD and the code disagree, update the PRD in the same change, or record the discrepancy in `claude-progress.md` so the team report stays accurate.
5. Remember the project deadline is mid-to-late December 2026. Prefer finishing the rubric-required flow over adding optional features.

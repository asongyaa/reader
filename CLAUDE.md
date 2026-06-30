# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Anx Reader is a cross-platform ebook reader built with Flutter. It uses a WebView-based renderer (`assets/foliate-js`, forked from [foliate-js](https://github.com/johnfactotum/foliate-js)) for EPUB/MOBI/AZW3/FB2/TXT/PDF content, with Dart-side state management via Riverpod and SQLite for local persistence.

Target Flutter version is pinned in `.github/flutter-version` (currently `3.35.3`).

## Common Commands

### Setup and Code Generation

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
```

`flutter gen-l10n` generates `lib/l10n/generated/L10n.dart`.
`build_runner` generates Riverpod providers (`.g.dart`), Freezed models, and JSON serializers.

### Running the App

```bash
flutter run
```

### Lint and Test

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

Run a single test file:

```bash
flutter test test/service/convert_to_epub/txt/convert_from_txt_test.dart
```

Run a single test:

```bash
flutter test test/service/convert_to_epub/txt/convert_from_txt_test.dart --name "matches headings with trailing ASCII whitespace"
```

### Build Commands

Debug builds:

```bash
flutter build apk --debug
flutter build ios --debug
flutter build macos --debug
flutter build windows --debug
```

Release builds:

```bash
flutter build apk --release
flutter build ios --release
flutter build macos --release
flutter build windows --release
```

Platform-specific release variants (e.g., Android App Bundle, split per ABI):

```bash
flutter build appbundle --release
flutter build apk --release --split-per-abi
```

## Core Code Locations by Module

| Module | Core Files |
|--------|------------|
| **Reader Core** | `lib/page/book_player/epub_player.dart` (WebView/JS bridge), `lib/page/reading_page.dart` (reader page shell) |
| **Bookshelf / Book Management** | `lib/page/home_page/bookshelf_page.dart`, `lib/service/book.dart`, `lib/providers/book_list.dart`, `lib/dao/book.dart` |
| **Recent Reading** | `lib/page/home_page/recent_page.dart` |
| **Notes** | `lib/page/home_page/notes_page.dart`, `lib/page/book_notes_page.dart`, `lib/service/notes/`, `lib/dao/book_note.dart` |
| **Reading Statistics** | `lib/page/home_page/statistics_page.dart`, `lib/widgets/statistic/`, `lib/providers/statistic_data.dart` |
| **My / Settings** | `lib/page/home_page/my_page.dart`, `lib/page/settings_page/`, `lib/config/shared_preference_provider.dart` |
| **TTS** | `lib/service/tts/tts_handler.dart`, `lib/service/tts/tts_engine_adapter.dart`, `lib/service/tts/tts_factory.dart`, `lib/widgets/reading_page/tts_player_sheet.dart` |
| **Search** | `lib/page/search/search_page.dart`, `lib/providers/search.dart` |
| **Import / Format Conversion** | `lib/service/book.dart` → `importBookList`, `lib/service/convert_to_epub/` |
| **Sync** | `lib/service/sync/`, `lib/providers/sync.dart` |
| **Database / Persistence** | `lib/dao/database.dart`, `lib/dao/*.dart`, `lib/models/` |
| **Themes / Styles** | `lib/models/read_theme.dart`, `lib/models/book_style.dart`, `lib/config/shared_preference_provider.dart` |
| **Localization** | `lib/l10n/` (ARB), `lib/l10n/generated/L10n.dart` |

## High-Level Architecture

### UI Layer

- `lib/page/` contains top-level pages. `lib/page/home_page.dart` is the main shell with bottom navigation. `lib/page/reading_page.dart` hosts the reader.
- `lib/widgets/` contains reusable widgets organized by feature (`widgets/reading_page/`, `widgets/bookshelf/`, etc.).
- `lib/page/book_player/epub_player.dart` is the core reader widget. It embeds an `InAppWebView` that loads `assets/foliate-js/index.html` served by a local `shelf` server (`lib/service/book_player/book_player_server.dart`).

### State Management

- Uses `flutter_riverpod` with code generation (`@Riverpod`, `@riverpod`). Generated files end in `.g.dart`.
- Global providers live in `lib/providers/`.
  - `current_reading.dart` tracks the active book, chapter, CFI, and page progress.
  - `book_list.dart` manages the grouped bookshelf list.
  - `sync.dart` drives WebDAV sync.
- `lib/main.dart` initializes the database, preferences, local server, and `AudioService` before calling `runApp` with `ProviderScope`.

### Book Rendering (foliate-js Bridge)

- `EpubPlayerState` (`lib/page/book_player/epub_player.dart`) owns the `InAppWebViewController` and exposes methods such as `goToPercentage`, `goToChapterFraction`, `ttsNext`, `ttsPrev`, `ttsCurrentDetail`, and selection/highlight APIs.
- JS-to-Dart communication uses `callAsyncJavaScript` for return values and `addJavaScriptHandler` for events.
- `assets/foliate-js/` is vendored. Avoid modifying it unless the change is intentional and tracked separately.

### Persistence

- SQLite via `sqflite` / `sqflite_common_ffi`.
- `lib/dao/` contains data access objects (`book.dart`, `book_note.dart`, `reading_time.dart`, etc.).
- `lib/dao/database.dart` defines schema, migrations, and `currentDbVersion`.
- `lib/models/` contains data models, many generated with Freezed/JSON serializable.

### TTS System

- `lib/service/tts/tts_handler.dart` is a singleton `BaseAudioHandler` registered with `AudioService` in `main.dart`.
- `lib/service/tts/base_tts.dart` defines the abstract TTS interface.
- `lib/service/tts/tts_engine_adapter.dart` wraps `TtsEngine` implementations and drives sentence chaining.
- `lib/service/tts/tts_factory.dart` creates engine instances (system, Edge, Azure, Sherpa ONNX).
- `lib/widgets/reading_page/tts_player_sheet.dart` is the TTS UI bottom sheet.

### Book Import Pipeline

- `lib/service/book.dart` → `importBookList` handles file picking, MD5 duplicate detection, unsupported file reporting, and final import.
- Non-EPUB formats are converted to EPUB first:
  - TXT → EPUB via `lib/service/convert_to_epub/txt/convert_from_txt.dart`.
  - MOBI/AZW3/FB2/PDF conversions live under `lib/service/convert_to_epub/`.
- Imported files are copied into the app’s base path and their metadata is inserted via `lib/dao/book.dart`.

### Sync

- WebDAV sync is implemented in `lib/service/sync/` and triggered from `lib/providers/sync.dart`.
- Sync runs automatically on app lifecycle pause/hidden when `Prefs().webdavStatus` is enabled.

### Configuration and Preferences

- `lib/config/shared_preference_provider.dart` exposes `Prefs()`, a singleton backed by `SharedPreferences`.
- Reading themes, fonts, and book styles are persisted partly in SQLite and partly in shared preferences.

### Localization

- ARB files are in `lib/l10n/`.
- Generated class is `lib/l10n/generated/L10n.dart`.
- Use `L10n.of(context).keyName` for user-facing strings.

## Important Notes from README

- Supported formats: EPUB, MOBI, AZW3, FB2, TXT, PDF.
- Platforms: Android, iOS, macOS, Windows.
- License history: MIT → GPLv3 (from v1.1.4) → MIT again (from v1.2.6 after rewriting selection/highlight).
- The selection and highlight feature was rewritten in/after v1.2.6 and no longer derives from the GPL-3.0 `foliate` project.
- foliate-js (MIT) is used as the ebook renderer and lives under `assets/foliate-js/`.

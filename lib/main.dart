import 'dart:io';

import 'package:anx_reader/utils/platform_utils.dart';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/database.dart';
import 'package:anx_reader/enums/sync_direction.dart';
import 'package:anx_reader/enums/sync_trigger.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/home_page.dart';
import 'package:anx_reader/page/migration_page.dart';
import 'package:anx_reader/service/book_player/book_player_server.dart';
import 'package:anx_reader/service/network/http_proxy_overrides.dart';
import 'package:anx_reader/service/tts/tts_handler.dart';
import 'package:anx_reader/utils/get_path/macos_migration.dart';
import 'package:anx_reader/utils/color_scheme.dart';
import 'package:anx_reader/utils/error/common.dart';
import 'package:anx_reader/utils/get_path/get_base_path.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:anx_reader/providers/sync.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:heroine/heroine.dart';
import 'package:provider/provider.dart' as provider;

final navigatorKey = GlobalKey<NavigatorState>();
late AudioHandler audioHandler;
final heroineController = HeroineController();

/// Whether macOS data migration is needed (checked at startup)
bool _needsMigration = false;
MigrationCheckResult? _migrationCheckResult;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs().initPrefs();
  HttpOverrides.global = AnxHttpProxyOverrides();

  // Initialize desktop window with validated position (desktop only)
  if (AnxPlatform.isWindows || AnxPlatform.isMacOS) {
    initBasePath();
    AnxLog.init();
  }

  // Check if migration is needed before initializing paths
  if (AnxPlatform.isMacOS) {
    _migrationCheckResult = await checkMigrationNeeded();
    _needsMigration = _migrationCheckResult?.needsMigration ?? false;
  }

  // If no migration needed, initialize paths normally
  if (!_needsMigration) {
    initBasePath();
    AnxLog.init();
    AnxError.init();
    await DBHelper().initDB();
  }

  Server().start();

  audioHandler = await AudioService.init(
    builder: () => TtsHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.anx.reader.tts.channel.audio',
      androidNotificationChannelName: 'ANX Reader TTS',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  SmartDialog.config.custom = SmartConfigCustom(
    maskColor: Colors.black.withAlpha(35),
    useAnimation: true,
    animationType: SmartAnimationType.centerFade_otherSlide,
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  static const Locale _englishFallbackLocale = Locale('en');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (Prefs().webdavStatus) {
        ref
            .read(syncProvider.notifier)
            .syncData(SyncDirection.both, ref, trigger: SyncTrigger.auto);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (AnxPlatform.isIOS) {
        Server().start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return provider.MultiProvider(
      providers: [
        provider.ChangeNotifierProvider(
          create: (_) => Prefs(),
        ),
      ],
      child: provider.Consumer<Prefs>(
        builder: (context, prefsNotifier, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            scrollBehavior: ScrollConfiguration.of(context).copyWith(
              physics: const BouncingScrollPhysics(),
              // dragDevices: {
              //   PointerDeviceKind.touch,
              //   PointerDeviceKind.mouse,
              // },
            ),
            navigatorObservers: [
              FlutterSmartDialog.observer,
              heroineController
            ],
            builder: FlutterSmartDialog.init(),
            navigatorKey: navigatorKey,
            locale: prefsNotifier.locale,
            localeListResolutionCallback: _resolveLocale,
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            title: 'Anx Reader',
            themeMode: prefsNotifier.themeMode,
            theme: colorSchema(prefsNotifier, context, Brightness.light),
            darkTheme: colorSchema(prefsNotifier, context, Brightness.dark),
            home: _needsMigration
                ? _MigrationWrapper(
                    migrationCheckResult: _migrationCheckResult!)
                : const HomePage(),
          );
        },
      ),
    );
  }

  Locale _resolveLocale(
    List<Locale>? preferredLocales,
    Iterable<Locale> supportedLocales,
  ) {
    if (preferredLocales == null || preferredLocales.isEmpty) {
      return _englishFallbackLocale;
    }

    final Locale resolvedLocale = basicLocaleListResolution(
      preferredLocales,
      supportedLocales,
    );

    final bool hasMatch = preferredLocales.any((Locale preferredLocale) {
      return supportedLocales.any((Locale supportedLocale) {
        if (preferredLocale.languageCode != supportedLocale.languageCode) {
          return false;
        }

        final String? preferredCountryCode = preferredLocale.countryCode;
        final String? supportedCountryCode = supportedLocale.countryCode;

        return preferredCountryCode == null ||
            supportedCountryCode == null ||
            preferredCountryCode == supportedCountryCode;
      });
    });

    return hasMatch ? resolvedLocale : _englishFallbackLocale;
  }
}

/// Widget that wraps the migration flow on macOS.
/// Shows MigrationPage during migration, then navigates to HomePage.
class _MigrationWrapper extends StatefulWidget {
  final MigrationCheckResult migrationCheckResult;

  const _MigrationWrapper({required this.migrationCheckResult});

  @override
  State<_MigrationWrapper> createState() => _MigrationWrapperState();
}

class _MigrationWrapperState extends State<_MigrationWrapper> {
  bool _migrationComplete = false;

  Future<void> _onMigrationComplete() async {
    // Initialize paths and DB after migration
    initBasePath();
    AnxLog.init();
    AnxError.init();
    await DBHelper().initDB();

    if (mounted) {
      setState(() {
        _migrationComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_migrationComplete) {
      return const HomePage();
    }
    return MigrationPage(onMigrationComplete: _onMigrationComplete);
  }
}

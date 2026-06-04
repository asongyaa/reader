import 'package:anx_reader/dao/database.dart';
import 'package:anx_reader/enums/sync_direction.dart';
import 'package:anx_reader/enums/sync_trigger.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/initialization_check.dart';
import 'package:anx_reader/page/home_page/bookshelf_page.dart';
import 'package:anx_reader/page/home_page/my_page.dart';
import 'package:anx_reader/page/home_page/recent_page.dart';
import 'package:anx_reader/service/receive_file/receive_share.dart';
import 'package:anx_reader/service/vibration_service.dart';
import 'package:anx_reader/utils/check_update.dart';
import 'package:anx_reader/utils/get_path/get_temp_dir.dart';
import 'package:anx_reader/utils/load_default_font.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:anx_reader/utils/platform_utils.dart';
import 'package:anx_reader/providers/sync.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';

WebViewEnvironment? webViewEnvironment;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _currentTab = 'recent';

  bool? _expanded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => initAnx());
  }

  Future<void> _checkWindowsWebview() async {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
    AnxLog.info('WebView2 version: $availableVersion');

    if (availableVersion == null) {
      SmartDialog.show(
        builder: (context) => AlertDialog(
          title: const Icon(Icons.error),
          content: Text(L10n.of(context).webview2NotInstalled),
          actions: [
            TextButton(
              onPressed: () => {
                launchUrl(
                    Uri.parse(
                        'https://developer.microsoft.com/en-us/microsoft-edge/webview2'),
                    mode: LaunchMode.externalApplication)
              },
              child: Text(L10n.of(context).webview2Install),
            ),
          ],
        ),
      );
    } else {
      webViewEnvironment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
            userDataFolder: (await getAnxTempDir()).path),
      );
    }
  }

  void _showDbUpdatedDialog() {
    SmartDialog.show(
      clickMaskDismiss: false,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).commonAttention),
        content: Text(L10n.of(context).dbUpdatedTip),
        actions: [
          TextButton(
            onPressed: () {
              SmartDialog.dismiss();
            },
            child: Text(L10n.of(context).commonOk),
          ),
        ],
      ),
    );
  }

  Future<void> initAnx() async {
    AnxToast.init(context);
    checkUpdate(false);
    InitializationCheck.check();
    if (Prefs().webdavStatus) {
      await Sync().init();
      await Sync().syncData(SyncDirection.both, ref, trigger: SyncTrigger.auto);
    }
    loadDefaultFont();

    if (AnxPlatform.isWindows) {
      await _checkWindowsWebview();
    }

    if (AnxPlatform.isAndroid || AnxPlatform.isIOS || AnxPlatform.isOhos) {
      receiveShareIntent(ref);
    }

    if (DBHelper.updatedDB) {
      _showDbUpdatedDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> navBarItems = [
      {
        'icon': Icons.history,
        'label': '最近',
        'identifier': 'recent'
      },
      {
        'icon': EvaIcons.book_open,
        'label': L10n.of(context).navBarBookshelf,
        'identifier': 'bookshelf'
      },
      {
        'icon': Icons.person_outline,
        'label': '我的',
        'identifier': 'my'
      },
    ];

    int currentIndex = navBarItems
        .indexWhere((element) => element['identifier'] == _currentTab);
    if (currentIndex == -1) {
      currentIndex = 0;
      _currentTab = 'bookshelf';
    }

    Widget pages(
      int index,
      BoxConstraints constraints,
      ScrollController? controller,
    ) {
      final page = [
        RecentPage(controller: controller),
        BookshelfPage(controller: controller),
        MyPage(controller: controller),
      ];
      return page[index];
    }

    void onBottomTap(int index, bool fromRail) {
      VibrationService.heavy();
      setState(() {
        _currentTab = navBarItems[index]['identifier'];
      });
    }

    List<NavigationRailDestination> railBarItems = navBarItems.map((item) {
      return NavigationRailDestination(
        icon: Icon(item['icon'] as IconData),
        label: Text(item['label'] as String),
      );
    }).toList();

    List<BottomNavigationBarItem> bottomBarItems = navBarItems.map((item) {
      return BottomNavigationBarItem(
        icon: Icon(item['icon'] as IconData),
        label: item['label'] as String,
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        _expanded ??= constraints.maxWidth > 1000;
        if (constraints.maxWidth > 600) {
          return Scaffold(
            extendBody: true,
            body: Row(
              children: [
                SafeArea(
                  bottom: false,
                  child: FilledContainer(
                    margin: const EdgeInsets.all(16),
                    color: ElevationOverlay.applySurfaceTint(
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.primary,
                      3,
                    ),
                    radius: 20,
                    child: SafeArea(
                      child: NavigationRail(
                        groupAlignment: 1,
                        extended: false,
                        selectedIndex: currentIndex,
                        onDestinationSelected: (int index) =>
                            onBottomTap(index, true),
                        destinations: railBarItems,
                        labelType: NavigationRailLabelType.all,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
                Expanded(child: pages(currentIndex, constraints, null)),
              ],
            ),
          );
        } else {
          return Scaffold(
            extendBody: true,
            body: pages(currentIndex, constraints, null),
            bottomNavigationBar: BottomNavigationBar(
              selectedFontSize: 12,
              enableFeedback: true,
              type: BottomNavigationBarType.fixed,
              landscapeLayout:
                  BottomNavigationBarLandscapeLayout.linear,
              currentIndex: currentIndex,
              onTap: (int index) => onBottomTap(index, false),
              items: bottomBarItems,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
          );
        }
      },
    );
  }
}

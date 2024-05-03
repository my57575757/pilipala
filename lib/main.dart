import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/common/widgets/custom_toast.dart';
import 'package:pilipala/http/init.dart';
import 'package:pilipala/models/common/color_type.dart';
import 'package:pilipala/models/common/theme_type.dart';
import 'package:pilipala/pages/search/index.dart';
import 'package:pilipala/pages/video/detail/index.dart';
import 'package:pilipala/router/app_pages.dart';
import 'package:pilipala/pages/main/view.dart';
import 'package:pilipala/services/disable_battery_opt.dart';
import 'package:pilipala/services/service_locator.dart';
import 'package:pilipala/utils/app_scheme.dart';
import 'package:pilipala/utils/data.dart';
import 'package:pilipala/utils/global_data.dart';
import 'package:pilipala/utils/storage.dart';
import 'package:media_kit/media_kit.dart'; // Provides [Player], [Media], [Playlist] etc.
import 'package:pilipala/utils/recommend_filter.dart';
import 'package:catcher_2/catcher_2.dart';
import './services/loggeer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown])
      .then((_) async {
    await GStrorage.init();
    await setupServiceLocator();
    clearLogs();
    Request();
    await Request.setCookie();
    RecommendFilter();

    // 异常捕获 logo记录
    final Catcher2Options debugConfig = Catcher2Options(
      SilentReportMode(),
      [
        FileHandler(await getLogsPath()),
        ConsoleHandler(
          enableDeviceParameters: false,
          enableApplicationParameters: false,
        )
      ],
    );

    final Catcher2Options releaseConfig = Catcher2Options(
      SilentReportMode(),
      [FileHandler(await getLogsPath())],
    );

    Catcher2(
      debugConfig: debugConfig,
      releaseConfig: releaseConfig,
      runAppFunction: () {
        runApp(const MyApp());
      },
    );

    // 小白条、导航栏沉浸
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 29) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
      ));
    }

    Data.init();
    GlobalData();
    PiliSchame.init();
    DisableBatteryOpt();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Box setting = GStrorage.setting;
    // 主题色
    Color defaultColor =
        colorThemeTypes[setting.get(SettingBoxKey.customColor, defaultValue: 0)]
            ['color'];
    Color brandColor = defaultColor;
    // 主题模式
    ThemeType currentThemeValue = ThemeType.values[setting
        .get(SettingBoxKey.themeMode, defaultValue: ThemeType.system.code)];
    // 是否动态取色
    bool isDynamicColor =
        setting.get(SettingBoxKey.dynamicColor, defaultValue: true);
    // 字体缩放大小
    double textScale =
        setting.get(SettingBoxKey.defaultTextScale, defaultValue: 1.0);

    // 强制设置高帧率
    if (Platform.isAndroid) {
      try {
        late List modes;
        FlutterDisplayMode.supported.then((value) {
          modes = value;
          var storageDisplay = setting.get(SettingBoxKey.displayMode);
          DisplayMode f = DisplayMode.auto;
          if (storageDisplay != null) {
            f = modes.firstWhere((e) => e.toString() == storageDisplay);
          }
          DisplayMode preferred = modes.toList().firstWhere((el) => el == f);
          FlutterDisplayMode.setPreferredMode(preferred);
        });
      } catch (_) {}
    }

    return DynamicColorBuilder(
      builder: ((ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme? lightColorScheme;
        ColorScheme? darkColorScheme;
        if (lightDynamic != null && darkDynamic != null && isDynamicColor) {
          // dynamic取色成功
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          // dynamic取色失败，采用品牌色
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: brandColor,
            brightness: Brightness.light,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: brandColor,
            brightness: Brightness.dark,
          );
        }

        // ThemeData themeData = ThemeData(
        //   colorScheme: currentThemeValue == ThemeType.dark
        //       ? darkColorScheme
        //       : lightColorScheme,
        // );

        // // 小白条、导航栏沉浸
        // if (Platform.isAndroid) {
        //   List<String> versionParts = Platform.version.split('.');
        //   int androidVersion = int.parse(versionParts[0]);
        //   if (androidVersion >= 29) {
        //     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        //   }
        //   SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        //     systemNavigationBarColor: GlobalData().enableMYBar
        //         ? const Color(0x00010000)
        //         : themeData.canvasColor,
        //     systemNavigationBarDividerColor: GlobalData().enableMYBar
        //         ? const Color(0x00010000)
        //         : themeData.canvasColor,
        //     systemNavigationBarIconBrightness:
        //         currentThemeValue == ThemeType.dark
        //             ? Brightness.light
        //             : Brightness.dark,
        //     statusBarColor: Colors.transparent,
        //   ));
        // }

        // 图片缓存
        // PaintingBinding.instance.imageCache.maximumSizeBytes = 1000 << 20;
        return GetMaterialApp(
          title: 'PiliPala',
          theme: ThemeData(
            colorScheme: currentThemeValue == ThemeType.dark
                ? darkColorScheme
                : lightColorScheme,
            snackBarTheme: SnackBarThemeData(
              actionTextColor: lightColorScheme.primary,
              backgroundColor: lightColorScheme.secondaryContainer,
              closeIconColor: lightColorScheme.secondary,
              contentTextStyle: TextStyle(color: lightColorScheme.secondary),
              elevation: 20,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: ZoomPageTransitionsBuilder(
                  allowEnterRouteSnapshotting: false,
                ),
              },
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: currentThemeValue == ThemeType.light
                ? lightColorScheme
                : darkColorScheme,
            snackBarTheme: SnackBarThemeData(
              actionTextColor: darkColorScheme.primary,
              backgroundColor: darkColorScheme.secondaryContainer,
              closeIconColor: darkColorScheme.secondary,
              contentTextStyle: TextStyle(color: darkColorScheme.secondary),
              elevation: 20,
            ),
          ),
          localizationsDelegates: const [
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          locale: const Locale("zh", "CN"),
          supportedLocales: const [Locale("zh", "CN"), Locale("en", "US")],
          fallbackLocale: const Locale("zh", "CN"),
          getPages: Routes.getPages,
          home: const MainApp(),
          builder: (BuildContext context, Widget? child) {
            return FlutterSmartDialog(
              toastBuilder: (String msg) => CustomToast(msg: msg),
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
            );
          },
          navigatorObservers: [
            VideoDetailPage.routeObserver,
            SearchPage.routeObserver,
          ],
        );
      }),
    );
  }
}

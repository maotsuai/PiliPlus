import 'dart:io';

import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/bili_theme.dart';
import 'package:PiliPlus/common/widgets/floating_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/main_layout.dart';
import 'package:PiliPlus/common/widgets/route_aware_mixin.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/services/bili_theme_service.dart';
import 'package:PiliPlus/utils/android/bindings.g.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/desktop/tray_controller.dart';
import 'package:PiliPlus/utils/desktop/window_controller.dart';
import 'package:PiliPlus/utils/extension/context_ext.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/mobile_observer.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nativeapi/nativeapi.dart' as nativeapi;

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends PopScopeState<MainApp>
    with RouteAware, RouteAwareMixin, WidgetsBindingObserver {
  final _mainController = Get.put(MainController());
  late EdgeInsets _padding;
  late ColorScheme _colorScheme;
  Brightness? _brightness;

  @override
  bool get initCanPop => false;

  @override
  void initState() {
    super.initState();
    addObserverMobile(this);
    if (Platform.isMacOS) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
    if (PlatformUtils.isDesktop) {
      WindowController.instance.init();
      TrayController.instance.init();
    }
    if (!Platform.isMacOS) {
      PiliScheme.init();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _padding = MediaQuery.viewPaddingOf(context);
    _colorScheme = ColorScheme.of(context);
    final brightness = _colorScheme.brightness;
    NetworkImgLayer.reduce =
        NetworkImgLayer.reduceLuxColor != null && brightness.isDark;
    if (PlatformUtils.isDesktop) {
      if (_brightness != brightness) {
        _brightness = brightness;
        nativeapi.Application.instance.setBrightness(
          brightness == .dark ? .dark : .light,
        );
      }
    }
    if (!_mainController.useSideBar) {
      _mainController.useBottomNav = MediaQuery.sizeOf(context).isPortrait;
    }
  }

  @override
  void didPopNext() {
    addObserverMobile(this);
    _mainController
      ..checkUnreadDynamic()
      ..checkDefaultSearch(true)
      ..checkUnread(_mainController.useBottomNav);
    super.didPopNext();
  }

  @override
  void didPushNext() {
    removeObserverMobile(this);
    super.didPushNext();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _mainController
        ..checkUnreadDynamic()
        ..checkDefaultSearch(true)
        ..checkUnread(_mainController.useBottomNav);
    }
  }

  @override
  void dispose() {
    if (Platform.isMacOS) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
    if (PlatformUtils.isDesktop) {
      WindowController.instance.dispose();
      TrayController.instance.dispose();
    }
    removeObserverMobile(this);
    PiliScheme.listener?.cancel();
    GStorage.close();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    return event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyR &&
        HardwareKeyboard.instance.isMetaPressed &&
        _mainController.refreshRecommendations();
  }

  @pragma('vm:prefer-inline')
  static void _onBack() {
    if (Platform.isAndroid) {
      AndroidHelper.back();
    }
  }

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (_mainController.directExitOnBack) {
      _onBack();
    } else {
      if (_mainController.selectedIndex.value != 0) {
        _mainController
          ..setIndex(0)
          ..barOffset?.value = 0.0
          ..showBottomBar?.value = true
          ..setSearchBar();
      } else {
        _onBack();
      }
    }
  }

  Widget? get _bottomNav {
    Widget? bottomNav;
    if (_mainController.navigationBars.length > 1) {
      bottomNav = Obx(() {
        final service = BiliThemeService.instance;
        final file = service.enabled.value ? service.tailBg : null;
        final edgeColor = Color(
          service.tailBackgroundColor.value ??
              service.activeSeedColor ??
              _colorScheme.surface.toARGB32(),
        );
        final fallbackForeground = edgeColor.computeLuminance() < 0.5
            ? Colors.white
            : Colors.black87;
        final props = service.appliedProperties;
        final selectedColor = file == null
            ? null
            : parseBiliThemeColor(props?.tailColorSelected) ??
                  fallbackForeground;
        final unselectedColor = file == null
            ? null
            : parseBiliThemeColor(props?.tailColor) ?? fallbackForeground;
        final labelStyle = file == null
            ? null
            : WidgetStateProperty.resolveWith<TextStyle?>(
                (states) => Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: states.contains(WidgetState.selected)
                      ? selectedColor
                      : unselectedColor,
                ),
              );
        final indicatorColor = selectedColor?.withValues(alpha: 0.16);
        final Widget bar;
        if (_mainController.floatingNavBar) {
          return FloatingNavigationBar(
            backgroundImage: file == null
                ? null
                : DecorationImage(
                    image: FileImage(file),
                    fit: BoxFit.cover,
                    onError: (_, _) {},
                  ),
            backgroundColor: file == null ? null : edgeColor,
            elevation: file == null ? null : 0,
            surfaceTintColor: file == null ? null : Colors.transparent,
            indicatorColor: indicatorColor,
            labelTextStyle: labelStyle,
            onDestinationSelected: _mainController.setIndex,
            selectedIndex: _mainController.selectedIndex.value,
            destinations: _mainController.navigationBars
                .map(
                  (e) => FloatingNavigationDestination(
                    label: e.label,
                    icon: _buildIcon(type: e),
                    selectedIcon: _buildIcon(type: e, selected: true),
                  ),
                )
                .toList(),
          );
        } else if (_mainController.enableMYBar) {
          bar = NavigationBar(
            backgroundColor: file == null ? null : Colors.transparent,
            elevation: file == null ? null : 0,
            surfaceTintColor: file == null ? null : Colors.transparent,
            indicatorColor: indicatorColor,
            labelTextStyle: labelStyle,
            maintainBottomViewPadding: true,
            onDestinationSelected: _mainController.setIndex,
            selectedIndex: _mainController.selectedIndex.value,
            destinations: _mainController.navigationBars
                .map(
                  (e) => NavigationDestination(
                    label: e.label,
                    icon: _buildIcon(type: e),
                    selectedIcon: _buildIcon(type: e, selected: true),
                  ),
                )
                .toList(),
          );
        } else {
          bar = BottomNavigationBar(
            backgroundColor: file == null ? null : Colors.transparent,
            elevation: file == null ? null : 0,
            selectedItemColor: selectedColor,
            unselectedItemColor: unselectedColor,
            currentIndex: _mainController.selectedIndex.value,
            onTap: _mainController.setIndex,
            iconSize: 16,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            type: .fixed,
            items: _mainController.navigationBars
                .map(
                  (e) => BottomNavigationBarItem(
                    label: e.label,
                    icon: _buildIcon(type: e),
                    activeIcon: _buildIcon(type: e, selected: true),
                  ),
                )
                .toList(),
          );
        }
        return BiliThemeNavigationBackground(
          file: file,
          edgeColor: edgeColor,
          child: bar,
        );
      });

      if (_mainController.hideBottomBar) {
        if (_mainController.barOffset case final barOffset?) {
          return Obx(
            () => FractionalTranslation(
              translation: Offset(0.0, barOffset.value / Style.topBarHeight),
              child: bottomNav,
            ),
          );
        }
        if (_mainController.showBottomBar case final showBottomBar?) {
          return Obx(
            () => AnimatedSlide(
              curve: Curves.easeInOutCubicEmphasized,
              duration: const Duration(milliseconds: 500),
              offset: Offset(0, showBottomBar.value ? 0 : 1),
              child: bottomNav,
            ),
          );
        }
      }
    }

    return bottomNav;
  }

  Widget _sideBar() {
    if (_mainController.navigationBars.length > 1) {
      if (context.isTablet && _mainController.optTabletNav) {
        return Padding(
          padding: const .only(top: 25),
          child: MediaQuery.removePadding(
            context: context,
            removeRight: true,
            child: Obx(
              () => DrawerTheme(
                data: DrawerThemeData(
                  width:
                      (_mainController.hideSideBarLabel ? 80 : 130) +
                      _padding.left,
                ),
                child: NavigationDrawer(
                  /// apply `lib/scripts/navigation_drawer.patch`
                  flex: 5,
                  backgroundColor: Colors.transparent,
                  onDestinationSelected: _mainController.setIndex,
                  selectedIndex: _mainController.selectedIndex.value,
                  header: Expanded(flex: 4, child: userAndSearchVertical()),
                  tilePadding: const .symmetric(vertical: 5, horizontal: 12),
                  indicatorShape: _mainController.hideSideBarLabel
                      ? const RoundedRectangleBorder(
                          borderRadius: .all(.circular(12)),
                        )
                      : const RoundedRectangleBorder(
                          borderRadius: .all(.circular(16)),
                        ),
                  children: _mainController.navigationBars
                      .map(
                        (e) => NavigationDrawerDestination(
                          label: _mainController.hideSideBarLabel
                              ? Semantics(
                                  label: e.label,
                                  child: const SizedBox.shrink(),
                                )
                              : Text(e.label),
                          icon: _buildIcon(type: e),
                          selectedIcon: _buildIcon(
                            type: e,
                            selected: true,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        );
      }
      return Obx(
        () => NavigationRail(
          groupAlignment: 0.5,
          labelType: _mainController.hideSideBarLabel ? .none : .selected,
          leading: userAndSearchVertical(),
          backgroundColor: Colors.transparent,
          onDestinationSelected: _mainController.setIndex,
          selectedIndex: _mainController.selectedIndex.value,
          destinations: _mainController.navigationBars
              .map(
                (e) => NavigationRailDestination(
                  label: Text(e.label),
                  icon: _buildIcon(type: e),
                  selectedIcon: _buildIcon(type: e, selected: true),
                ),
              )
              .toList(),
        ),
      );
    }
    return Container(
      width: 80,
      margin: .only(top: 12 + _padding.top, left: _padding.left),
      child: userAndSearchVertical(),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_mainController.mainTabBarView) {
      child = TabBarView(
        controller: _mainController.controller,
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: _mainController.useBottomNav ? .horizontal : .vertical,
        children: _mainController.navigationBars.map((i) => i.page).toList(),
      );
    } else {
      child = PageView(
        controller: _mainController.controller,
        physics: const NeverScrollableScrollPhysics(),
        children: _mainController.navigationBars.map((i) => i.page).toList(),
      );
    }

    Widget? sideBar;
    Widget? bottomNav;
    final EdgeInsets padding;
    if (_mainController.useBottomNav) {
      bottomNav = _bottomNav;
      if (bottomNav != null) {
        bottomNav = MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: bottomNav,
        );
      }
      padding = _padding.copyWith(
        top: PlatformUtils.isMobile ? 0 : _padding.top,
        bottom: 0,
      );
    } else {
      sideBar = DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: _colorScheme.outline.withValues(alpha: 0.06),
            ),
          ),
        ),
        child: _sideBar(),
      );
      padding = .only(
        top: PlatformUtils.isMobile ? 0 : _padding.top,
        right: _padding.right,
      );
    }

    child = Material(
      child: Stack(
        children: [
          Positioned.fill(child: _biliThemeBackground()),
          MainLayout(
            sideBar: sideBar,
            bottomNav: bottomNav,
            body: PrimaryPageInsets(
              top: PlatformUtils.isMobile ? _padding.top : 0,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ],
      ),
    );

    if (PlatformUtils.isMobile) {
      final body = child;
      return Obx(() {
        final service = BiliThemeService.instance;
        final edge =
            service.enabled.value &&
                !_mainController.floatingNavBar &&
                service.tailBg != null
            ? service.tailBackgroundColor.value
            : null;
        final navBrightness = edge == null
            ? _colorScheme.brightness.reverse
            : Color(edge).computeLuminance() < 0.5
            ? Brightness.light
            : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarBrightness: _colorScheme.brightness,
            statusBarIconBrightness: _colorScheme.brightness.reverse,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: navBrightness,
            systemNavigationBarContrastEnforced: edge == null ? null : false,
          ),
          child: body,
        );
      });
    }

    return child;
  }

  Widget _biliThemeBackground() => Obx(() {
    final service = BiliThemeService.instance;
    final seed = service.activeSeedColor;
    if (seed == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: ColoredBox(
        color: Color.alphaBlend(
          _colorScheme.surface.withValues(alpha: service.bgOpacity.value),
          Color(seed),
        ),
      ),
    );
  });

  Widget _buildIcon({required NavigationBarType type, bool selected = false}) {
    Widget icon = selected ? type.selectIcon : type.icon;
    final service = BiliThemeService.instance;
    if (service.enabled.value) {
      final themedIcon = service.tailIcon(
        switch (type) {
          .home => 'main',
          .dynamics => 'dynamic',
          .mine => 'myself',
        },
        selected,
      );
      if (themedIcon != null) {
        icon = Image.file(
          themedIcon,
          width: 26,
          height: 26,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => selected ? type.selectIcon : type.icon,
        );
      }
      if (service.tailBg != null) {
        final edge = Color(
          service.tailBackgroundColor.value ??
              service.activeSeedColor ??
              _colorScheme.surface.toARGB32(),
        );
        final props = service.appliedProperties;
        final color =
            parseBiliThemeColor(
              selected ? props?.tailColorSelected : props?.tailColor,
            ) ??
            (edge.computeLuminance() < 0.5 ? Colors.white : Colors.black87);
        icon = IconTheme(
          data: IconThemeData(color: color),
          child: icon,
        );
      }
    }
    return type == .dynamics
        ? Obx(() {
            final dynCount = _mainController.dynCount.value;
            return Badge(
              isLabelVisible: dynCount > 0,
              label: _mainController.dynamicBadgeMode == .number
                  ? Text(dynCount.toString())
                  : null,
              padding: const .symmetric(horizontal: 6),
              child: icon,
            );
          })
        : icon;
  }

  Widget userAndSearchVertical() {
    return Column(
      children: [
        userAvatar(colorScheme: _colorScheme, mainController: _mainController),
        const SizedBox(height: 8),
        msgBadge(_mainController),
        IconButton(
          tooltip: '搜索',
          icon: const Icon(
            Icons.search_outlined,
            semanticLabel: '搜索',
          ),
          onPressed: () => Get.toNamed('/search'),
        ),
      ],
    );
  }
}

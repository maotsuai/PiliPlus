import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/bili_theme.dart';
import 'package:PiliPlus/common/widgets/custom_height_widget.dart';
import 'package:PiliPlus/common/widgets/floating_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/player_bar.dart';
import 'package:PiliPlus/utils/bili_theme_color.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late File art;
  late File categoryArt;

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('piliplus-theme-test-');
    art = File('${temporary.path}/theme.png');
    await art.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aK1cAAAAASUVORK5CYII=',
      ),
    );
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xFF4537AD), BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 8);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    categoryArt = File('${temporary.path}/category.png');
    await categoryArt.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
  tearDownAll(() => temporary.delete(recursive: true));

  Widget frame(
    Widget child, {
    double top = 32,
    double bottom = 34,
    double scale = 1,
    double width = 390,
    ThemeData? theme,
  }) {
    return MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          padding: EdgeInsets.only(top: top, bottom: bottom),
          viewPadding: EdgeInsets.only(top: top, bottom: bottom),
          textScaler: TextScaler.linear(scale),
        ),
        child: PrimaryPageInsets(
          top: top,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }

  test('theme colors and status icon brightness have safe fallbacks', () {
    expect(parseBiliThemeColor('#aBcDeF'), const Color(0xFFABCDEF));
    expect(parseBiliThemeColor('0x80aabbcc'), const Color(0xFFAABBCC));
    expect(parseBiliThemeColor('not-a-color'), isNull);
    expect(parseBiliThemeColor(null), isNull);
    final white = biliThemeOverlayStyle(Colors.white);
    expect(white.statusBarIconBrightness, Brightness.light);
    expect(white.statusBarBrightness, Brightness.dark);
    expect(white.statusBarColor, Colors.transparent);
    expect(white.systemNavigationBarColor, isNull);
    expect(
      biliThemeOverlayStyle(Colors.black).statusBarIconBrightness,
      Brightness.dark,
    );
  });

  test(
    'gesture color samples the bottom edge rather than the image center',
    () async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..drawColor(const Color(0xFFFF0000), BlendMode.src)
        ..drawRect(
          const Rect.fromLTWH(0, 6, 64, 4),
          Paint()..color = const Color(0xFF123456),
        );
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 10);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${temporary.path}/edge.png');
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      expect(await extractBottomEdgeColorFromImage(file), 0xFF123456);
    },
  );

  testWidgets(
    'header art includes status pixels, controls stay below the inset',
    (tester) async {
      const controlKey = ValueKey('control');
      await tester.pumpWidget(
        frame(
          BiliThemePrimaryHeader(
            file: art,
            foreground: Colors.white,
            child: const SizedBox(key: controlKey, height: 52),
          ),
        ),
      );
      expect(tester.getSize(find.byType(BiliThemePrimaryHeader)).height, 84);
      expect(tester.getTopLeft(find.byKey(controlKey)).dy, 32);
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find
            .descendant(
              of: find.byType(BiliThemePrimaryHeader),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            )
            .first,
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
    },
  );

  testWidgets('collapsing search preserves just the status inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      frame(
        BiliThemePrimaryHeader(
          file: art,
          child: const ClipRect(
            child: CustomHeightWidget(
              height: 0,
              offset: Offset(0, -52),
              child: SizedBox(height: 52),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(BiliThemePrimaryHeader)).height, 32);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone headers do not add a second SafeArea', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: BiliThemePrimaryHeader(child: SizedBox(height: 52)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(BiliThemePrimaryHeader)).height, 52);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'category art blends into the $brightness page without fading labels',
      (tester) async {
        final theme = ThemeData(brightness: brightness);
        final background = brightness == Brightness.dark
            ? const Color(0xFF2D2C4C)
            : const Color(0xFFF4F2FC);
        var selected = -1;
        const boundaryKey = ValueKey('category-pixels');
        // Resolve real file I/O outside the fake clock before painting it.
        // Starting FileImage in pumpWidget then awaiting precacheImage in
        // runAsync would leave its completion queued in the fake async zone.
        await tester.pumpWidget(frame(const SizedBox.shrink(), theme: theme));
        await tester.runAsync(
          () => precacheImage(
            FileImage(categoryArt),
            tester.element(find.byType(PrimaryPageInsets)),
          ).timeout(const Duration(seconds: 10)),
        );
        await tester.pumpWidget(
          frame(
            DefaultTabController(
              length: 2,
              child: RepaintBoundary(
                key: boundaryKey,
                child: BiliThemeTabBarSurface(
                  file: categoryArt,
                  backgroundColor: background,
                  child: SizedBox(
                    height: 46,
                    child: TabBar(
                      labelColor: theme.colorScheme.onSurface,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      indicatorColor: theme.colorScheme.primary,
                      onTap: (index) => selected = index,
                      tabs: const [
                        Tab(text: '直播'),
                        Tab(text: '推荐'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byType(BiliThemeTabBarSurface),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(decoration.color, background);
        expect(decoration.image!.opacity, 0.18);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final data = await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          } finally {
            image.dispose();
          }
        });
        final offset = (5 * boundary.size.width.toInt() + 5) * 4;
        final rgba = data!.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final actual = Color.fromARGB(
          rgba[offset + 3],
          rgba[offset],
          rgba[offset + 1],
          rgba[offset + 2],
        );
        final expected = Color.alphaBlend(
          const Color(0xFF4537AD).withValues(alpha: 0.18),
          background,
        );
        expect(actual.r, closeTo(expected.r, 2 / 255));
        expect(actual.g, closeTo(expected.g, 2 / 255));
        expect(actual.b, closeTo(expected.b, 2 / 255));
        expect(
          DefaultTextStyle.of(tester.element(find.text('直播'))).style.color,
          theme.colorScheme.onSurface,
        );
        await tester.tap(find.text('推荐'));
        await tester.pumpAndSettle();
        expect(selected, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('missing category art keeps the original tab strip unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      frame(
        const BiliThemeTabBarSurface(
          file: null,
          backgroundColor: Colors.red,
          child: SizedBox(height: 46, child: Text('原生栏目栏')),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(BiliThemeTabBarSurface),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    expect(find.text('原生栏目栏'), findsOneWidget);
    expect(tester.getSize(find.byType(BiliThemeTabBarSurface)).height, 46);
  });

  testWidgets(
    'mine header is one third INCLUDING status and actions; buttons hit',
    (tester) async {
      var taps = 0;
      const actionKey = ValueKey('mine-action');
      await tester.pumpWidget(
        frame(
          BiliThemeHeaderLayout(
            preferredHeight: 300,
            topInset: 32,
            actions: SizedBox(
              height: 60,
              child: TextButton(
                key: actionKey,
                onPressed: () => taps++,
                child: const Text('设置'),
              ),
            ),
            info: const SizedBox(height: 110),
          ),
        ),
      );
      expect(tester.getSize(find.byType(BiliThemeHeaderLayout)).height, 300);
      expect(tester.getTopLeft(find.byKey(actionKey)).dy, 32);
      await tester.tap(find.byKey(actionKey));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('short landscape and scaled user info grow without clipping', (
    tester,
  ) async {
    const infoKey = ValueKey('info');
    await tester.pumpWidget(
      frame(
        const BiliThemeHeaderLayout(
          preferredHeight: 130,
          topInset: 44,
          actions: SizedBox(height: 60),
          info: Text(
            '用户资料\n硬币和经验\n稿件 关注 粉丝',
            key: infoKey,
            style: TextStyle(fontSize: 24),
          ),
        ),
        top: 44,
        scale: 2,
      ),
    );
    final height = tester.getSize(find.byType(BiliThemeHeaderLayout)).height;
    final infoBottom = tester.getBottomLeft(find.byKey(infoKey)).dy;
    expect(height, greaterThan(130));
    expect(height - infoBottom, greaterThanOrEqualTo(12));
    expect(tester.takeException(), isNull);
  });

  // Use MinePage's actual PlayerBar/Row structure. A generic SizedBox or
  // TextButton does not reproduce PlayerBar's overflow scaling regression.
  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets(
      'mine action icons keep their painted size and right alignment at $width dp',
      (tester) async {
        const icons = [
          Icons.message_outlined,
          Icons.visibility_off_outlined,
          Icons.switch_account_outlined,
          Icons.dark_mode_outlined,
          Icons.settings_outlined,
        ];
        final taps = <int>[];
        await tester.pumpWidget(
          frame(
            BiliThemeHeaderLayout(
              preferredHeight: 300,
              topInset: 32,
              actions: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: PlayerBar(
                  left: const SizedBox.shrink(),
                  right: Row(
                    spacing: 5,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < icons.length; i++)
                        IconButton(
                          key: ValueKey('action-$i'),
                          iconSize: 22,
                          padding: const EdgeInsets.all(8),
                          style: const ButtonStyle(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => taps.add(i),
                          icon: Icon(icons[i]),
                        ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
              info: const SizedBox(height: 110),
            ),
            width: width,
            scale: 2,
          ),
        );
        expect(tester.getSize(find.byType(BiliThemeHeaderLayout)).height, 300);
        for (var i = 0; i < icons.length; i++) {
          final icon = tester.renderObject<RenderBox>(find.byIcon(icons[i]));
          final origin = icon.localToGlobal(Offset.zero);
          final end = icon.localToGlobal(
            Offset(icon.size.width, icon.size.height),
          );
          expect(end.dx - origin.dx, closeTo(22, 0.01));
          expect(end.dy - origin.dy, closeTo(22, 0.01));
          final button = tester.renderObject<RenderBox>(
            find.byKey(ValueKey('action-$i')),
          );
          final top = button.localToGlobal(Offset.zero);
          final bottom = button.localToGlobal(
            Offset(button.size.width, button.size.height),
          );
          expect(top.dy, greaterThanOrEqualTo(32 + 10));
          expect(bottom.dx - top.dx, greaterThanOrEqualTo(38));
          expect(bottom.dy - top.dy, greaterThanOrEqualTo(38));
          if (i == icons.length - 1) {
            // Row.spacing also precedes the final 16dp trailing spacer.
            expect(bottom.dx, closeTo(width - 16 - 5, 0.01));
          }
          await tester.tapAt(
            button.localToGlobal(button.size.center(Offset.zero)),
          );
        }
        expect(taps, [0, 1, 2, 3, 4]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'mine layout works in a scrolling Stack and updates after rotation',
    (tester) async {
      const actionsKey = ValueKey('scroll-actions');
      Widget page(double height, double inset) => frame(
        ListView(
          padding: EdgeInsets.zero,
          children: [
            Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.blue)),
                BiliThemeHeaderLayout(
                  preferredHeight: height / 3,
                  topInset: inset,
                  actions: const SizedBox(key: actionsKey, height: 60),
                  info: const SizedBox(height: 110),
                ),
              ],
            ),
            const SizedBox(height: 1000),
          ],
        ),
        top: inset,
      );
      await tester.pumpWidget(page(900, 32));
      expect(tester.getSize(find.byType(BiliThemeHeaderLayout)).height, 300);
      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(actionsKey)).dy, lessThan(0));
      await tester.pumpWidget(page(390, 0));
      expect(tester.getSize(find.byType(BiliThemeHeaderLayout)).height, 194);
      expect(tester.takeException(), isNull);
    },
  );

  for (final modern in [true, false]) {
    testWidgets(
      '${modern ? 'MD3' : 'classic'} bar reserves system inset once and remains tappable',
      (tester) async {
        var selected = -1;
        final Widget bar = modern
            ? NavigationBar(
                maintainBottomViewPadding: true,
                backgroundColor: Colors.transparent,
                onDestinationSelected: (i) => selected = i,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: '首页'),
                  NavigationDestination(icon: Icon(Icons.person), label: '我的'),
                ],
              )
            : BottomNavigationBar(
                selectedFontSize: 12,
                unselectedFontSize: 12,
                onTap: (i) => selected = i,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: '我的',
                  ),
                ],
              );
        await tester.pumpWidget(
          frame(
            BiliThemeNavigationBackground(
              file: art,
              edgeColor: Colors.blue,
              child: bar,
            ),
            top: 0,
          ),
        );
        final type = modern ? NavigationBar : BottomNavigationBar;
        final barHeight = tester.getSize(find.byType(type)).height;
        final backgroundHeight = tester
            .getSize(find.byType(BiliThemeNavigationBackground))
            .height;
        expect(backgroundHeight - barHeight, 34);
        expect(barHeight, modern ? 80 : 56);
        await tester.tap(find.text('我的'));
        expect(selected, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'floating art stays inside the capsule and above the system inset',
    (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        frame(
          FloatingNavigationBar(
            backgroundImage: DecorationImage(
              image: FileImage(art),
              fit: BoxFit.cover,
              onError: (_, _) {},
            ),
            onDestinationSelected: (i) => selected = i,
            destinations: const [
              FloatingNavigationDestination(
                icon: Icon(Icons.home),
                label: '首页',
              ),
              FloatingNavigationDestination(
                icon: Icon(Icons.person),
                label: '我的',
              ),
            ],
          ),
        ),
      );
      final decoration = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .firstWhere(
            (box) =>
                box.decoration is ShapeDecoration &&
                (box.decoration as ShapeDecoration).image != null,
          );
      expect(
        (decoration.decoration as ShapeDecoration).image!.fit,
        BoxFit.cover,
      );
      expect(
        tester.getSize(find.byType(FloatingNavigationBar)).height,
        64 + 8 + 34,
      );
      await tester.tap(find.text('我的'));
      expect(selected, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing artwork preserves native safe-area behavior', (
    tester,
  ) async {
    await tester.pumpWidget(
      frame(
        BiliThemeNavigationBackground(
          file: null,
          edgeColor: Colors.red,
          child: NavigationBar(
            maintainBottomViewPadding: true,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: '首页'),
              NavigationDestination(icon: Icon(Icons.person), label: '我的'),
            ],
          ),
        ),
        top: 0,
      ),
    );
    expect(tester.getSize(find.byType(NavigationBar)).height, 114);
    expect(
      tester.getSize(find.byType(BiliThemeNavigationBackground)).height,
      114,
    );
    expect(tester.takeException(), isNull);
  });
}

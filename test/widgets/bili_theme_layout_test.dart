import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/bili_theme.dart';
import 'package:PiliPlus/common/widgets/custom_height_widget.dart';
import 'package:PiliPlus/common/widgets/floating_navigation_bar.dart';
import 'package:PiliPlus/utils/bili_theme_color.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late File art;

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('piliplus-theme-test-');
    art = File('${temporary.path}/theme.png');
    await art.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aK1cAAAAASUVORK5CYII=',
      ),
    );
  });
  tearDownAll(() => temporary.delete(recursive: true));

  Widget frame(
    Widget child, {
    double top = 32,
    double bottom = 34,
    double scale = 1,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 900),
          padding: EdgeInsets.only(top: top, bottom: bottom),
          viewPadding: EdgeInsets.only(top: top, bottom: bottom),
          textScaler: TextScaler.linear(scale),
        ),
        child: PrimaryPageInsets(
          top: top,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 390, child: child),
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

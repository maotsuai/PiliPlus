import 'package:PiliPlus/utils/pip_restore_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class _PlaybackPageController extends GetxController {
  bool closed = false;

  @override
  void onClose() {
    closed = true;
    super.onClose();
  }
}

void main() {
  tearDown(Get.reset);

  for (final name in ['/videoV', '/liveRoom']) {
    testWidgets(
      '$name restores immediately and keeps animated back navigation',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          const GetMaterialApp(
            defaultTransition: Transition.rightToLeft,
            home: Scaffold(body: Text('browsing')),
          ),
        );
        await tester.pumpAndSettle();
        final arguments = name == '/videoV' ? {'cid': 42} : 99;
        final playback = _PlaybackPageController();
        const pageKey = ValueKey('playback');
        final route = PipRestoreRoute<void>(
          name: name,
          arguments: arguments,
          page: () {
            Get.put(playback);
            return const Scaffold(key: pageKey, body: Text('playback'));
          },
        );
        Get.key.currentState!.push(route);
        await tester.pump();

        expect(Get.currentRoute, name);
        expect(Get.arguments, same(arguments));
        expect(Get.routing.route, same(route));
        expect(route.animation!.value, 1);
        expect(route.animation!.isAnimating, isFalse);
        expect(tester.getTopLeft(find.byKey(pageKey)), Offset.zero);
        expect(find.text('browsing'), findsNothing);

        Get.back<void>();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(route.animation!.value, inExclusiveRange(0, 1));
        expect(playback.closed, isFalse);
        await tester.pumpAndSettle();
        expect(find.text('browsing'), findsOneWidget);
        expect(playback.closed, isTrue);
        expect(Get.isRegistered<_PlaybackPageController>(), isFalse);
      },
    );
  }

  testWidgets('pages opened after PiP retain their normal transitions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        defaultTransition: Transition.rightToLeft,
        home: Scaffold(body: Text('browsing')),
      ),
    );
    await tester.pumpAndSettle();
    Get.key.currentState!.push(
      PipRestoreRoute<void>(
        name: '/videoV',
        page: () => const Scaffold(body: Text('playback')),
      ),
    );
    await tester.pumpAndSettle();
    final next = GetPageRoute<void>(
      routeName: '/other',
      settings: const RouteSettings(name: '/other'),
      page: () => const Scaffold(body: Text('other')),
    );
    Get.key.currentState!.push(next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(next.animation!.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(Get.currentRoute, '/videoV');
    expect(find.text('playback'), findsOneWidget);
  });
}

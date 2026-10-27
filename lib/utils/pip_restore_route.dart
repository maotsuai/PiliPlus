import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Restores a playback page without another entrance animation after system PiP.
/// Get routing, page ownership and subsequent transitions remain unchanged.
class PipRestoreRoute<T> extends GetPageRoute<T> {
  PipRestoreRoute({
    required String name,
    required GetPageBuilder page,
    Object? arguments,
  }) : super(
         routeName: name,
         settings: RouteSettings(name: name, arguments: arguments),
         page: page,
       );

  @override
  TickerFuture didPush() {
    super.didPush();
    controller!.value = controller!.upperBound;
    return TickerFuture.complete();
  }
}

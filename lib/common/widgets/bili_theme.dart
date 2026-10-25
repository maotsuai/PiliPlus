import 'dart:io';
import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/slotted_layout_helper.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Only MainApp supplies this inset. Standalone/secondary routes keep their
/// existing SafeArea ownership, rather than acquiring a second top inset.
class PrimaryPageInsets extends InheritedWidget {
  const PrimaryPageInsets({super.key, required this.top, required super.child});

  final double top;

  static double topOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrimaryPageInsets>()?.top ?? 0;

  @override
  bool updateShouldNotify(PrimaryPageInsets oldWidget) => top != oldWidget.top;
}

Color? parseBiliThemeColor(String? value) {
  if (value == null) return null;
  final hex = value.trim().replaceFirst(RegExp(r'^(#|0[xX])'), '');
  if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(hex)) {
    return null;
  }
  final color = int.parse(hex, radix: 16);
  // Theme foregrounds must be opaque even when a package specifies alpha.
  return Color(0xFF000000 | color);
}

SystemUiOverlayStyle biliThemeOverlayStyle(Color foreground) {
  final darkIcons = foreground.computeLuminance() < 0.5;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: darkIcons ? Brightness.light : Brightness.dark,
    statusBarIconBrightness: darkIcons ? Brightness.dark : Brightness.light,
    systemStatusBarContrastEnforced: false,
  );
}

/// Artwork and a restrained contrast veil; never expands the artwork into the
/// content region. All interactive children retain their own Material surface.
class BiliThemeSurface extends StatelessWidget {
  const BiliThemeSurface({
    super.key,
    this.file,
    this.foreground,
    required this.child,
  });

  final File? file;
  final Color? foreground;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (file == null) return child;
    final darkText = (foreground ?? Colors.white).computeLuminance() < 0.5;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: darkText ? Colors.white : const Color(0xFF263238),
        image: DecorationImage(
          image: FileImage(file!),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          onError: (_, _) {},
        ),
      ),
      child: ColoredBox(
        color: darkText ? const Color(0x99FFFFFF) : const Color(0x40000000),
        child: child,
      ),
    );
  }
}

/// The category strip should transition into the page, rather than repeat the
/// saturated header art. Fade only the artwork, never the tab labels/indicator.
class BiliThemeTabBarSurface extends StatelessWidget {
  const BiliThemeTabBarSurface({
    super.key,
    required this.file,
    required this.backgroundColor,
    required this.child,
  });

  static const imageOpacity = 0.18;

  final File? file;
  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (file == null) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        image: DecorationImage(
          image: FileImage(file!),
          opacity: imageOpacity,
          fit: BoxFit.cover,
          onError: (_, _) {},
        ),
      ),
      child: child,
    );
  }
}

/// Background owns the status-bar pixels; content starts below the safe inset.
class BiliThemePrimaryHeader extends StatelessWidget {
  const BiliThemePrimaryHeader({
    super.key,
    this.file,
    this.foreground,
    required this.child,
  });

  final File? file;
  final Color? foreground;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = foreground ?? ColorScheme.of(context).onSurface;
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: biliThemeOverlayStyle(color),
      child: BiliThemeSurface(
        file: file,
        foreground: color,
        child: Padding(
          padding: EdgeInsets.only(top: PrimaryPageInsets.topOf(context)),
          child: Theme(
            data: theme.copyWith(
              iconTheme: theme.iconTheme.copyWith(color: color),
              iconButtonTheme: IconButtonThemeData(
                style: (theme.iconButtonTheme.style ?? const ButtonStyle())
                    .copyWith(foregroundColor: WidgetStatePropertyAll(color)),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Native bars normally include the system inset in their own Material. Keep
/// the original art aspect ratio in the button area and extend its edge color
/// into the gesture/three-button system navigation area exactly once.
class BiliThemeNavigationBackground extends StatelessWidget {
  const BiliThemeNavigationBackground({
    super.key,
    required this.file,
    required this.edgeColor,
    required this.child,
  });

  final File? file;
  final Color edgeColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (file == null) return child;
    final media = MediaQuery.of(context);
    return ColoredBox(
      color: edgeColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewPadding.bottom),
        child: DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: FileImage(file!),
              fit: BoxFit.cover,
              onError: (_, _) {},
            ),
          ),
          child: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(bottom: 0),
              viewPadding: media.viewPadding.copyWith(bottom: 0),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

enum BiliThemeHeaderSlot { actions, info }

/// Measures real content (including text scaling) before choosing the header
/// height. Normally exactly screenHeight / 3, including the status bar. Short
/// landscape screens and large fonts may grow it to avoid clipping controls.
class BiliThemeHeaderLayout
    extends
        SlottedMultiChildRenderObjectWidget<BiliThemeHeaderSlot, RenderBox> {
  const BiliThemeHeaderLayout({
    super.key,
    required this.preferredHeight,
    required this.topInset,
    required this.actions,
    required this.info,
  });

  final double preferredHeight;
  final double topInset;
  final Widget actions;
  final Widget info;

  @override
  Iterable<BiliThemeHeaderSlot> get slots => BiliThemeHeaderSlot.values;

  @override
  Widget childForSlot(BiliThemeHeaderSlot slot) => switch (slot) {
    .actions => actions,
    .info => info,
  };

  @override
  SlottedContainerRenderObjectMixin<BiliThemeHeaderSlot, RenderBox>
  createRenderObject(
    BuildContext context,
  ) => RenderBiliThemeHeaderLayout(preferredHeight, topInset);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBiliThemeHeaderLayout renderObject,
  ) {
    renderObject.update(preferredHeight, topInset);
  }
}

class RenderBiliThemeHeaderLayout extends RenderBox
    with
        SlottedContainerRenderObjectMixin<BiliThemeHeaderSlot, RenderBox>,
        SlottedLayoutMixin<BiliThemeHeaderSlot> {
  RenderBiliThemeHeaderLayout(this.preferredHeight, this.topInset);

  double preferredHeight;
  double topInset;

  void update(double height, double inset) {
    if (height == preferredHeight && inset == topInset) return;
    preferredHeight = height;
    topInset = inset;
    markNeedsLayout();
  }

  @override
  Iterable<BiliThemeHeaderSlot> get slots => BiliThemeHeaderSlot.values;

  @override
  void performLayout() {
    final actions = childForSlot(.actions)!;
    final info = childForSlot(.info)!;
    final childConstraints = BoxConstraints.tightFor(
      width: constraints.maxWidth,
    );
    // PlayerBar measures its left/right slots with an unbounded max width.
    // Do not pass a tight min width: even its empty left slot would otherwise
    // become screen-wide and trigger a spurious 50% overflow scale.
    actions.layout(
      BoxConstraints(maxWidth: constraints.maxWidth),
      parentUsesSize: true,
    );
    info.layout(childConstraints, parentUsesSize: true);
    final infoTop = topInset + actions.size.height;
    size = constraints.constrain(
      Size(
        constraints.maxWidth,
        math.max(preferredHeight, infoTop + info.size.height + 24),
      ),
    );
    setOffset(actions, Offset(0, topInset));
    setOffset(
      info,
      Offset(0, infoTop + (size.height - infoTop - info.size.height) / 2),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final slot in slots) {
      final child = childForSlot(slot)!;
      context.paintChild(child, offset + getOffset(child));
    }
  }
}

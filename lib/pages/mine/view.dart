import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/player_bar.dart';
import 'package:PiliPlus/common/widgets/route_aware_mixin.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/mine/widgets/item.dart';
import 'package:PiliPlus/services/bili_theme_service.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key, this.showBackBtn = false});

  final bool showBackBtn;

  @override
  State<MinePage> createState() => _MediaPageState();
}

class _MediaPageState extends CommonPageState<MinePage>
    with AutomaticKeepAliveClientMixin, RouteAware, RouteAwareMixin<MinePage> {
  final MineController controller = Get.putOrFind(MineController.new);
  late final MainController _mainController = Get.find<MainController>();
  final _routeVisible = true.obs;

  @override
  bool get wantKeepAlive => true;

  @override
  void didPushNext() {
    _routeVisible.value = false;
  }

  @override
  void didPopNext() {
    _routeVisible.value = true;
  }

  @override
  void dispose() {
    _routeVisible.close();
    super.dispose();
  }

  bool get checkPage =>
      _mainController.navigationBars[0] != NavigationBarType.mine &&
      _mainController.selectedIndex.value == 0;

  @override
  bool onNotificationType1(UserScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType1(notification);
  }

  @override
  bool onNotificationType2(ScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType2(notification);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    return Column(
      children: [
        Padding(
          padding: const .symmetric(vertical: 10),
          child: _buildHeaderActions,
        ),
        Expanded(
          child: Material(
            type: .transparency,
            child: refreshIndicator(
              onRefresh: controller.onRefresh,
              child: onBuild(
                ListView(
                  padding: const .only(bottom: 100),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildThemedUserInfo(theme, secondary),
                    _buildActions(secondary),
                    Obx(
                      () => controller.loadingState.value is Loading
                          ? const SizedBox.shrink()
                          : _buildFav(theme, secondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(Color primary) {
    return Row(
      mainAxisAlignment: .spaceEvenly,
      children: controller.list
          .map(
            (e) => Flexible(
              child: InkWell(
                onTap: e.onTap,
                borderRadius: Style.mdRadius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Column(
                      spacing: 6,
                      mainAxisSize: .min,
                      mainAxisAlignment: .center,
                      children: [
                        Icon(e.icon, color: primary),
                        Text(
                          e.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget get _buildHeaderActions {
    const iconSize = 22.0;
    const padding = EdgeInsets.all(8);
    const style = ButtonStyle(tapTargetSize: .shrinkWrap);
    return PlayerBar(
      children: [
        if (widget.showBackBtn)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: BackButton(),
          )
        else
          const SizedBox.shrink(),
        Row(
          spacing: 5,
          mainAxisSize: .min,
          children: [
            if (!_mainController.hasHome) ...[
              IconButton(
                iconSize: iconSize,
                padding: padding,
                style: style,
                tooltip: '搜索',
                onPressed: () => Get.toNamed('/search'),
                icon: const Icon(Icons.search),
              ),
              msgBadge(_mainController),
            ],
            if (GStorage.reply != null)
              IconButton(
                iconSize: iconSize,
                padding: padding,
                style: style,
                tooltip: '评论记录',
                onPressed: () => Get.toNamed('/myReply'),
                icon: const Icon(Icons.message_outlined),
              ),
            Obx(
              () {
                final anonymity = MineController.anonymity.value;
                return IconButton(
                  iconSize: iconSize,
                  padding: padding,
                  style: style,
                  tooltip: "${anonymity ? '退出' : '进入'}无痕模式",
                  onPressed: MineController.onChangeAnonymity,
                  icon: anonymity
                      ? const Icon(MdiIcons.incognito)
                      : const Icon(MdiIcons.incognitoOff),
                );
              },
            ),
            IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: '切换账号',
              onPressed: () => LoginPageController.switchAccountDialog(context),
              icon: const Icon(Icons.switch_account_outlined),
            ),
            Obx(
              () => IconButton(
                iconSize: iconSize,
                padding: padding,
                style: style,
                tooltip: '切换至${controller.nextThemeType.label}主题',
                onPressed: controller.onChangeTheme,
                icon: controller.themeType.value.icon,
              ),
            ),
            IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: '设置',
              onPressed: () =>
                  Get.toNamed('/setting', preventDuplicates: false),
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildThemedUserInfo(ThemeData theme, Color secondary) => Obx(() {
    final service = BiliThemeService.instance;
    final enabled = service.enabled.value;
    final staticBg = enabled ? service.mineBg : null;
    final videoBg = enabled && service.mineVideo.value
        ? service.mineVideoFile
        : null;
    if (staticBg == null && videoBg == null) {
      return _buildUserInfo(theme, secondary);
    }

    final selectedIndex = _mainController.selectedIndex.value;
    final isMine = selectedIndex < _mainController.navigationBars.length &&
        _mainController.navigationBars[selectedIndex] ==
            NavigationBarType.mine;
    final isCurrentTab = isMine && _routeVisible.value;
    final height = (MediaQuery.sizeOf(context).height / 3)
        .clamp(220.0, 380.0)
        .toDouble();
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (staticBg != null)
            Image.file(
              staticBg,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          if (videoBg != null)
            _LoopVideoBg(
              key: ValueKey(
                '${videoBg.path}:${service.resourceRevision.value}',
              ),
              file: videoBg,
              playing: isCurrentTab,
              loop: service.loopMineVideo,
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x19000000), Color(0xA6000000)],
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: _buildUserInfo(
                theme,
                Colors.white,
                onThemeBackground: true,
              ),
            ),
          ),
        ],
      ),
    );
  });

  Widget _buildUserInfo(
    ThemeData theme,
    Color secondary, {
    bool onThemeBackground = false,
  }) {
    final shadows = onThemeBackground
        ? const [Shadow(color: Colors.black54, blurRadius: 4)]
        : null;
    final style = TextStyle(
      fontSize: theme.textTheme.titleMedium!.fontSize,
      fontWeight: FontWeight.bold,
      color: onThemeBackground ? Colors.white : null,
      shadows: shadows,
    );
    final labelStyle = theme.textTheme.labelMedium!.copyWith(
      color: onThemeBackground ? Colors.white70 : theme.colorScheme.outline,
      shadows: shadows,
    );
    final coinLabelStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      color: onThemeBackground ? Colors.white70 : theme.colorScheme.outline,
      shadows: shadows,
    );
    final coinValStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      fontWeight: FontWeight.bold,
      color: secondary,
      shadows: shadows,
    );
    return Obx(() {
      final userInfo = controller.userInfo.value;
      final levelInfo = userInfo.levelInfo;
      final hasLevel = levelInfo != null;
      final isVip = userInfo.vipStatus != null && userInfo.vipStatus! > 0;
      final userStat = controller.userStat.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: .opaque,
            onTap: controller.onLogin,
            onLongPress: () {
              Feedback.forLongPress(context);
              controller.onLogin(true);
            },
            onSecondaryTap: PlatformUtils.isMobile
                ? null
                : () => controller.onLogin(true),
            child: Row(
              mainAxisSize: .min,
              children: [
                const SizedBox(width: 20),
                userInfo.face != null
                    ? Stack(
                        clipBehavior: .none,
                        children: [
                          NetworkImgLayer(
                            src: userInfo.face,
                            type: .avatar,
                            width: 55,
                            height: 55,
                          ),
                          if (isVip)
                            Positioned(
                              right: -1,
                              bottom: -2,
                              child: SvgPicture.asset(
                                Assets.vipIcon,
                                height: 19,
                                semanticsLabel: "大会员",
                              ),
                            ),
                        ],
                      )
                    : ClipOval(
                        child: Image.asset(
                          width: 55,
                          height: 55,
                          cacheHeight: 55.cacheSize(context),
                          Assets.avatarPlaceHolder,
                          semanticLabel: "默认头像",
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    mainAxisAlignment: .center,
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Flexible(
                            child: Text(
                              userInfo.uname ?? '点击登录',
                              style: theme.textTheme.titleMedium!.copyWith(
                                height: 1,
                                color: onThemeBackground
                                    ? Colors.white
                                    : isVip && userInfo.vipType == 2
                                    ? theme.colorScheme.vipColor
                                    : null,
                                shadows: shadows,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ),
                          BiliUtils.levelPicture(
                            levelInfo?.currentLevel ?? 0,
                            isSeniorMember: userInfo.isSeniorMember == 1,
                            height: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '硬币 ',
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: userInfo.money?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "      经验 ",
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: levelInfo?.currentExp?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "/${levelInfo?.nextExp ?? '-'}",
                              style: coinLabelStyle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 225),
                        child: LinearProgressIndicator(
                          minHeight: 2.25,
                          value: hasLevel
                              ? levelInfo.currentExp! / levelInfo.nextExp!
                              : 0,
                          backgroundColor: onThemeBackground
                              ? Colors.white24
                              : theme.colorScheme.outline.withValues(
                                  alpha: 0.4,
                                ),
                          valueColor: AlwaysStoppedAnimation<Color>(secondary),
                          stopIndicatorColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: .spaceEvenly,
            children: [
              _btn(
                count: controller.archiveCount.value,
                countStyle: style,
                name: '稿件',
                labelStyle: labelStyle,
                onTap: controller.onLogin,
              ),
              _btn(
                count: userStat.following,
                countStyle: style,
                name: '关注',
                labelStyle: labelStyle,
                onTap: () => controller.push('follow'),
              ),
              _btn(
                count: userStat.follower,
                countStyle: style,
                name: '粉丝',
                labelStyle: labelStyle,
                onTap: () => controller.push('fan'),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _btn({
    required int? count,
    required TextStyle countStyle,
    required String name,
    required TextStyle? labelStyle,
    required VoidCallback onTap,
  }) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: Style.mdRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: AspectRatio(
            aspectRatio: 1,
            child: Column(
              spacing: 4,
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                Text(
                  count?.toString() ?? '-',
                  style: countStyle,
                ),
                Text(
                  name,
                  style: labelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _autoRefresh() => Timer(
    const Duration(milliseconds: 150),
    () => controller.onRefresh(isManual: false),
  );

  Widget _buildFav(ThemeData theme, Color secondary) {
    return Column(
      children: [
        Divider(
          height: 20,
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
        ListTile(
          onTap: () => Get.toNamed('/fav')?.whenComplete(_autoRefresh),
          dense: true,
          title: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '我的收藏  ',
                    style: TextStyle(
                      fontSize: theme.textTheme.titleMedium!.fontSize,
                      fontWeight: .bold,
                    ),
                  ),
                  if (controller.favFolderCount != null)
                    TextSpan(
                      text: "${controller.favFolderCount}  ",
                      style: TextStyle(
                        fontSize: theme.textTheme.titleSmall!.fontSize,
                        color: secondary,
                      ),
                    ),
                  WidgetSpan(
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          trailing: IconButton(
            tooltip: '刷新',
            onPressed: controller.onRefresh,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ),
        _buildFavBody(theme, secondary, controller.loadingState.value),
      ],
    );
  }

  Widget _buildFavBody(
    ThemeData theme,
    Color secondary,
    LoadingState loadingState,
  ) {
    return switch (loadingState) {
      Loading() => const SizedBox.shrink(),
      Success(:final response) => Builder(
        builder: (context) {
          List<FavFolderInfo>? favFolderList = response.list;
          if (favFolderList == null || favFolderList.isEmpty) {
            return const SizedBox.shrink();
          }
          bool flag = (controller.favFolderCount ?? 0) > favFolderList.length;
          return SizedBox(
            height: 200,
            child: ListView.separated(
              controller: controller.scrollController,
              padding: const .only(left: 20, top: 10, right: 20),
              itemCount: response.list.length + (flag ? 1 : 0),
              itemBuilder: (context, index) {
                if (flag && index == favFolderList.length) {
                  return Padding(
                    padding: const .only(bottom: 35),
                    child: Center(
                      child: IconButton(
                        tooltip: '查看更多',
                        style: ButtonStyle(
                          padding: const WidgetStatePropertyAll(.zero),
                          backgroundColor: WidgetStatePropertyAll(
                            theme.colorScheme.secondaryContainer.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        onPressed: () =>
                            Get.toNamed('/fav')?.whenComplete(_autoRefresh),
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          size: 18,
                          color: secondary,
                        ),
                      ),
                    ),
                  );
                } else {
                  return FavFolderItem(
                    heroTag: Utils.generateRandomString(8),
                    item: response.list[index],
                    onPop: _autoRefresh,
                  );
                }
              },
              scrollDirection: .horizontal,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
            ),
          );
        },
      ),
      Error(:final errMsg) => SizedBox(
        height: 160,
        child: Center(
          child: Text(
            errMsg ?? '',
            textAlign: .center,
          ),
        ),
      ),
    };
  }
}

class _LoopVideoBg extends StatefulWidget {
  const _LoopVideoBg({
    super.key,
    required this.file,
    required this.playing,
    required this.loop,
  });

  final File file;
  final bool playing;
  final bool loop;

  @override
  State<_LoopVideoBg> createState() => _LoopVideoBgState();
}

class _LoopVideoBgState extends State<_LoopVideoBg>
    with WidgetsBindingObserver {
  Player? _player;
  VideoController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    Player? initializingPlayer;
    try {
      initializingPlayer = await Player.create();
      final controller = await VideoController.create(initializingPlayer);
      if (!mounted) {
        initializingPlayer.dispose();
        return;
      }
      final player = initializingPlayer;
      _player = player;
      _controller = controller;
      initializingPlayer = null;
      await player.setVolume(0);
      await player.setPlaylistMode(
        widget.loop ? PlaylistMode.loop : PlaylistMode.none,
      );
      await player.open(
        Media(Uri.file(widget.file.path).toString()),
        play: widget.playing,
      );
      if (mounted) setState(() {});
    } catch (_) {
      initializingPlayer?.dispose();
      _player?.dispose();
      _player = null;
      _controller = null;
    }
  }

  @override
  void didUpdateWidget(covariant _LoopVideoBg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) {
      widget.playing ? _player?.play() : _player?.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.playing) {
      _player?.play();
    } else if (state != AppLifecycleState.resumed) {
      _player?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player?.dispose();
    _player = null;
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SimpleVideo(controller: controller, fill: Colors.transparent),
      ),
    );
  }
}

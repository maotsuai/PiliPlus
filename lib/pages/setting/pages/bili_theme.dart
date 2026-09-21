import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models_new/bili_theme/asset_list.dart';
import 'package:PiliPlus/services/bili_theme_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class BiliThemePage extends StatefulWidget {
  const BiliThemePage({super.key});

  @override
  State<BiliThemePage> createState() => _BiliThemePageState();
}

class _BiliThemePageState extends State<BiliThemePage> {
  final service = BiliThemeService.instance;

  @override
  void initState() {
    super.initState();
    if (Accounts.main.isLogin) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _refresh(showError: false),
      );
    }
  }

  Future<void> _refresh({bool showError = true}) async {
    final error = await service.refreshAssets();
    if (showError && error != null) SmartDialog.showToast(error);
  }

  Future<void> _refreshFromUi() => _refresh();

  Future<void> _apply(BiliThemeItem item) async {
    SmartDialog.showLoading(msg: '正在下载并应用装扮…');
    String? error;
    try {
      error = await service.applyTheme(item);
    } catch (exception) {
      error = '应用主题失败：$exception';
    } finally {
      SmartDialog.dismiss();
    }
    SmartDialog.showToast(error ?? '装扮已应用');
  }

  Future<void> _sync() async {
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    SmartDialog.showLoading(msg: '正在同步当前装扮…');
    String? error;
    try {
      error = await service.syncEquippedTheme();
    } catch (exception) {
      error = '同步当前装扮失败：$exception';
    } finally {
      SmartDialog.dismiss();
    }
    SmartDialog.showToast(error ?? '已同步并应用当前装扮');
  }

  Future<void> _openThemeCenter() async {
    if (!Accounts.main.isLogin) {
      SmartDialog.showToast('请先登录');
      return;
    }
    await Get.toNamed(
      '/webview',
      parameters: {
        'url': 'https://www.bilibili.com/h5/mall/skin/setting?navhide=1',
        'uaType': 'mob',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('B站个性主题'),
        actions: [
          IconButton(
            tooltip: '同步当前装扮',
            onPressed: _sync,
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: '刷新已购装扮',
            onPressed: _refreshFromUi,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        final items = service.assets
            .map((asset) => asset.item)
            .whereType<BiliThemeItem>()
            .toList();
        final appliedLabel = service.appliedName ?? service.appliedId.value;
        const noThemeHint = '请先从下方选择装扮，或同步B站当前装扮';
        return RefreshIndicator(
          onRefresh: _refreshFromUi,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom + 80,
            ),
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome_outlined),
                title: const Text('启用个性主题'),
                subtitle: Text(
                  service.hasAppliedTheme
                      ? '当前：$appliedLabel'
                      : noThemeHint,
                ),
                value: service.enabled.value,
                onChanged: (value) {
                  if (value && !service.hasAppliedTheme) {
                    SmartDialog.showToast('请先应用一个装扮');
                    return;
                  }
                  service.setEnabled(value);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.animated_images_outlined),
                title: const Text('我的页动态背景'),
                subtitle: const Text(
                  '使用主题包内视频；缺失时自动使用静态图',
                ),
                value: service.mineVideo.value,
                onChanged: service.setMineVideo,
              ),
              ListTile(
                leading: const Icon(Icons.opacity_outlined),
                title: const Text('首页背景遮罩浓度'),
                subtitle: Slider(
                  value: service.bgOpacity.value,
                  divisions: 20,
                  label: '${(service.bgOpacity.value * 100).round()}%',
                  onChanged: (value) => service.bgOpacity.value = value,
                  onChangeEnd: service.setBgOpacity,
                ),
                trailing: Text('${(service.bgOpacity.value * 100).round()}%'),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_browser_outlined),
                title: const Text('装扮中心（H5）'),
                subtitle: const Text(
                  '在B站官方页面换装，'
                  '返回后点击“同步当前装扮”',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openThemeCenter,
              ),
              const Divider(height: 24),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '已购装扮',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (service.isLoading.value)
                const LinearProgressIndicator()
              else if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      service.lastError.value ??
                          (Accounts.main.isLogin
                              ? '暂无可用装扮'
                              : '登录后可获取已购装扮'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...items.map(_buildThemeTile),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildThemeTile(BiliThemeItem item) {
    final properties = item.properties;
    final cover = properties.imageCover ?? properties.imagePreview;
    final selected = service.appliedId.value == item.itemId &&
        service.appliedVer.value == properties.ver;
    return ListTile(
      minVerticalPadding: 8,
      leading: SizedBox(
        width: 72,
        height: 52,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: cover == null
              ? const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.wallpaper_outlined),
                )
              : NetworkImgLayer(src: cover, width: 72, height: 52),
        ),
      ),
      title: Text(item.name ?? '未命名装扮'),
      subtitle: Text('版本 ${properties.ver ?? '-'}'),
      trailing: selected
          ? const Icon(Icons.check_circle)
          : const Icon(Icons.download_outlined),
      onTap: service.isApplying.value ? null : () => _apply(item),
    );
  }
}

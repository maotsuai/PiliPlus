import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models_new/bili_theme/asset_list.dart';
import 'package:PiliPlus/services/bili_theme_service.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class BiliThemePage extends StatefulWidget {
  const BiliThemePage({super.key});

  @override
  State<BiliThemePage> createState() => _BiliThemePageState();
}

class _BiliThemePageState extends State<BiliThemePage> {
  final service = Get.find<BiliThemeService>();

  @override
  void initState() {
    super.initState();
    if (service.assetList.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _refresh(silent: true),
      );
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) SmartDialog.showLoading(msg: '刷新中...');
    final err = await service.refresh();
    if (!silent) SmartDialog.dismiss();
    if (err != null) {
      SmartDialog.showToast(err);
    } else if (!silent) {
      SmartDialog.showToast('已刷新：${service.assetList.length} 个主题');
    }
  }

  Future<void> _apply(BiliThemeAssetItem asset) async {
    SmartDialog.showLoading(msg: '下载主题资源...');
    final err = await service.apply(asset);
    SmartDialog.dismiss();
    if (err == null) {
      SmartDialog.showToast('已应用「${asset.item?.name}」');
    } else {
      SmartDialog.showToast(err);
    }
  }

  Future<void> _applyEquipped() async {
    SmartDialog.showLoading(msg: '同步中...');
    final err = await service.applyEquipped();
    SmartDialog.dismiss();
    if (err == null) {
      SmartDialog.showToast('已同步 B站当前装扮');
    } else {
      SmartDialog.showToast(err);
    }
  }

  void _openH5() {
    Get.toNamed(
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
      appBar: AppBar(title: const Text('B站个性主题')),
      body: Obx(
        () => ListView(
          padding: const .only(bottom: 100),
          children: [
            SwitchListTile(
              title: const Text('启用主题装扮'),
              subtitle: Text(
                service.enabled.value
                    ? '底栏图标 / 首页背景 / 主题取色已生效'
                    : '关闭时保持 PiliPlus 原有外观',
              ),
              value: service.enabled.value,
              onChanged: service.setEnabled,
            ),
            ListTile(
              title: Row(
                children: [
                  const Expanded(child: Text('首页背景浓度')),
                  Text('${(((1 - service.bgOpacity.value)) * 100).round()}%'),
                ],
              ),
              subtitle: Slider(
                value: service.bgOpacity.value,
                min: 0.5,
                max: 1,
                onChanged: service.setBgOpacity,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.wallpaper_outlined),
              title: const Text('当前主题'),
              subtitle: Text(
                service.appliedName ??
                    (service.appliedId.value == 0
                        ? '未应用'
                        : '已应用（${service.appliedId.value}）'),
              ),
              trailing: service.appliedId.value == 0
                  ? null
                  : IconButton(
                      tooltip: '清除',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => service.clear(),
                    ),
            ),
            Padding(
              padding: const .symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新列表'),
                    onPressed: service.fetching.value
                        ? null
                        : () => _refresh(),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.sync),
                    label: const Text('同步当前装扮'),
                    onPressed: service.applying.value ? null : _applyEquipped,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_browser_outlined),
                    label: const Text('装扮中心(H5)'),
                    onPressed: _openH5,
                  ),
                ],
              ),
            ),
            if (service.fetching.value)
              const Padding(
                padding: .symmetric(horizontal: 16),
                child: LinearProgressIndicator(),
              ),
            const Divider(height: 24),
            if (service.assetList.isEmpty)
              const Padding(
                padding: .all(32),
                child: Center(
                  child: Text('暂无数据，点「刷新列表」加载已购主题'),
                ),
              )
            else
              ...service.assetList.map(_buildTile),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BiliThemeAssetItem asset) {
    final item = asset.item;
    final props = item?.properties;
    final applied = service.appliedId.value == item?.itemId;
    return ListTile(
      leading: NetworkImgLayer(
        src: props?.imageCover ?? props?.imagePreview,
        width: 48,
        height: 48,
        borderRadius: Style.mdRadius,
      ),
      title: Text(item?.name ?? '未知主题'),
      subtitle: Text(
        applied ? '当前已应用' : 'ID: ${item?.itemId}',
        style: applied
            ? TextStyle(color: Theme.of(context).colorScheme.primary)
            : null,
      ),
      trailing: applied
          ? Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : TextButton(
              onPressed: service.applying.value ? null : () => _apply(asset),
              child: const Text('应用'),
            ),
      onTap: applied ? null : () => _apply(asset),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/http/bili_theme.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/bili_theme/asset_list.dart';
import 'package:PiliPlus/utils/bili_theme_color.dart';
import 'package:PiliPlus/utils/extension/box_ext.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' show Color;
import 'package:path/path.dart' as path;

/// B站个性主题（装扮）资源服务
///
/// - 已购列表：/x/garb/user/asset/list（cookie 认证）
/// - 当前装备：/x/resource/show/skin（access_key 签名，mobi_app=android）
/// - 主题包：CDN ZIP 匿名下载，md5 校验后解压至本地目录
class BiliThemeService extends GetxService {
  static BiliThemeService get instance => Get.find<BiliThemeService>();

  /// 总开关
  final RxBool enabled = false.obs;

  /// 首页背景的 surface 遮罩透明度（越大背景越淡）
  final RxDouble bgOpacity = 0.85.obs;

  /// 我的页使用动态视频背景
  final RxBool mineVideo = true.obs;

  /// 当前应用的主题 id / ver
  final RxInt appliedId = 0.obs;
  final RxInt appliedVer = 0.obs;

  /// 已购主题列表
  final RxList<BiliThemeAssetItem> assetList = <BiliThemeAssetItem>[].obs;

  final RxBool fetching = false.obs;
  final RxBool applying = false.obs;

  int _seed = 0;

  late final String _themeDir = path.join(appSupportDirPath, 'bili_theme');

  @override
  void onInit() {
    super.onInit();
    final setting = GStorage.setting;
    enabled.value =
        setting.get(SettingBoxKey.biliThemeEnabled, defaultValue: false) as bool;
    bgOpacity.value =
        (setting.get(SettingBoxKey.biliThemeBgOpacity, defaultValue: 0.85)
                as num)
            .toDouble();
    mineVideo.value =
        setting.get(SettingBoxKey.biliThemeMineVideo, defaultValue: true)
            as bool;
    appliedId.value =
        setting.get(SettingBoxKey.biliThemeAppliedId, defaultValue: 0) as int;
    appliedVer.value =
        setting.get(SettingBoxKey.biliThemeAppliedVer, defaultValue: 0) as int;
    _seed = setting.get(SettingBoxKey.biliThemeSeed, defaultValue: 0) as int;
    final cached = setting.get(SettingBoxKey.biliThemeAssets);
    if (cached is String && cached.isNotEmpty) {
      try {
        assetList.assignAll(
          (jsonDecode(cached) as List).map(
            (e) => BiliThemeAssetItem.fromJson(e as Map<String, dynamic>),
          ),
        );
      } catch (_) {}
    }
  }

  /// 当前主题的属性（配色等），列表未恢复时为 null
  BiliThemeProperties? get appliedProperties {
    final id = appliedId.value;
    if (id == 0) return null;
    for (final e in assetList) {
      if (e.item?.itemId == id) return e.item?.properties;
    }
    return null;
  }

  String? get appliedName {
    final id = appliedId.value;
    if (id == 0) return null;
    for (final e in assetList) {
      if (e.item?.itemId == id) return e.item?.name;
    }
    return null;
  }

  /// Monet 种子色（从主题背景图提取）
  Color? get seedColor =>
      enabled.value && appliedId.value != 0 && _seed != 0
      ? Color(_seed)
      : null;

  // ---------------- 资源文件 ----------------

  File? _assetFile(String name) {
    if (appliedId.value == 0) return null;
    final file = File(
      path.join(_themeDir, '${appliedId.value}', '${appliedVer.value}', name),
    );
    return file.existsSync() ? file : null;
  }

  /// 首页顶栏背景
  File? get homeBg => _assetFile('head_bg.png');

  /// 顶部分类标签背景
  File? get headTabBg => _assetFile('head_tab_bg.png');

  /// 我的页静态背景
  File? get mineBg => _assetFile('head_myself_squared_bg.png');

  /// 我的页动态背景（mp4）
  File? get mineVideoBg => _assetFile('head_myself_mp4_bg.mp4');

  /// 底栏背景
  File? get tailBg => _assetFile('tail_bg.png');

  /// 底栏图标；[type]: main / dynamic / myself / channel / shop
  File? tailIcon(String type, bool selected) =>
      _assetFile('tail_icon_${selected ? 'selected_' : ''}$type.png');

  // ---------------- 操作 ----------------

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await GStorage.setting.put(SettingBoxKey.biliThemeEnabled, value);
    Get.updateMyAppTheme();
  }

  Future<void> setBgOpacity(double value) async {
    bgOpacity.value = value;
    await GStorage.setting.put(SettingBoxKey.biliThemeBgOpacity, value);
  }

  Future<void> setMineVideo(bool value) async {
    mineVideo.value = value;
    await GStorage.setting.put(SettingBoxKey.biliThemeMineVideo, value);
  }

  /// 刷新已购主题列表
  Future<String?> refresh() async {
    if (fetching.value) return null;
    fetching.value = true;
    try {
      final res = await BiliThemeHttp.assetList();
      switch (res) {
        case Success(:final response):
          assetList.assignAll(response);
          await GStorage.setting.put(
            SettingBoxKey.biliThemeAssets,
            jsonEncode(response.map((e) => e.toJson()).toList()),
          );
          return null;
        case Error(:final errMsg):
          return errMsg;
        case Loading():
          return null;
      }
    } finally {
      fetching.value = false;
    }
  }

  /// 下载并应用主题：ZIP → md5 校验 → 解压 → 记录状态 → 提取种子色
  Future<String?> apply(BiliThemeAssetItem asset) async {
    if (applying.value) return '正在应用中，请稍候';
    final item = asset.item;
    final props = item?.properties;
    final itemId = item?.itemId;
    final url = props?.packageUrl;
    if (itemId == null || props == null) return '主题数据异常';
    if (url == null || url.isEmpty) return '该主题没有资源包';
    applying.value = true;
    try {
      final res = await Request().dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) return '下载失败';
      final md5Hex = props.packageMd5;
      if (md5Hex != null && md5Hex.isNotEmpty) {
        if (md5.convert(bytes).toString() != md5Hex) {
          return '资源校验失败，请重试';
        }
      }
      final dir = Directory(path.join(_themeDir, '$itemId', '${props.ver}'));
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
      await dir.create(recursive: true);
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final outFile = File(path.join(dir.path, file.name));
        await outFile.create(recursive: true);
        final dynamic content = file.content;
        if (content is List<int>) {
          await outFile.writeAsBytes(content);
        }
      }

      appliedId.value = itemId;
      appliedVer.value = int.tryParse(props.ver ?? '') ?? 0;

      final bg = homeBg ?? mineBg;
      _seed = bg == null ? 0 : (await extractSeedColorFromImage(bg) ?? 0);

      await GStorage.setting.putAllNE({
        SettingBoxKey.biliThemeAppliedId: appliedId.value,
        SettingBoxKey.biliThemeAppliedVer: appliedVer.value,
        SettingBoxKey.biliThemeSeed: _seed,
      });
      Get.updateMyAppTheme();
      return null;
    } catch (e) {
      return '应用失败：$e';
    } finally {
      applying.value = false;
    }
  }

  /// 停止使用（保留已下载文件）
  Future<void> clear() async {
    appliedId.value = 0;
    appliedVer.value = 0;
    _seed = 0;
    await GStorage.setting.putAllNE({
      SettingBoxKey.biliThemeAppliedId: 0,
      SettingBoxKey.biliThemeAppliedVer: 0,
      SettingBoxKey.biliThemeSeed: 0,
    });
    Get.updateMyAppTheme();
  }

  /// 读取 B站当前装备的装扮并应用
  Future<String?> applyEquipped() async {
    final res = await BiliThemeHttp.equipped();
    switch (res) {
      case Success(:final response):
        final equip = response;
        if (equip?.id == null) return 'B站当前未装备个性主题';
        final id = equip!.id;
        final asset = assetList.firstWhereOrNull(
          (e) => e.item?.itemId == id,
        );
        if (asset == null) return '未在已购列表中找到该主题，请先刷新列表';
        return apply(asset);
      case Error(:final errMsg):
        return errMsg;
      case Loading():
        return null;
    }
  }
}

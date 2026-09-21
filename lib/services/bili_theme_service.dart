import 'dart:io';

import 'package:PiliPlus/http/bili_theme.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/bili_theme/asset_list.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/bili_theme_color.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

class BiliThemeService extends GetxService {
  static BiliThemeService get instance => Get.find<BiliThemeService>();

  final enabled = false.obs;
  final bgOpacity = 0.85.obs;
  final mineVideo = false.obs;
  final assets = <BiliThemeAssetItem>[].obs;
  final appliedId = Rxn<String>();
  final appliedVer = Rxn<String>();
  final seedColor = Rxn<int>();
  final isLoading = false.obs;
  final isApplying = false.obs;
  final lastError = Rxn<String>();
  final resourceRevision = 0.obs;

  bool get hasAppliedTheme =>
      appliedId.value?.isNotEmpty == true &&
      appliedVer.value?.isNotEmpty == true;

  int? get activeSeedColor =>
      enabled.value && hasAppliedTheme ? seedColor.value : null;

  String? get appliedName {
    final id = appliedId.value;
    if (id == null) return null;
    for (final asset in assets) {
      if (asset.item?.itemId == id) return asset.item?.name;
    }
    return null;
  }

  bool get loopMineVideo {
    final id = appliedId.value;
    if (id == null) return true;
    for (final asset in assets) {
      if (asset.item?.itemId == id) {
        return asset.item?.properties.headMyselfMp4Play?.toLowerCase() !=
            'once';
      }
    }
    return true;
  }

  File? get homeBg =>
      _assetFile('head_bg.png') ?? _assetFile('head_myself_squared_bg.png');
  File? get mineBg => _assetFile('head_myself_squared_bg.png');
  File? get mineVideoFile => _assetFile('head_myself_mp4_bg.mp4');

  File? tailIcon(String name, bool selected) => _assetFile(
    'tail_icon_${selected ? 'selected_' : ''}$name.png',
  );

  @override
  void onInit() {
    super.onInit();
    enabled.value = GStorage.setting.get(
      SettingBoxKey.biliThemeEnabled,
      defaultValue: false,
    );
    bgOpacity.value = (GStorage.setting.get(
      SettingBoxKey.biliThemeBgOpacity,
      defaultValue: 0.85,
    ) as num).toDouble().clamp(0.0, 1.0).toDouble();
    mineVideo.value = GStorage.setting.get(
      SettingBoxKey.biliThemeMineVideo,
      defaultValue: false,
    );
    appliedId.value = GStorage.setting.get(SettingBoxKey.biliThemeAppliedId);
    appliedVer.value = GStorage.setting.get(SettingBoxKey.biliThemeAppliedVer);
    seedColor.value = GStorage.setting.get(SettingBoxKey.biliThemeSeed);
    _restoreAssets();
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await GStorage.setting.put(SettingBoxKey.biliThemeEnabled, value);
    Get.updateMyAppTheme();
  }

  Future<void> setBgOpacity(double value) async {
    final opacity = value.clamp(0.0, 1.0).toDouble();
    bgOpacity.value = opacity;
    await GStorage.setting.put(SettingBoxKey.biliThemeBgOpacity, opacity);
  }

  Future<void> setMineVideo(bool value) async {
    mineVideo.value = value;
    await GStorage.setting.put(SettingBoxKey.biliThemeMineVideo, value);
  }

  Future<String?> refreshAssets() async {
    if (isLoading.value) return null;
    isLoading.value = true;
    lastError.value = null;
    try {
      final result = await BiliThemeHttp.assetList();
      if (result case Success(:final response)) {
        assets.assignAll(response.where((asset) => asset.item != null));
        await _persistAssets();
        return null;
      }
      final error = result.toString();
      lastError.value = error;
      return error;
    } catch (error, stackTrace) {
      logger.e(
        'Failed to load Bilibili themes',
        error: error,
        stackTrace: stackTrace,
      );
      final message = '获取主题列表失败：$error';
      lastError.value = message;
      return message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> syncEquippedTheme() async {
    if (isApplying.value) return '正在应用装扮，请稍候';
    final result = await BiliThemeHttp.equipped();
    if (!result.isSuccess) return result.toString();
    final response = result.dataOrNull;
    if (response == null) return 'B站账号当前未装备个性主题';

    if (assets.isEmpty) {
      final error = await refreshAssets();
      if (error != null && assets.isEmpty) return error;
    }

    BiliThemeItem? ownedItem;
    for (final asset in assets) {
      if (asset.item?.itemId == response.id) {
        ownedItem = asset.item;
        break;
      }
    }

    final equipItem = response.toThemeItem();
    final item = ownedItem == null
        ? equipItem
        : BiliThemeItem(
            itemId: ownedItem.itemId,
            name: ownedItem.name ?? equipItem.name,
            properties: ownedItem.properties.copyWith(
              packageUrl: equipItem.properties.packageUrl,
              packageMd5: equipItem.properties.packageMd5,
              ver: equipItem.properties.ver,
            ),
          );
    return applyTheme(item);
  }

  /// Downloads, verifies, extracts and activates [item].
  ///
  /// Returns `null` on success, otherwise a user-facing error message.
  Future<String?> applyTheme(BiliThemeItem item) async {
    if (isApplying.value) return '正在应用装扮，请稍候';
    final id = item.itemId;
    final version = item.properties.ver;
    final packageUrl = item.properties.packageUrl;
    if (id == null || id.isEmpty || version == null || version.isEmpty) {
      return '装扮信息不完整，请重新同步';
    }
    if (packageUrl == null || packageUrl.isEmpty) {
      return '该装扮没有可用的资源包';
    }

    isApplying.value = true;
    lastError.value = null;
    Directory? stagingDir;
    Directory? backupDir;
    try {
      final response = await Request.dio.get<List<int>>(
        packageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return '主题资源下载失败';

      final expectedMd5 = item.properties.packageMd5;
      if (expectedMd5?.isNotEmpty == true &&
          md5.convert(bytes).toString().toLowerCase() !=
              expectedMd5!.toLowerCase()) {
        return '资源校验失败，请重试';
      }

      final root = Directory(biliThemeDirPath);
      await root.create(recursive: true);
      final safeId = _safePathComponent(id);
      final safeVersion = _safePathComponent(version);
      final tempTimestamp = DateTime.now().microsecondsSinceEpoch;
      stagingDir = Directory(
        path.join(
          root.path,
          '.tmp-$safeId-$safeVersion-$tempTimestamp',
        ),
      );
      await stagingDir.create(recursive: true);
      await _extractArchive(bytes, stagingDir);

      final destination = Directory(
        path.join(root.path, safeId, safeVersion),
      );
      await destination.parent.create(recursive: true);
      if (destination.existsSync()) {
        final timestamp = DateTime.now().microsecondsSinceEpoch;
        backupDir = Directory(
          path.join(
            root.path,
            '.old-$safeId-$safeVersion-$timestamp',
          ),
        );
        await destination.rename(backupDir.path);
      }
      try {
        await stagingDir.rename(destination.path);
        stagingDir = null;
      } catch (_) {
        if (backupDir != null && backupDir.existsSync()) {
          await backupDir.rename(destination.path);
          backupDir = null;
        }
        rethrow;
      }
      if (backupDir != null && backupDir.existsSync()) {
        await backupDir.delete(recursive: true);
        backupDir = null;
      }

      final seedSource = _existingFile(destination, 'head_bg.png') ??
          _existingFile(destination, 'head_myself_squared_bg.png');
      int? extractedSeed;
      if (seedSource != null) {
        try {
          extractedSeed = await extractSeedColorFromImage(seedSource);
        } catch (error, stackTrace) {
          logger.w(
            'Failed to extract Bilibili theme color',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      _upsertAsset(item);
      appliedId.value = id;
      appliedVer.value = version;
      appliedVer.refresh();
      seedColor.value = extractedSeed;
      enabled.value = true;
      resourceRevision.value++;
      await _persistAssets();
      await GStorage.setting.putAll({
        SettingBoxKey.biliThemeAppliedId: id,
        SettingBoxKey.biliThemeAppliedVer: version,
        SettingBoxKey.biliThemeEnabled: true,
      });
      if (extractedSeed == null) {
        await GStorage.setting.delete(SettingBoxKey.biliThemeSeed);
      } else {
        await GStorage.setting.put(
          SettingBoxKey.biliThemeSeed,
          extractedSeed,
        );
      }
      Get.updateMyAppTheme();
      return null;
    } catch (error, stackTrace) {
      logger.e(
        'Failed to apply Bilibili theme',
        error: error,
        stackTrace: stackTrace,
      );
      final message = '应用主题失败：$error';
      lastError.value = message;
      return message;
    } finally {
      if (stagingDir != null && stagingDir.existsSync()) {
        try {
          await stagingDir.delete(recursive: true);
        } catch (error, stackTrace) {
          logger.w(
            'Failed to remove temporary Bilibili theme directory',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      isApplying.value = false;
    }
  }

  void _restoreAssets() {
    final cached = GStorage.setting.get(SettingBoxKey.biliThemeAssets);
    if (cached is! Iterable) return;
    final restored = <BiliThemeAssetItem>[];
    for (final value in cached) {
      if (value is Map) {
        try {
          restored.add(
            BiliThemeAssetItem.fromJson(Map<String, dynamic>.from(value)),
          );
        } catch (_) {}
      }
    }
    assets.assignAll(restored.where((asset) => asset.item != null));
  }

  Future<void> _persistAssets() => GStorage.setting.put(
    SettingBoxKey.biliThemeAssets,
    assets.map((asset) => asset.toJson()).toList(),
  );

  void _upsertAsset(BiliThemeItem item) {
    final index = assets.indexWhere(
      (asset) => asset.item?.itemId == item.itemId,
    );
    final asset = BiliThemeAssetItem(item: item);
    if (index == -1) {
      assets.add(asset);
    } else {
      assets[index] = asset;
    }
  }

  File? _assetFile(String name) {
    final id = appliedId.value;
    final version = appliedVer.value;
    if (id == null || version == null) return null;
    final directory = Directory(
      path.join(
        biliThemeDirPath,
        _safePathComponent(id),
        _safePathComponent(version),
      ),
    );
    return _existingFile(directory, name);
  }

  static File? _existingFile(Directory directory, String name) {
    final file = File(path.join(directory.path, name));
    return file.existsSync() ? file : null;
  }

  static Future<void> _extractArchive(
    List<int> bytes,
    Directory destination,
  ) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    var uncompressedSize = 0;
    var fileCount = 0;
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      fileCount++;
      uncompressedSize += entry.size;
      if (uncompressedSize > 100 * 1024 * 1024) {
        throw const FormatException('主题资源包解压后过大');
      }

      final relativeName = path.posix.normalize(
        entry.name.replaceAll('\\', '/'),
      );
      if (relativeName == '.' ||
          relativeName == '..' ||
          relativeName.startsWith('../') ||
          path.posix.isAbsolute(relativeName)) {
        throw const FormatException('主题资源包包含非法路径');
      }
      final outputPath = path.joinAll([
        destination.path,
        ...relativeName.split('/'),
      ]);
      if (!path.isWithin(destination.path, outputPath)) {
        throw const FormatException('主题资源包包含非法路径');
      }

      final content = entry.content;
      final output = File(outputPath);
      await output.parent.create(recursive: true);
      await output.writeAsBytes(content, flush: true);
    }
    if (fileCount == 0) {
      throw const FormatException('主题资源包为空');
    }
  }

  static String _safePathComponent(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty || safe == '.' || safe == '..' ? 'unknown' : safe;
  }
}

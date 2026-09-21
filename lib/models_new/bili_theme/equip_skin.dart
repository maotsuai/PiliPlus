import 'package:PiliPlus/models_new/bili_theme/asset_list.dart';

class BiliThemeEquipData {
  final String? id;
  final String? name;
  final String? ver;
  final String? packageUrl;
  final String? packageMd5;
  final BiliThemeProperties data;

  const BiliThemeEquipData({
    this.id,
    this.name,
    this.ver,
    this.packageUrl,
    this.packageMd5,
    this.data = const BiliThemeProperties(),
  });

  factory BiliThemeEquipData.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return BiliThemeEquipData(
      id: _asString(json['id'] ?? json['item_id']),
      name: _asString(json['name']),
      ver: _asString(json['ver']),
      packageUrl: _asString(json['package_url']),
      packageMd5: _asString(json['package_md5']),
      data: rawData is Map
          ? BiliThemeProperties.fromJson(Map<String, dynamic>.from(rawData))
          : const BiliThemeProperties(),
    );
  }

  BiliThemeItem toThemeItem() => BiliThemeItem(
    itemId: id,
    name: name,
    properties: data.copyWith(
      packageUrl: packageUrl,
      packageMd5: packageMd5,
      ver: ver,
    ),
  );
}

String? _asString(Object? value) {
  if (value == null) return null;
  final result = value.toString();
  return result.isEmpty ? null : result;
}

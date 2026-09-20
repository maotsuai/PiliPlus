/// B站当前装备的装扮
/// GET https://app.bilibili.com/x/resource/show/skin → data.user_equip
library;

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

class BiliThemeEquipData {
  BiliThemeEquipData({
    this.id,
    this.name,
    this.ver,
    this.packageUrl,
    this.packageMd5,
    this.color,
    this.colorSecondPage,
    this.tailColor,
    this.tailColorSelected,
  });

  final int? id;
  final String? name;
  final int? ver;
  final String? packageUrl;
  final String? packageMd5;
  final String? color;
  final String? colorSecondPage;
  final String? tailColor;
  final String? tailColorSelected;

  factory BiliThemeEquipData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return BiliThemeEquipData(
      id: _asInt(json['id']),
      name: json['name'] as String?,
      ver: _asInt(json['ver']),
      packageUrl: json['package_url'] as String?,
      packageMd5: json['package_md5'] as String?,
      color: data?['color'] as String?,
      colorSecondPage: data?['color_second_page'] as String?,
      tailColor: data?['tail_color'] as String?,
      tailColorSelected: data?['tail_color_selected'] as String?,
    );
  }
}

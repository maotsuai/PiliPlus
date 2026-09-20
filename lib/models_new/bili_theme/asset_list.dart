/// B站个性主题（装扮）已购资产列表
/// GET https://api.bilibili.com/x/garb/user/asset/list
library;

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

class BiliThemeAssetItem {
  BiliThemeAssetItem({this.assetId, this.assetState, this.item});

  final int? assetId;
  final String? assetState;
  final BiliThemeItem? item;

  factory BiliThemeAssetItem.fromJson(Map<String, dynamic> json) =>
      BiliThemeAssetItem(
        assetId: _asInt(json['asset_id']),
        assetState: json['asset_state'] as String?,
        item: json['item'] == null
            ? null
            : BiliThemeItem.fromJson(json['item'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
    'asset_id': assetId,
    'asset_state': assetState,
    'item': item?.toJson(),
  };
}

class BiliThemeItem {
  BiliThemeItem({
    this.itemId,
    this.name,
    this.state,
    this.suitItemId,
    this.properties,
  });

  final int? itemId;
  final String? name;
  final String? state;
  final int? suitItemId;
  final BiliThemeProperties? properties;

  factory BiliThemeItem.fromJson(Map<String, dynamic> json) => BiliThemeItem(
    itemId: _asInt(json['item_id']),
    name: json['name'] as String?,
    state: json['state'] as String?,
    suitItemId: _asInt(json['suit_item_id']),
    properties: json['properties'] == null
        ? null
        : BiliThemeProperties.fromJson(
            json['properties'] as Map<String, dynamic>,
          ),
  );

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'name': name,
    'state': state,
    'suit_item_id': suitItemId,
    'properties': properties?.toJson(),
  };
}

class BiliThemeProperties {
  BiliThemeProperties({
    this.color,
    this.colorMode,
    this.colorSecondPage,
    this.goodsType,
    this.headBg,
    this.headMyselfMp4Bg,
    this.headMyselfMp4Play,
    this.headMyselfSquaredBg,
    this.headTabBg,
    this.imageCover,
    this.imagePreview,
    this.packageMd5,
    this.packageUrl,
    this.tailBg,
    this.tailColor,
    this.tailColorSelected,
    this.tailIconChannel,
    this.tailIconDynamic,
    this.tailIconMain,
    this.tailIconMode,
    this.tailIconMyself,
    this.tailIconPubBtnBg,
    this.tailIconSelectedChannel,
    this.tailIconSelectedDynamic,
    this.tailIconSelectedMain,
    this.tailIconSelectedMyself,
    this.tailIconSelectedPubBtnBg,
    this.tailIconSelectedShop,
    this.tailIconShop,
    this.ver,
  });

  final String? color;
  final String? colorMode;
  final String? colorSecondPage;
  final String? goodsType;
  final String? headBg;
  final String? headMyselfMp4Bg;
  final String? headMyselfMp4Play;
  final String? headMyselfSquaredBg;
  final String? headTabBg;
  final String? imageCover;
  final String? imagePreview;
  final String? packageMd5;
  final String? packageUrl;
  final String? tailBg;
  final String? tailColor;
  final String? tailColorSelected;
  final String? tailIconChannel;
  final String? tailIconDynamic;
  final String? tailIconMain;
  final String? tailIconMode;
  final String? tailIconMyself;
  final String? tailIconPubBtnBg;
  final String? tailIconSelectedChannel;
  final String? tailIconSelectedDynamic;
  final String? tailIconSelectedMain;
  final String? tailIconSelectedMyself;
  final String? tailIconSelectedPubBtnBg;
  final String? tailIconSelectedShop;
  final String? tailIconShop;
  final String? ver;

  factory BiliThemeProperties.fromJson(Map<String, dynamic> json) =>
      BiliThemeProperties(
        color: json['color'] as String?,
        colorMode: json['color_mode'] as String?,
        colorSecondPage: json['color_second_page'] as String?,
        goodsType: json['goods_type'] as String?,
        headBg: json['head_bg'] as String?,
        headMyselfMp4Bg: json['head_myself_mp4_bg'] as String?,
        headMyselfMp4Play: json['head_myself_mp4_play'] as String?,
        headMyselfSquaredBg: json['head_myself_squared_bg'] as String?,
        headTabBg: json['head_tab_bg'] as String?,
        imageCover: json['image_cover'] as String?,
        imagePreview: json['image_preview'] as String?,
        packageMd5: json['package_md5'] as String?,
        packageUrl: json['package_url'] as String?,
        tailBg: json['tail_bg'] as String?,
        tailColor: json['tail_color'] as String?,
        tailColorSelected: json['tail_color_selected'] as String?,
        tailIconChannel: json['tail_icon_channel'] as String?,
        tailIconDynamic: json['tail_icon_dynamic'] as String?,
        tailIconMain: json['tail_icon_main'] as String?,
        tailIconMode: json['tail_icon_mode'] as String?,
        tailIconMyself: json['tail_icon_myself'] as String?,
        tailIconPubBtnBg: json['tail_icon_pub_btn_bg'] as String?,
        tailIconSelectedChannel: json['tail_icon_selected_channel'] as String?,
        tailIconSelectedDynamic: json['tail_icon_selected_dynamic'] as String?,
        tailIconSelectedMain: json['tail_icon_selected_main'] as String?,
        tailIconSelectedMyself: json['tail_icon_selected_myself'] as String?,
        tailIconSelectedPubBtnBg: json['tail_icon_selected_pub_btn_bg']
            as String?,
        tailIconSelectedShop: json['tail_icon_selected_shop'] as String?,
        tailIconShop: json['tail_icon_shop'] as String?,
        ver: json['ver']?.toString(),
      );

  Map<String, dynamic> toJson() => {
    'color': color,
    'color_mode': colorMode,
    'color_second_page': colorSecondPage,
    'goods_type': goodsType,
    'head_bg': headBg,
    'head_myself_mp4_bg': headMyselfMp4Bg,
    'head_myself_mp4_play': headMyselfMp4Play,
    'head_myself_squared_bg': headMyselfSquaredBg,
    'head_tab_bg': headTabBg,
    'image_cover': imageCover,
    'image_preview': imagePreview,
    'package_md5': packageMd5,
    'package_url': packageUrl,
    'tail_bg': tailBg,
    'tail_color': tailColor,
    'tail_color_selected': tailColorSelected,
    'tail_icon_channel': tailIconChannel,
    'tail_icon_dynamic': tailIconDynamic,
    'tail_icon_main': tailIconMain,
    'tail_icon_mode': tailIconMode,
    'tail_icon_myself': tailIconMyself,
    'tail_icon_pub_btn_bg': tailIconPubBtnBg,
    'tail_icon_selected_channel': tailIconSelectedChannel,
    'tail_icon_selected_dynamic': tailIconSelectedDynamic,
    'tail_icon_selected_main': tailIconSelectedMain,
    'tail_icon_selected_myself': tailIconSelectedMyself,
    'tail_icon_selected_pub_btn_bg': tailIconSelectedPubBtnBg,
    'tail_icon_selected_shop': tailIconSelectedShop,
    'tail_icon_shop': tailIconShop,
    'ver': ver,
  };
}

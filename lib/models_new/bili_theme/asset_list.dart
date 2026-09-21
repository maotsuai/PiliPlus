class BiliThemeAssetItem {
  final BiliThemeItem? item;

  const BiliThemeAssetItem({this.item});

  factory BiliThemeAssetItem.fromJson(Map<String, dynamic> json) {
    final rawItem = json['item'];
    return BiliThemeAssetItem(
      item: rawItem is Map
          ? BiliThemeItem.fromJson(Map<String, dynamic>.from(rawItem))
          : BiliThemeItem.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() => {'item': item?.toJson()};
}

class BiliThemeItem {
  final String? itemId;
  final String? name;
  final BiliThemeProperties properties;

  const BiliThemeItem({
    this.itemId,
    this.name,
    this.properties = const BiliThemeProperties(),
  });

  factory BiliThemeItem.fromJson(Map<String, dynamic> json) {
    final rawProperties = json['properties'];
    return BiliThemeItem(
      itemId: _asString(json['item_id'] ?? json['id']),
      name: _asString(json['name']),
      properties: rawProperties is Map
          ? BiliThemeProperties.fromJson(
              Map<String, dynamic>.from(rawProperties),
            )
          : const BiliThemeProperties(),
    );
  }

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'name': name,
    'properties': properties.toJson(),
  };
}

class BiliThemeProperties {
  final String? packageUrl;
  final String? packageMd5;
  final String? ver;
  final String? imageCover;
  final String? imagePreview;
  final String? color;
  final String? colorSecondPage;
  final String? tailColor;
  final String? tailColorSelected;
  final Object? colorSeries;
  final String? headBg;
  final String? headTabBg;
  final String? headMyselfSquaredBg;
  final String? headMyselfMp4Bg;
  final String? headMyselfMp4Play;
  final String? tailBg;
  final String? tailIconMain;
  final String? tailIconSelectedMain;
  final String? tailIconChannel;
  final String? tailIconSelectedChannel;
  final String? tailIconDynamic;
  final String? tailIconSelectedDynamic;
  final String? tailIconShop;
  final String? tailIconSelectedShop;
  final String? tailIconMyself;
  final String? tailIconSelectedMyself;
  final String? tailIconPubBtnBg;
  final String? tailIconPubBtnBgSelected;

  const BiliThemeProperties({
    this.packageUrl,
    this.packageMd5,
    this.ver,
    this.imageCover,
    this.imagePreview,
    this.color,
    this.colorSecondPage,
    this.tailColor,
    this.tailColorSelected,
    this.colorSeries,
    this.headBg,
    this.headTabBg,
    this.headMyselfSquaredBg,
    this.headMyselfMp4Bg,
    this.headMyselfMp4Play,
    this.tailBg,
    this.tailIconMain,
    this.tailIconSelectedMain,
    this.tailIconChannel,
    this.tailIconSelectedChannel,
    this.tailIconDynamic,
    this.tailIconSelectedDynamic,
    this.tailIconShop,
    this.tailIconSelectedShop,
    this.tailIconMyself,
    this.tailIconSelectedMyself,
    this.tailIconPubBtnBg,
    this.tailIconPubBtnBgSelected,
  });

  factory BiliThemeProperties.fromJson(Map<String, dynamic> json) =>
      BiliThemeProperties(
        packageUrl: _asString(json['package_url']),
        packageMd5: _asString(json['package_md5']),
        ver: _asString(json['ver']),
        imageCover: _asString(json['image_cover']),
        imagePreview: _asString(json['image_preview']),
        color: _asString(json['color']),
        colorSecondPage: _asString(json['color_second_page']),
        tailColor: _asString(json['tail_color']),
        tailColorSelected: _asString(json['tail_color_selected']),
        colorSeries: json['color_series'],
        headBg: _asString(json['head_bg']),
        headTabBg: _asString(json['head_tab_bg']),
        headMyselfSquaredBg: _asString(json['head_myself_squared_bg']),
        headMyselfMp4Bg: _asString(json['head_myself_mp4_bg']),
        headMyselfMp4Play: _asString(json['head_myself_mp4_play']),
        tailBg: _asString(json['tail_bg']),
        tailIconMain: _asString(json['tail_icon_main']),
        tailIconSelectedMain: _asString(json['tail_icon_selected_main']),
        tailIconChannel: _asString(json['tail_icon_channel']),
        tailIconSelectedChannel: _asString(
          json['tail_icon_selected_channel'],
        ),
        tailIconDynamic: _asString(json['tail_icon_dynamic']),
        tailIconSelectedDynamic: _asString(
          json['tail_icon_selected_dynamic'],
        ),
        tailIconShop: _asString(json['tail_icon_shop']),
        tailIconSelectedShop: _asString(json['tail_icon_selected_shop']),
        tailIconMyself: _asString(json['tail_icon_myself']),
        tailIconSelectedMyself: _asString(
          json['tail_icon_selected_myself'],
        ),
        tailIconPubBtnBg: _asString(json['tail_icon_pub_btn_bg']),
        tailIconPubBtnBgSelected: _asString(
          json['tail_icon_pub_btn_bg_selected'],
        ),
      );

  BiliThemeProperties copyWith({
    String? packageUrl,
    String? packageMd5,
    String? ver,
  }) => BiliThemeProperties(
    packageUrl: packageUrl ?? this.packageUrl,
    packageMd5: packageMd5 ?? this.packageMd5,
    ver: ver ?? this.ver,
    imageCover: imageCover,
    imagePreview: imagePreview,
    color: color,
    colorSecondPage: colorSecondPage,
    tailColor: tailColor,
    tailColorSelected: tailColorSelected,
    colorSeries: colorSeries,
    headBg: headBg,
    headTabBg: headTabBg,
    headMyselfSquaredBg: headMyselfSquaredBg,
    headMyselfMp4Bg: headMyselfMp4Bg,
    headMyselfMp4Play: headMyselfMp4Play,
    tailBg: tailBg,
    tailIconMain: tailIconMain,
    tailIconSelectedMain: tailIconSelectedMain,
    tailIconChannel: tailIconChannel,
    tailIconSelectedChannel: tailIconSelectedChannel,
    tailIconDynamic: tailIconDynamic,
    tailIconSelectedDynamic: tailIconSelectedDynamic,
    tailIconShop: tailIconShop,
    tailIconSelectedShop: tailIconSelectedShop,
    tailIconMyself: tailIconMyself,
    tailIconSelectedMyself: tailIconSelectedMyself,
    tailIconPubBtnBg: tailIconPubBtnBg,
    tailIconPubBtnBgSelected: tailIconPubBtnBgSelected,
  );

  Map<String, dynamic> toJson() => {
    'package_url': packageUrl,
    'package_md5': packageMd5,
    'ver': ver,
    'image_cover': imageCover,
    'image_preview': imagePreview,
    'color': color,
    'color_second_page': colorSecondPage,
    'tail_color': tailColor,
    'tail_color_selected': tailColorSelected,
    'color_series': colorSeries,
    'head_bg': headBg,
    'head_tab_bg': headTabBg,
    'head_myself_squared_bg': headMyselfSquaredBg,
    'head_myself_mp4_bg': headMyselfMp4Bg,
    'head_myself_mp4_play': headMyselfMp4Play,
    'tail_bg': tailBg,
    'tail_icon_main': tailIconMain,
    'tail_icon_selected_main': tailIconSelectedMain,
    'tail_icon_channel': tailIconChannel,
    'tail_icon_selected_channel': tailIconSelectedChannel,
    'tail_icon_dynamic': tailIconDynamic,
    'tail_icon_selected_dynamic': tailIconSelectedDynamic,
    'tail_icon_shop': tailIconShop,
    'tail_icon_selected_shop': tailIconSelectedShop,
    'tail_icon_myself': tailIconMyself,
    'tail_icon_selected_myself': tailIconSelectedMyself,
    'tail_icon_pub_btn_bg': tailIconPubBtnBg,
    'tail_icon_pub_btn_bg_selected': tailIconPubBtnBgSelected,
  };
}

String? _asString(Object? value) {
  if (value == null) return null;
  final result = value.toString();
  return result.isEmpty ? null : result;
}

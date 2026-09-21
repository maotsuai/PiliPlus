import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/bili_theme/asset_list.dart';
import 'package:PiliPlus/models_new/bili_theme/equip_skin.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/app_sign.dart';

abstract final class BiliThemeHttp {
  static const _pageSize = 100;

  /// All active skins owned by the current account.
  static Future<LoadingState<List<BiliThemeAssetItem>>> assetList() async {
    if (!Accounts.main.isLogin) {
      return const Error('请先登录后获取装扮');
    }

    final result = <BiliThemeAssetItem>[];
    for (var page = 1; page <= 20; page++) {
      final res = await Request().get(
        Api.biliThemeAssetList,
        queryParameters: {
          'part': 'skin',
          'pn': page,
          'ps': _pageSize,
          'state': 'active',
          'csrf': Accounts.main.csrf,
        },
      );
      final json = _asJsonMap(res.data);
      if (json?['code'] != 0) {
        return Error(_errorMessage(json, '获取主题列表失败'));
      }

      final data = _asJsonMap(json?['data']);
      final rawList = data?['list'];
      if (rawList is! List) break;
      for (final value in rawList) {
        final item = _asJsonMap(value);
        if (item != null) {
          result.add(BiliThemeAssetItem.fromJson(item));
        }
      }
      if (rawList.length < _pageSize) break;
    }
    return Success(result);
  }

  /// The skin currently equipped in the official Bilibili client.
  static Future<LoadingState<BiliThemeEquipData?>> equipped() async {
    final accessKey = Accounts.main.accessKey;
    if (accessKey == null || accessKey.isEmpty) {
      return const Error('登录凭据已失效，请重新登录');
    }

    final params = <String, dynamic>{
      'access_key': accessKey,
      'build': 8980200,
      'mobi_app': 'android',
      'platform': 'android',
      'is_free_theme': 1,
    };
    AppSign.appSign(params);
    final res = await Request().get(
      Api.biliThemeEquipSkin,
      queryParameters: params,
    );
    final json = _asJsonMap(res.data);
    if (json?['code'] != 0) {
      return Error(_errorMessage(json, '同步当前装扮失败'));
    }

    final data = _asJsonMap(json?['data']);
    final equip = _asJsonMap(data?['user_equip']);
    if (equip == null ||
        equip.isEmpty ||
        equip['id'] == 0 ||
        equip['id'] == '0') {
      return const Success(null);
    }
    return Success(BiliThemeEquipData.fromJson(equip));
  }

  static Map<String, dynamic>? _asJsonMap(Object? value) => value is Map
      ? Map<String, dynamic>.from(value)
      : null;

  static String _errorMessage(
    Map<String, dynamic>? json,
    String fallback,
  ) =>
      json?['message']?.toString() ??
      json?['msg']?.toString() ??
      fallback;
}

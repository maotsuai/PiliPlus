import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/bili_theme/asset_list.dart';
import 'package:PiliPlus/models_new/bili_theme/equip_skin.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/app_sign.dart';

abstract final class BiliThemeHttp {
  /// 已购个性主题列表（cookie 认证）
  static Future<LoadingState<List<BiliThemeAssetItem>>> assetList() async {
    if (!Accounts.main.isLogin) {
      return Error('请先登录后再使用');
    }
    final res = await Request().get(
      Api.biliThemeAssetList,
      queryParameters: {
        'part': 'skin',
        'pn': 1,
        'ps': 100,
        'state': 'active',
        'csrf': Accounts.main.csrf,
      },
    );
    if (res.data['code'] == 0) {
      final list = (res.data['data']?['list'] as List?)
          ?.map((e) => BiliThemeAssetItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return Success(list ?? []);
    }
    return Error(
      res.data['message']?.toString() ??
          res.data['msg']?.toString() ??
          '获取主题列表失败',
    );
  }

  /// B站当前装备的装扮（access_key 签名，mobi_app 必须为 android）
  static Future<LoadingState<BiliThemeEquipData?>> equipped() async {
    final accessKey = Accounts.main.accessKey;
    if (accessKey == null || accessKey.isEmpty) {
      return Error('登录状态异常，请重新登录后再试');
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
    if (res.data['code'] == 0) {
      final equip = res.data['data']?['user_equip'];
      return Success(
        equip == null
            ? null
            : BiliThemeEquipData.fromJson(equip as Map<String, dynamic>),
      );
    }
    return Error(res.data['message']?.toString() ?? '同步当前装扮失败');
  }
}

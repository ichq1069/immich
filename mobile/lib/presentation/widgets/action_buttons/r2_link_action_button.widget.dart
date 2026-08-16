import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:immich_mobile/providers/timeline/multiselect.provider.dart';
import 'package:immich_mobile/services/r2_link.service.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';

class R2LinkActionButton extends ConsumerWidget {
  final ActionSource source;
  final bool iconOnly;
  final bool menuItem;

  const R2LinkActionButton({super.key, required this.source, this.iconOnly = false, this.menuItem = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = Icon(Icons.link, color: Colors.white, size: iconOnly ? null : 20);
    final label = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: const Text('R2 直链', style: TextStyle(color: Colors.white)),
    );

    return menuItem
        ? MenuItemButton(
            onPressed: () => _onTap(context, ref),
            child: Row(children: [icon, const SizedBox(width: 8), label]),
          )
        : iconOnly
            ? IconButton(onPressed: () => _onTap(context, ref), icon: icon)
            : TextButton(onPressed: () => _onTap(context, ref), child: Row(children: [icon, const SizedBox(width: 4), label]));
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;

    final multiselect = ref.read(multiSelectProvider);
    final ids = multiselect.selectedAssets
        .where((a) => a.storage == AssetState.remote || a.storage == AssetState.merged)
        .map((a) => a.remoteId)
        .whereType<String>()
        .toList();

    if (ids.isEmpty) {
      ImmichToast.show(msg: '没有远程资产可创建直链', context: context);
      return;
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      final r2Service = R2LinkService(apiService);
      final links = await r2Service.createLinks(assetIds: ids, expiresIn: '24h');
      if (context.mounted) {
        ImmichToast.show(msg: '已生成 ${links.length} 条直链', context: context);
      }
    } catch (e) {
      if (context.mounted) {
        ImmichToast.show(msg: '创建直链失败: $e', context: context);
      }
    }
  }
}
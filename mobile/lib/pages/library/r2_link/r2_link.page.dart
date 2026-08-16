import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:immich_mobile/services/r2_link.service.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

@RoutePage()
class R2LinkPage extends ConsumerStatefulWidget {
  const R2LinkPage({super.key});

  @override
  ConsumerState<R2LinkPage> createState() => _R2LinkPageState();
}

class _R2LinkPageState extends ConsumerState<R2LinkPage> {
  List<R2LinkResponseDto> _links = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final r2Service = R2LinkService(apiService);
      final links = await r2Service.getLinks();
      if (mounted) {
        setState(() {
          _links = links.where((l) => l.revokedAt == null).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ImmichToast.show(msg: '加载直链失败: $e', context: context);
      }
    }
  }

  Future<void> _copyLink(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ImmichToast.show(msg: '链接已复制到剪贴板', context: context);
      }
    } catch (e) {
      if (mounted) {
        ImmichToast.show(msg: '复制失败: $e', context: context);
      }
    }
  }

  Future<void> _revokeLink(String id) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final r2Service = R2LinkService(apiService);
      await r2Service.revokeLink(id);
      if (mounted) {
        ImmichToast.show(msg: '直链已撤销', context: context);
        _loadLinks();
      }
    } catch (e) {
      if (mounted) {
        ImmichToast.show(msg: '撤销失败: $e', context: context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('R2 直链管理'),
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _links.isEmpty
                ? _buildEmptyState()
                : _buildLinksList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 100, color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
          const SizedBox(height: 20),
          const Text('暂无 R2 直链', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          const Text('在照片或视频上点击"R2 直链"按钮创建', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLinksList() {
    return ListView.separated(
      key: const PageStorageKey('r2-links-list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _links.length,
      itemBuilder: (context, index) => _buildLinkItem(_links[index]),
      separatorBuilder: (context, index) => const Divider(height: 1),
    );
  }

  Widget _buildLinkItem(R2LinkResponseDto link) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final isExpired = link.expiresAt != null && link.expiresAt!.isBefore(DateTime.now());
    final expiresText = link.expiresAt != null
        ? (isExpired ? '已过期' : '过期时间: ${dateFormat.format(link.expiresAt!)}')
        : '永久有效';

    return ListTile(
      leading: Icon(
        Icons.link,
        color: isExpired ? Colors.grey : Colors.green,
      ),
      title: Text(
        link.url.split('/').last,
        style: TextStyle(
          fontSize: 12,
          color: isExpired ? Colors.grey : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        expiresText,
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: isExpired ? null : () => _copyLink(link.url),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: isExpired ? null : () => launchUrl(Uri.parse(link.url)),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
            onPressed: () => _confirmRevoke(link),
          ),
        ],
      ),
    );
  }

  void _confirmRevoke(R2LinkResponseDto link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤销直链'),
        content: const Text('确定要撤销此直链吗？撤销后链接将立即失效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _revokeLink(link.id);
            },
            child: const Text('撤销', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
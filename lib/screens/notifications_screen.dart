import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../domain/social.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/ui_bits.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _refreshing = false;
  DateTime? _lastRefreshed;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await AppScope.read(context).refreshSocialGraph();
      if (mounted) setState(() => _lastRefreshed = DateTime.now());
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final items = store.activeNotifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            tooltip: 'Refresh notifications',
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            const ScreenTitle(
              title: 'Activity',
              subtitle:
                  'New app sessions sync once automatically. While the app stays open, use Refresh for new requests.',
            ),
            const SizedBox(height: 12),
            _RefreshStrip(
              refreshing: _refreshing,
              lastRefreshed: _lastRefreshed,
              onRefresh: _refresh,
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.notifications_none_rounded),
                  title: Text('Nothing new'),
                  subtitle: Text(
                    'If someone just sent a request while you were using CricXii, tap Refresh.',
                  ),
                ),
              ),
            if (items.isNotEmpty)
              ...items.map((item) => _NotificationCard(item: item)),
          ],
        ),
      ),
    );
  }
}

class _RefreshStrip extends StatelessWidget {
  const _RefreshStrip({
    required this.refreshing,
    required this.lastRefreshed,
    required this.onRefresh,
  });

  final bool refreshing;
  final DateTime? lastRefreshed;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F7F3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDCEBE3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.sync_rounded, color: AppColors.greenDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            lastRefreshed == null
                ? 'Cached activity is shown. Refresh only when you need the latest.'
                : 'Refreshed at ${_time(lastRefreshed!)}',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: refreshing ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
      ],
    ),
  );

  static String _time(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final CricNotification item;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    FriendRequest? request;
    for (final candidate in store.incomingFriendRequests) {
      if (candidate.id == item.referenceId) request = candidate;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        color: item.read ? Colors.white : const Color(0xFFEAF8F1),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    item.type == NotificationType.friendRequest
                        ? Icons.person_add_alt_1_rounded
                        : Icons.notifications_active_outlined,
                    color: AppColors.greenDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (!item.read)
                    const Icon(
                      Icons.circle,
                      size: 10,
                      color: AppColors.greenDark,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(item.body, style: const TextStyle(height: 1.35)),
              if (request != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await AppScope.read(context).respondToFriendRequest(
                            request!.id,
                            accept: false,
                          );
                        },
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await AppScope.read(context).respondToFriendRequest(
                            request!.id,
                            accept: true,
                          );
                        },
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ] else if (!item.read) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => store.markNotificationRead(item.id),
                    child: const Text('Mark read'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

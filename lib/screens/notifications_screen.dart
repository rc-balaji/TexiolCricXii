import 'package:flutter/material.dart';

import '../domain/enums.dart';
import '../domain/social.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/ui_bits.dart';
import 'public_player_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _refreshing = false;
  bool _deleting = false;
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


  Future<void> _deleteAll() async {
    final store = AppScope.read(context);
    if (_deleting || store.activeNotifications.isEmpty) return;
    final hasPending = store.incomingFriendRequests.isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all notifications?'),
        content: Text(
          hasPending
              ? 'All visible notifications will be deleted. Pending incoming friend requests will be rejected first.'
              : 'All visible notifications will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await store.deleteAllNotifications();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
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
            onPressed: items.isEmpty || _deleting ? null : _deleteAll,
            tooltip: 'Delete all notifications',
            icon: _deleting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_sweep_outlined),
          ),
          IconButton(
            onPressed: _refreshing || _deleting ? null : _refresh,
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
                  'Notifications sync when you sign in. While the app is already open, use Refresh only when you want the latest requests.',
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
                    'If someone just sent or accepted a request, tap Refresh.',
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
                ? 'Showing cached activity. Refresh for new requests.'
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

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({required this.item});

  final CricNotification item;

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _busy = false;

  CricNotification get item => widget.item;

  Future<void> _do(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    FriendRequest? request;
    for (final candidate in store.incomingFriendRequests) {
      if (candidate.id == item.referenceId) request = candidate;
    }
    final status = item.actionStatus;
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
                        : Icons.how_to_reg_rounded,
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
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.circle,
                        size: 10,
                        color: AppColors.greenDark,
                      ),
                    ),
                  PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (value) {
                      if (value == 'read') {
                        _do(() => store.markNotificationRead(item.id));
                      } else if (value == 'unread') {
                        _do(() => store.markNotificationUnread(item.id));
                      } else if (value == 'delete') {
                        _do(() => store.deleteNotification(item.id));
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: item.read ? 'unread' : 'read',
                        child: Text(item.read ? 'Mark unread' : 'Mark read'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          request != null && status == 'pending'
                              ? 'Reject & delete'
                              : 'Delete notification',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(item.body, style: const TextStyle(height: 1.35)),
              if ((item.fromPlayerId ?? request?.fromPlayerId) != null) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => openPlayerProfile(
                          context,
                          item.fromPlayerId ?? request!.fromPlayerId,
                        ),
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
                  label: const Text('View player profile'),
                ),
              ],
              if (status == 'accepted' || status == 'rejected') ...[
                const SizedBox(height: 10),
                _StatusChip(status: status!),
              ],
              if (request != null && status != 'accepted' && status != 'rejected') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _do(
                                () => store.respondToFriendRequest(
                                  request!.id,
                                  accept: false,
                                ),
                              ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _do(
                                () => store.respondToFriendRequest(
                                  request!.id,
                                  accept: true,
                                ),
                              ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final accepted = status == 'accepted';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accepted
            ? const Color(0xFFE5F6ED)
            : const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        accepted ? 'ACCEPTED' : 'REJECTED',
        style: TextStyle(
          color: accepted ? AppColors.greenDark : Colors.red.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    );
  }
}

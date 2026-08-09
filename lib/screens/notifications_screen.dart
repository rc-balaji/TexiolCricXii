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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).refreshSocialGraph();
    });
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
            onPressed: store.refreshSocialGraph,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: store.refreshSocialGraph,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            const ScreenTitle(
              title: 'Activity',
              subtitle: 'Friend requests and account updates appear here.',
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.notifications_none_rounded),
                  title: Text('Nothing new'),
                  subtitle: Text('Your CricXii notifications will stay here.'),
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
                    const Icon(Icons.circle, size: 10, color: AppColors.greenDark),
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

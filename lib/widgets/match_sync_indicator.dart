import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_scope.dart';

class MatchSyncIndicator extends StatelessWidget {
  const MatchSyncIndicator({required this.matchId, super.key});

  final String matchId;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final synced = store.isMatchSynced(matchId);
    final error = store.matchSyncError(matchId);
    return IconButton(
      tooltip: synced
          ? 'Score synced to cloud'
          : error == null
          ? 'Score waiting to sync. Tap to retry.'
          : 'Sync needs attention. Tap to retry.',
      onPressed: synced
          ? null
          : () async {
              await AppScope.read(context).refreshMatches();
              if (!context.mounted) return;
              final latest = AppScope.read(context);
              final message = latest.isMatchSynced(matchId)
                  ? 'Match synced.'
                  : 'Still offline or another device has a newer revision.';
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            },
      icon: Icon(
        synced ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
        color: synced ? AppColors.greenDark : Colors.orangeAccent,
      ),
    );
  }
}

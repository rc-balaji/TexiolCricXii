import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_scope.dart';

class TeamMatchSyncIndicator extends StatefulWidget {
  const TeamMatchSyncIndicator({
    required this.matchId,
    this.compact = true,
    super.key,
  });

  final String matchId;
  final bool compact;

  @override
  State<TeamMatchSyncIndicator> createState() =>
      _TeamMatchSyncIndicatorState();
}

class _TeamMatchSyncIndicatorState extends State<TeamMatchSyncIndicator> {
  bool _syncing = false;

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final store = AppScope.read(context);
    final match = store.teamMatchById(widget.matchId);
    late final bool ok;
    if (match != null && store.canTakeTeamMatchControl(match)) {
      ok = await store.syncTeamMatchNow(widget.matchId);
    } else {
      await store.refreshMatchHistory();
      ok = store.isTeamMatchSynced(widget.matchId);
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    final message = ok
        ? 'Team Match synced with cloud.'
        : store.matchSyncError(widget.matchId) ??
            'Could not sync now. The match is still safe on this device.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final synced = store.isTeamMatchSynced(widget.matchId);
    final error = store.matchSyncError(widget.matchId);
    final color = synced
        ? AppColors.greenDark
        : error == null
            ? AppColors.gold
            : AppColors.danger;
    final icon = synced
        ? Icons.cloud_done_rounded
        : error == null
            ? Icons.cloud_sync_rounded
            : Icons.cloud_off_rounded;
    final label = synced ? 'Cloud synced' : 'Sync pending';

    if (widget.compact) {
      return IconButton(
        tooltip: synced ? label : '$label — tap to retry',
        onPressed: synced || _syncing ? null : _sync,
        icon: _syncing
            ? const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: color),
      );
    }
    return ActionChip(
      avatar: _syncing
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18, color: color),
      label: Text(label),
      onPressed: synced || _syncing ? null : _sync,
    );
  }
}

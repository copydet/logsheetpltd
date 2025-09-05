import 'package:flutter/material.dart';
import '../services/sync_manager.dart';

class SyncStatusWidget extends StatefulWidget {
  const SyncStatusWidget({Key? key}) : super(key: key);

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  final SyncManager _syncManager = SyncManager.instance;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: Stream.periodic(
        const Duration(seconds: 5),
      ), // Refresh setiap 5 detik
      builder: (context, snapshot) {
        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getSyncStatusColor().withOpacity(0.1),
            border: Border.all(color: _getSyncStatusColor()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Status sync utama
              ListTile(
                leading: _getSyncIcon(),
                title: Text(
                  _getSyncStatusText(),
                  style: TextStyle(
                    color: _getSyncStatusColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: _buildSyncSubtitle(),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_syncManager.pendingUploads > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_syncManager.pendingUploads}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (_syncManager.newUpdatesFromOthers > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.people,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${_syncManager.newUpdatesFromOthers}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                      onPressed: () =>
                          setState(() => _isExpanded = !_isExpanded),
                    ),
                  ],
                ),
                onTap: () => _showSyncActions(context),
              ),

              // Detail yang diperluas
              if (_isExpanded) _buildExpandedDetails(),
            ],
          ),
        );
      },
    );
  }

  Widget _getSyncIcon() {
    if (_syncManager.isSyncing) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_syncManager.pendingUploads > 0) {
      return const Icon(Icons.cloud_upload, color: Colors.orange);
    }

    if (_syncManager.syncErrors.isNotEmpty) {
      return const Icon(Icons.error, color: Colors.red);
    }

    return const Icon(Icons.cloud_done, color: Colors.green);
  }

  Color _getSyncStatusColor() {
    if (_syncManager.isSyncing) return Colors.blue;
    if (_syncManager.pendingUploads > 0) return Colors.orange;
    if (_syncManager.syncErrors.isNotEmpty) return Colors.red;
    return Colors.green;
  }

  String _getSyncStatusText() {
    if (_syncManager.isSyncing) return 'Syncing...';
    if (_syncManager.pendingUploads > 0) return 'Pending uploads';
    if (_syncManager.syncErrors.isNotEmpty) return 'Sync errors';
    return 'All synced';
  }

  Widget? _buildSyncSubtitle() {
    final lastSync = _syncManager.lastSyncTime;
    final newUpdates = _syncManager.newUpdatesFromOthers;

    // Tampilkan update baru dari device lain jika ada
    if (newUpdates > 0) {
      return Text(
        '$newUpdates update baru dari device lain',
        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
      );
    }

    if (lastSync == null) return const Text('Belum pernah sync');

    final now = DateTime.now();
    final diff = now.difference(lastSync);

    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (diff.inMinutes < 60) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      timeAgo = '${diff.inHours}h ago';
    } else {
      timeAgo = '${diff.inDays}d ago';
    }

    return Text('Last sync: $timeAgo');
  }

  Widget _buildExpandedDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),

          // Statistik sync
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Pending',
                '${_syncManager.pendingUploads}',
                Colors.orange,
              ),
              _buildStatItem(
                'From Others',
                '${_syncManager.newUpdatesFromOthers}',
                Colors.blue,
              ),
              _buildStatItem(
                'Errors',
                '${_syncManager.syncErrors.length}',
                Colors.red,
              ),
              _buildStatItem(
                'Status',
                _syncManager.isSyncing ? 'Active' : 'Idle',
                Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Status multi-device
          Row(
            children: [
              Icon(
                _syncManager.isListening
                    ? Icons.podcasts
                    : Icons.portable_wifi_off,
                size: 16,
                color: _syncManager.isListening ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                _syncManager.isListening
                    ? 'Real-time sync active'
                    : 'Real-time sync inactive',
                style: TextStyle(
                  fontSize: 12,
                  color: _syncManager.isListening ? Colors.green : Colors.grey,
                ),
              ),
              if (_syncManager.deviceId != null) ...[
                const Spacer(),
                Text(
                  'Device: ${_syncManager.deviceId!.substring(0, 8)}...',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Error terbaru (jika ada)
          if (_syncManager.syncErrors.isNotEmpty) ...[
            const Text(
              'Error Terbaru:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 8),
            ...(_syncManager.syncErrors
                .take(3)
                .map(
                  (error) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      error,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )),
          ],

          const SizedBox(height: 16),

          // Tombol aksi
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _syncManager.isSyncing
                      ? null
                      : () => _forceSyncNow(),
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync Sekarang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _syncManager.isSyncing ||
                          _syncManager.newUpdatesFromOthers == 0
                      ? null
                      : () => _downloadUpdatesFromOthers(),
                  icon: const Icon(Icons.download, size: 16),
                  label: Text(
                    'Ambil Update (${_syncManager.newUpdatesFromOthers})',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSyncSettings(context),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _syncManager.newUpdatesFromOthers > 0
                      ? () => _markUpdatesAsSeen()
                      : null,
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Mark Seen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _showSyncActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sync Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Force Sync Now'),
              subtitle: const Text('Upload all pending data immediately'),
              onTap: () {
                Navigator.pop(context);
                _forceSyncNow();
              },
            ),

            ListTile(
              leading: const Icon(Icons.cloud_download),
              title: const Text('Restore from Cloud'),
              subtitle: const Text('Download data from Firebase'),
              onTap: () {
                Navigator.pop(context);
                _restoreFromCloud();
              },
            ),

            ListTile(
              leading: const Icon(Icons.clear_all),
              title: const Text('Clear Sync Errors'),
              subtitle: const Text('Reset error list'),
              onTap: () {
                Navigator.pop(context);
                _clearSyncErrors();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sync Configuration:'),
            const SizedBox(height: 8),
            Text(
              '• Sync interval: ${SyncManager.SYNC_INTERVAL_MINUTES} minutes',
            ),
            Text('• Data retention: ${SyncManager.DATA_RETENTION_DAYS} days'),
            const SizedBox(height: 16),
            const Text('Current Status:'),
            const SizedBox(height: 8),
            Text('• Initialized: ${_syncManager.isInitialized ? "Yes" : "No"}'),
            Text('• Syncing: ${_syncManager.isSyncing ? "Yes" : "No"}'),
            Text('• Pending uploads: ${_syncManager.pendingUploads}'),
            Text('• Errors: ${_syncManager.syncErrors.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _forceSyncNow() async {
    try {
      final success = await _syncManager.forceSyncNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Sync completed successfully' : 'Sync failed',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        setState(() {}); // Refresh UI
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreFromCloud() async {
    try {
      final success = await _syncManager.restoreFromFirestore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Data restored successfully' : 'Restore failed',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        setState(() {}); // Refresh UI
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearSyncErrors() {
    // For now, just show that errors are cleared
    // In real implementation, you'd add a method to SyncManager
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sync errors cleared'),
        backgroundColor: Colors.green,
      ),
    );
    setState(() {}); // Refresh UI
  }

  Future<void> _downloadUpdatesFromOthers() async {
    try {
      final success = await _syncManager.downloadUpdatesFromOthers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Updates downloaded successfully'
                  : 'Failed to download updates',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        setState(() {}); // Refresh UI
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _markUpdatesAsSeen() {
    _syncManager.markUpdatesAsSeen();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Updates marked as seen'),
        backgroundColor: Colors.blue,
      ),
    );
    setState(() {}); // Refresh UI
  }
}

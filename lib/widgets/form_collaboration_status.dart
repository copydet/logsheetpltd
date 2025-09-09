import 'package:flutter/material.dart';
import 'dart:async';
import '../services/form_collaboration_service.dart';
import '../services/auth_service.dart';

/// Widget untuk menampilkan status collaboration di form
class FormCollaborationStatus extends StatefulWidget {
  final String generatorName;
  final int hour;
  final VoidCallback? onFormLocked;
  final VoidCallback? onFormUnlocked;

  const FormCollaborationStatus({
    Key? key,
    required this.generatorName,
    required this.hour,
    this.onFormLocked,
    this.onFormUnlocked,
  }) : super(key: key);

  @override
  State<FormCollaborationStatus> createState() =>
      _FormCollaborationStatusState();
}

class _FormCollaborationStatusState extends State<FormCollaborationStatus> {
  StreamSubscription? _collaboratorListener;
  Timer? _heartbeatTimer;
  Map<String, dynamic>? _collaboratorData;
  bool _isCurrentUserEditing = false;

  @override
  void initState() {
    super.initState();
    _initializeCollaboration();
  }

  @override
  void dispose() {
    _collaboratorListener?.cancel();
    _heartbeatTimer?.cancel();
    if (_isCurrentUserEditing) {
      FormCollaborationService.endEditingSession(
        generatorName: widget.generatorName,
        hour: widget.hour,
      );
    }
    super.dispose();
  }

  Future<void> _initializeCollaboration() async {
    // Cek apakah form sudah dikunci
    final lockStatus = await FormCollaborationService.checkFormLock(
      generatorName: widget.generatorName,
      hour: widget.hour,
    );

    if (lockStatus != null && lockStatus['isLocked'] == true) {
      // Form dikunci oleh user lain
      setState(() {
        _collaboratorData = lockStatus;
      });
      widget.onFormLocked?.call();
    } else {
      // Form tersedia, klaim untuk user ini
      final claimed = await FormCollaborationService.startEditingSession(
        generatorName: widget.generatorName,
        hour: widget.hour,
      );

      if (claimed) {
        setState(() {
          _isCurrentUserEditing = true;
        });
        widget.onFormUnlocked?.call();
        _startHeartbeat();
      }
    }

    // Listen untuk perubahan collaboration
    _collaboratorListener = FormCollaborationService.listenForCollaborators(
      generatorName: widget.generatorName,
      hour: widget.hour,
      onCollaboratorUpdate: _onCollaboratorUpdate,
    );
  }

  void _onCollaboratorUpdate(Map<String, dynamic>? data) async {
    if (data == null) {
      // Tidak ada yang editing
      setState(() {
        _collaboratorData = null;
      });
      widget.onFormUnlocked?.call();
      return;
    }

    final otherUserUid = data['userUid'] as String?;
    final currentUser = await AuthService.getCurrentUser();

    if (otherUserUid != currentUser?.uid) {
      // User lain sedang editing
      setState(() {
        _collaboratorData = data;
      });
      widget.onFormLocked?.call();
    } else {
      // User saat ini yang sedang editing
      setState(() {
        _collaboratorData = null;
        _isCurrentUserEditing = true;
      });
      widget.onFormUnlocked?.call();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isCurrentUserEditing) {
        FormCollaborationService.updateActivity(
          generatorName: widget.generatorName,
          hour: widget.hour,
        );
      }
    });
  }

  Widget _buildCollaborationIndicator() {
    if (_collaboratorData == null) {
      if (_isCurrentUserEditing) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit, size: 16, color: Colors.green.shade700),
              SizedBox(width: 6),
              Text(
                'Anda sedang mengedit',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }
      return SizedBox.shrink();
    }

    final userName = _collaboratorData!['userName'] as String? ?? 'User lain';
    final lastActivity = _collaboratorData!['lastActivity'];
    String timeAgo = '';

    if (lastActivity != null) {
      final DateTime activityTime = lastActivity.toDate();
      final int minutesAgo = DateTime.now().difference(activityTime).inMinutes;
      timeAgo = minutesAgo == 0 ? 'baru saja' : '$minutesAgo menit lalu';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, size: 16, color: Colors.orange.shade700),
              SizedBox(width: 6),
              Text(
                '$userName sedang mengedit',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (timeAgo.isNotEmpty) ...[
            SizedBox(height: 2),
            Text(
              'Aktivitas terakhir: $timeAgo',
              style: TextStyle(color: Colors.orange.shade600, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormLockedOverlay() {
    if (_collaboratorData == null) return SizedBox.shrink();

    final userName = _collaboratorData!['userName'] as String? ?? 'User lain';

    return Container(
      color: Colors.black45,
      child: Center(
        child: Card(
          margin: EdgeInsets.all(20),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 48, color: Colors.orange.shade600),
                SizedBox(height: 16),
                Text(
                  'Form Sedang Digunakan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '$userName sedang mengisi jam ${widget.hour}:00 untuk ${widget.generatorName}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Kembali'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _collaboratorData = null;
                        });
                        _initializeCollaboration();
                      },
                      icon: Icon(Icons.refresh, size: 16),
                      label: Text('Coba Lagi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Status indicator (always show at top)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(8),
            child: Center(child: _buildCollaborationIndicator()),
          ),
        ),

        // Overlay jika form dikunci
        if (_collaboratorData != null)
          Positioned.fill(child: _buildFormLockedOverlay()),
      ],
    );
  }

  /// Method public untuk update form data secara real-time
  Future<void> updateFormData(Map<String, dynamic> formData) async {
    if (_isCurrentUserEditing) {
      await FormCollaborationService.saveFormDraft(
        generatorName: widget.generatorName,
        hour: widget.hour,
        formData: formData,
      );
    }
  }

  /// Method public untuk load form draft
  Future<Map<String, dynamic>?> loadFormData() async {
    return await FormCollaborationService.loadFormDraft(
      generatorName: widget.generatorName,
      hour: widget.hour,
    );
  }
}

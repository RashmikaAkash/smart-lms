import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final Set<String> _shownNotificationIds = <String>{};

  CollectionReference<Map<String, dynamic>>? get _notifications {
    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('teacher_notifications')
        .doc(teacher.uid)
        .collection('notifications');
  }

  @override
  void initState() {
    super.initState();
    NotificationService.requestPermission();
  }

  Future<void> _showOnPhone(_NotificationData notification) async {
    final granted = await NotificationService.requestPermission();
    if (!granted) {
      if (!mounted) {
        return;
      }
      _showSnack('Phone notification permission allow කරන්න.');
      return;
    }

    final shown = await NotificationService.show(
      id: notification.phoneId,
      title: notification.title,
      body: notification.body,
    );

    if (!mounted) {
      return;
    }

    _showSnack(
      shown
          ? 'Phone notification bar එකට sent.'
          : 'Phone notification show කරන්න බැරි වුණා.',
    );
  }

  Future<void> _showUnreadOnPhone(List<_NotificationData> notifications) async {
    final unread = notifications
        .where((notification) => !notification.isRead)
        .where((notification) => !_shownNotificationIds.contains(notification.id))
        .take(3)
        .toList();

    if (unread.isEmpty) {
      return;
    }

    final granted = await NotificationService.requestPermission();
    if (!granted) {
      return;
    }

    for (final notification in unread) {
      _shownNotificationIds.add(notification.id);
      await NotificationService.show(
        id: notification.phoneId,
        title: notification.title,
        body: notification.body,
      );
    }
  }

  Future<void> _markAsRead(_NotificationData notification) async {
    if (notification.isRead) {
      return;
    }

    try {
      await _notifications?.doc(notification.id).set({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException {
      if (!mounted) {
        return;
      }
      _showSnack('Notification update rules check කරන්න.');
    }
  }

  Future<void> _showTestNotification() async {
    final granted = await NotificationService.requestPermission();
    if (!granted) {
      if (!mounted) {
        return;
      }
      _showSnack('Phone notification permission allow කරන්න.');
      return;
    }

    final shown = await NotificationService.show(
      title: 'Smart LMS',
      body: 'Notifications are ready on this phone.',
    );

    if (!mounted) {
      return;
    }

    _showSnack(shown ? 'Test notification sent.' : 'Test notification failed.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Test phone notification',
            onPressed: _showTestNotification,
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      body: notifications == null
          ? const _NotificationMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Login needed',
              message: 'Notifications බලන්න teacher account එකෙන් login වෙන්න.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: notifications
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _NotificationMessage(
                    icon: Icons.rule_folder_outlined,
                    title: 'Could not load notifications',
                    message:
                        'Firestore rules වල teacher_notifications read permission add කරන්න.',
                    actionLabel: 'Send Test Notification',
                    onActionPressed: _showTestNotification,
                  );
                }

                final items = (snapshot.data?.docs ?? [])
                    .map(_NotificationData.fromSnapshot)
                    .where((notification) => !notification.isArchived)
                    .toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _showUnreadOnPhone(items);
                  }
                });

                if (items.isEmpty) {
                  return _NotificationMessage(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications yet',
                    message:
                        'New class updates, payments, assignments වගේ alerts මෙතැන පේනවා.',
                    actionLabel: 'Send Test Notification',
                    onActionPressed: _showTestNotification,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  itemBuilder: (context, index) {
                    final notification = items[index];
                    return _NotificationTile(
                      notification: notification,
                      onTap: () => _markAsRead(notification),
                      onShowPhonePressed: () => _showOnPhone(notification),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: items.length,
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onShowPhonePressed,
  });

  final _NotificationData notification;
  final VoidCallback onTap;
  final VoidCallback onShowPhonePressed;

  @override
  Widget build(BuildContext context) {
    final accent = notification.isRead
        ? const Color(0xFF64748B)
        : const Color(0xFF316DFF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xFFE1E7F2)
                : const Color(0xFFBFD0FF),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(notification.icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF071B3C),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF316DFF),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notification.body,
                    style: const TextStyle(
                      color: Color(0xFF66748F),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        notification.timeLabel,
                        style: const TextStyle(
                          color: Color(0xFF8A98B3),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onShowPhonePressed,
                        icon: const Icon(Icons.phone_android_rounded, size: 16),
                        label: const Text('Phone'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF316DFF),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDDE5F4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF316DFF), size: 44),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF071B3C),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF66748F),
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (actionLabel != null && onActionPressed != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onActionPressed,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationData {
  const _NotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String status;
  final DateTime? createdAt;

  factory _NotificationData.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final createdAtValue = data['createdAt'];

    return _NotificationData(
      id: snapshot.id,
      title: _readString(data, 'title', 'Smart LMS Notification'),
      body: _readString(data, 'body', _readString(data, 'message', '')),
      type: _readString(data, 'type', 'general'),
      isRead: _readBool(data, 'isRead'),
      status: _readString(data, 'status', 'active'),
      createdAt:
          createdAtValue is Timestamp ? createdAtValue.toDate() : null,
    );
  }

  bool get isArchived => status.toLowerCase() == 'archived';

  int get phoneId => id.hashCode & 0x7fffffff;

  IconData get icon {
    switch (type.toLowerCase()) {
      case 'payment':
        return Icons.payments_rounded;
      case 'attendance':
        return Icons.qr_code_scanner_rounded;
      case 'assignment':
        return Icons.assignment_rounded;
      case 'quiz':
        return Icons.quiz_rounded;
      case 'live':
        return Icons.video_call_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  String get timeLabel {
    final date = createdAt;
    if (date == null) {
      return 'Just now';
    }

    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }
}

String _readString(
  Map<String, dynamic> data,
  String key, [
  String fallback = '',
]) {
  final value = data[key]?.toString().trim();
  return value?.isNotEmpty == true ? value! : fallback;
}

bool _readBool(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is bool) {
    return value;
  }
  return value?.toString().toLowerCase() == 'true';
}

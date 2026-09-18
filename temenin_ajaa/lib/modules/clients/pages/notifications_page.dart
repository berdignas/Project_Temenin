import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/client_notification_provider.dart';
import '../booking/screens/tracking_driver_screen.dart';
import '../chat/screens/chat_list_screen.dart';
import '../chat/screens/chat_room_screen.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isLoggedIn && authProvider.user != null) {
        Provider.of<ClientNotificationProvider>(context, listen: false)
            .subscribeToNotifications(authProvider.user!.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead(String notificationId) async {
    await Provider.of<ClientNotificationProvider>(context, listen: false)
        .markAsRead(notificationId);
  }

  Future<void> _markAllAsRead() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Tandai Semua Dibaca',
          style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menandai semua notifikasi sebagai telah dibaca?',
          style: GoogleFonts.inter(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<ClientNotificationProvider>(context, listen: false)
                  .markAllAsRead();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Semua notifikasi ditandai dibaca'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text('Ya', style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNotification(String notificationId) async {
    await Provider.of<ClientNotificationProvider>(context, listen: false)
        .deleteNotification(notificationId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifikasi dihapus'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _onNotificationTap(NotificationModel notification) {
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    final data = notification.data ?? {};
    final type = notification.type;

    switch (type) {
      case 'booking':
        final bookingId = data['bookingId']?.toString() ?? '';
        final bookingData = data['booking'] as Map<String, dynamic>?;
        if (bookingId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrackingDriverScreen(
                bookingId: bookingId,
                bookingData: bookingData,
              ),
            ),
          );
        } else {
          Navigator.pushNamed(context, '/booking-history');
        }
        break;

      case 'chat':
        final bookingId = (data['bookingId'] ?? data['chatRoomId'])?.toString();
        if (bookingId != null && bookingId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatRoomScreen(
                bookingId: bookingId,
                recipientName: 'Driver / Partner',
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatListScreen()),
          );
        }
        break;

      case 'payment':
        Navigator.pushNamed(context, '/payment-methods');
        break;

      case 'promo':
      case 'reward':
        Navigator.pushNamed(context, '/rewards');
        break;

      case 'system':
        Navigator.pushNamed(context, '/help-center');
        break;

      default:
        break;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7}mgg lalu';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}hr lalu';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}jam lalu';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}mnt lalu';
    } else {
      return 'Baru saja';
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<ClientNotificationProvider>();
    final allNotifications = notifProvider.notifications;
    final unreadNotifications = allNotifications.where((n) => !n.isRead).toList();
    final readNotifications = allNotifications.where((n) => n.isRead).toList();
    final unreadCount = unreadNotifications.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Notifikasi',
              style: GoogleFonts.inter(
                color: AppTheme.textHighContrast,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textHighContrast),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (allNotifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textHighContrast),
              color: AppTheme.surface,
              onSelected: (value) {
                if (value == 'mark_all_read') {
                  _markAllAsRead();
                } else if (value == 'clear_all') {
                  Provider.of<ClientNotificationProvider>(context, listen: false).clearAll();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'mark_all_read',
                  child: Text(
                    'Tandai semua dibaca',
                    style: GoogleFonts.inter(color: AppTheme.textHighContrast),
                  ),
                ),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Text(
                    'Hapus semua notifikasi',
                    style: GoogleFonts.inter(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryPink,
          labelColor: AppTheme.primaryPink,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Belum Dibaca'),
            Tab(text: 'Sudah Dibaca'),
          ],
        ),
      ),
      body: allNotifications.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_off_outlined,
                        size: 48,
                        color: AppTheme.textMuted.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada notifikasi',
                      style: GoogleFonts.inter(
                        color: AppTheme.textHighContrast,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Notifikasi terbaru terkait booking, pesan, dan aktivitas Anda akan muncul di sini',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationList(allNotifications),
                _buildNotificationList(unreadNotifications),
                _buildNotificationList(readNotifications),
              ],
            ),
    );
  }

  Widget _buildNotificationList(List<NotificationModel> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: AppTheme.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Tidak ada notifikasi di kategori ini',
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    IconData icon;
    Color iconColor;

    switch (notification.type) {
      case 'booking':
        icon = Icons.directions_car_rounded;
        iconColor = AppTheme.primaryPink;
        break;
      case 'chat':
        icon = Icons.chat_bubble_rounded;
        iconColor = const Color(0xFF00E5FF);
        break;
      case 'promo':
        icon = Icons.local_offer_rounded;
        iconColor = const Color(0xFFFF9800);
        break;
      case 'payment':
        icon = Icons.payment_rounded;
        iconColor = const Color(0xFF10B981);
        break;
      case 'reward':
        icon = Icons.card_giftcard_rounded;
        iconColor = const Color(0xFF9C27B0);
        break;
      case 'system':
        icon = Icons.info_outline_rounded;
        iconColor = Colors.blue;
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = Colors.grey;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _deleteNotification(notification.id);
      },
      child: GestureDetector(
        onTap: () => _onNotificationTap(notification),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? AppTheme.surface
                : AppTheme.primaryPink.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? AppTheme.border
                  : AppTheme.primaryPink.withOpacity(0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: GoogleFonts.inter(
                        color: AppTheme.textHighContrast,
                        fontSize: 14,
                        fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeAgo(notification.createdAt),
                          style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        if (!notification.isRead)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryPink,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _deleteNotification(notification.id),
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Model untuk Notification
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  bool isRead;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    this.data,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'system',
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['timestamp'] != null
              ? DateTime.parse(json['timestamp'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'data': data,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    Map<String, dynamic>? data,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
import 'package:temenin_ajaa/core/theme/app_theme.dart';
// lib/modules/home/pages/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:temenin_ajaa/core/services/notification_service.dart';
import '../../../providers/auth_provider.dart';


class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  late TabController _tabController;
  
  List<NotificationModel> _allNotifications = [];
  List<NotificationModel> _unreadNotifications = [];
  List<NotificationModel> _readNotifications = [];
  
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await _notificationService.getNotifications(authProvider.user!.id);
      
      if (result['success'] == true) {
        setState(() {
          _allNotifications = result['notifications'];
          _unreadNotifications = _allNotifications.where((n) => !n.isRead).toList();
          _readNotifications = _allNotifications.where((n) => n.isRead).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load notifications';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    final result = await _notificationService.markAsRead(notificationId);
    
    if (result['success'] == true) {
      // Update local state
      setState(() {
        final index = _allNotifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _allNotifications[index].isRead = true;
        }
        _unreadNotifications = _allNotifications.where((n) => !n.isRead).toList();
        _readNotifications = _allNotifications.where((n) => n.isRead).toList();
      });
    }
  }

  Future<void> _markAllAsRead() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1C24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Mark All as Read',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to mark all notifications as read?',
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryPink),
                ),
              );
              
              final result = await _notificationService.markAllAsRead();
              
              if (context.mounted) {
                Navigator.pop(context);
                
                if (result['success'] == true) {
                  _loadNotifications();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Failed to mark all as read'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('Yes', style: GoogleFonts.inter(color: AppTheme.primaryPink, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNotification(String notificationId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1C24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Notification',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this notification?',
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final result = await _notificationService.deleteNotification(notificationId);
              
              if (result['success'] == true) {
                setState(() {
                  _allNotifications.removeWhere((n) => n.id == notificationId);
                  _unreadNotifications = _allNotifications.where((n) => !n.isRead).toList();
                  _readNotifications = _allNotifications.where((n) => n.isRead).toList();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Failed to delete notification'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onNotificationTap(NotificationModel notification) {
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }
    
    // Navigate based on notification type
    switch (notification.type) {
      case 'booking':
        // Navigate to booking detail
        break;
      case 'promo':
        // Navigate to vouchers page
        break;
      case 'payment':
        // Navigate to payment history
        break;
      case 'reward':
        // Navigate to rewards page
        break;
      default:
        break;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7}w ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _unreadNotifications.length;
    
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
          if (_allNotifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textHighContrast),
              color: AppTheme.surface,
              onSelected: (value) {
                if (value == 'mark_all_read') {
                  _markAllAsRead();
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryPink,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 64,
                        color: AppTheme.textMuted.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPink,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _allNotifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: AppTheme.textMuted.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada notifikasi',
                            style: GoogleFonts.inter(
                              color: AppTheme.textHighContrast,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Notifikasi terbaru akan muncul di sini',
                            style: GoogleFonts.inter(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildNotificationList(_allNotifications),
                        _buildNotificationList(_unreadNotifications),
                        _buildNotificationList(_readNotifications),
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
              size: 64,
              color: AppTheme.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada notifikasi',
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
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
        icon = Icons.directions_car;
        iconColor = AppTheme.primaryPink;
        break;
      case 'promo':
        icon = Icons.local_offer;
        iconColor = const Color(0xFFFF9800);
        break;
      case 'payment':
        icon = Icons.payment;
        iconColor = Colors.green;
        break;
      case 'reward':
        icon = Icons.card_giftcard;
        iconColor = const Color(0xFF9C27B0);
        break;
      case 'system':
        icon = Icons.settings;
        iconColor = Colors.blue;
        break;
      default:
        icon = Icons.notifications;
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
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Hapus Notifikasi',
              style: GoogleFonts.inter(color: AppTheme.textHighContrast, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Apakah Anda yakin ingin menghapus notifikasi ini?',
              style: GoogleFonts.inter(color: AppTheme.textMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Batal', style: GoogleFonts.inter(color: AppTheme.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Hapus', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
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
                : AppTheme.fuchsiaLight,
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
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
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
      isRead: json['is_read'] ?? false,
      data: json['data'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
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
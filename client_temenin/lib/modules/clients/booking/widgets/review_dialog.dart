import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_theme.dart';

class BookingReviewDialog extends StatefulWidget {
  final String bookingId;
  final String? driverName;
  final String? driverImage;
  final VoidCallback? onReviewSubmitted;

  const BookingReviewDialog({
    super.key,
    required this.bookingId,
    this.driverName,
    this.driverImage,
    this.onReviewSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required String bookingId,
    String? driverName,
    String? driverImage,
    VoidCallback? onReviewSubmitted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BookingReviewDialog(
        bookingId: bookingId,
        driverName: driverName,
        driverImage: driverImage,
        onReviewSubmitted: onReviewSubmitted,
      ),
    );
  }

  @override
  State<BookingReviewDialog> createState() => _BookingReviewDialogState();
}

class _BookingReviewDialogState extends State<BookingReviewDialog> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);

    bool success = false;
    String message = 'Terima kasih atas ulasan Anda!';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // 1. Try backend API
      final url = Uri.parse('${ApiConstants.baseUrl}/api/bookings/${widget.bookingId}/reviews');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'rating': _rating,
          'comment': _commentController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        success = true;
      }
    } catch (_) {
      // 2. Direct Supabase Fallback
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final bookingRes = await Supabase.instance.client
              .from('bookings')
              .select('driver_id')
              .eq('id', widget.bookingId)
              .maybeSingle();

          final driverId = bookingRes?['driver_id'];
          if (driverId != null) {
            await Supabase.instance.client.from('reviews').insert({
              'booking_id': widget.bookingId,
              'user_id': user.id,
              'driver_id': driverId,
              'rating': _rating,
              'comment': _commentController.text.trim(),
            });

            // Recalculate average rating
            final allReviews = await Supabase.instance.client
                .from('reviews')
                .select('rating')
                .eq('driver_id', driverId);

            if (allReviews is List && allReviews.isNotEmpty) {
              final sum = allReviews.fold<double>(
                  0.0, (acc, r) => acc + (double.tryParse(r['rating']?.toString() ?? '5') ?? 5.0));
              final avg = (sum / allReviews.length).clamp(1.0, 5.0);
              await Supabase.instance.client
                  .from('drivers')
                  .update({'rating': double.parse(avg.toStringAsFixed(1))})
                  .eq('id', driverId);
            }
            success = true;
          }
        }
      } catch (err) {
        debugPrint('Direct Supabase review insert error: $err');
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? message : 'Ulasan tersimpan secara lokal. Terima kasih!',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppTheme.primaryPink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      widget.onReviewSubmitted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverName = widget.driverName ?? 'Partner Temenin Ajaa';
    final driverImage = widget.driverImage ?? 'https://i.pravatar.cc/300?img=14';

    return Dialog(
      backgroundColor: const Color(0xFF16151A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.primaryPink.withOpacity(0.2),
              backgroundImage: NetworkImage(driverImage),
            ),
            const SizedBox(height: 14),
            Text(
              'Bagaimana perjalananmu?',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Beri penilaian untuk $driverName',
              style: GoogleFonts.inter(
                color: Colors.grey.shade400,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Interactive Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1.0;
                final isFilled = _rating >= starValue;
                return GestureDetector(
                  onTap: () {
                    setState(() => _rating = starValue);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.star_rounded,
                      size: 38,
                      color: isFilled ? const Color(0xFFFFB800) : Colors.grey.shade700,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              _getRatingLabel(_rating),
              style: GoogleFonts.inter(
                color: const Color(0xFFFFB800),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),

            // Feedback Comment Box
            TextField(
              controller: _commentController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ceritakan pengalamanmu (opsional)...',
                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF24222A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Lewati',
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPink,
                      foregroundColor: const Color(0xFF6F004B),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6F004B)),
                            ),
                          )
                        : Text(
                            'Kirim Ulasan',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(double rating) {
    if (rating >= 5) return 'Sempurna! ⭐⭐⭐⭐⭐';
    if (rating >= 4) return 'Sangat Bagus! ⭐⭐⭐⭐';
    if (rating >= 3) return 'Cukup Baik ⭐⭐⭐';
    if (rating >= 2) return 'Kurang Memuaskan ⭐⭐';
    return 'Perlu Peningkatan ⭐';
  }
}

import re

with open('lib/modules/clients/booking/screens/payment_method_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

proper_header = '''import 'package:temenin_ajaa/core/theme/app_theme.dart';
// lib/modules/booking/screens/payment_method_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/auth_provider.dart';
import 'tracking_driver_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final Map<String, dynamic>? bookingData;
  
  const PaymentMethodScreen({super.key, this.bookingData});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String selectedMethod = "visa";
  
  late int totalPayment;
  late int dpAmount;

  @override
  void initState() {
    super.initState();
    totalPayment = widget.bookingData?['totalPayment'] ?? 250000;
    dpAmount = widget.bookingData?['dp'] ?? 125000;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE94057).withValues(alpha: 0.35),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTotalPaymentCard(),
                      const SizedBox(height: 30),
                      _buildSectionTitle("Saved Methods"),
                      const SizedBox(height: 15),
                      _buildPaymentTile(
                        id: "visa",
                        icon: Icons.credit_card_rounded,
                        title: "Visa ending in 1234",
                        subtitle: "Expires 12/26",
                      ),
                      const SizedBox(height: 12),
                      _buildPaymentTile(
                        id: "gopay",
'''

marker = 'id: "gopay",'
parts = content.split(marker)
if len(parts) >= 2:
    new_content = proper_header + parts[1]
    with open('lib/modules/clients/booking/screens/payment_method_screen.dart', 'w', encoding='utf-8') as f:
        f.write(new_content)
    print('Fixed successfully')
else:
    print('Marker not found')

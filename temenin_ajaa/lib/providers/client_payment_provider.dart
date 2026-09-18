import 'package:flutter/foundation.dart';
import 'package:temenin_ajaa/modules/clients/services/payment_service.dart';
import 'package:temenin_ajaa/modules/clients/pages/payment_methods_page.dart';

class ClientPaymentProvider with ChangeNotifier {
  final PaymentService _paymentService = PaymentService();

  List<PaymentMethod> _methods = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<PaymentMethod> get methods => _methods;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  PaymentMethod? get defaultMethod {
    if (_methods.isEmpty) return null;
    try {
      return _methods.firstWhere((m) => m.isDefault);
    } catch (_) {
      return _methods.first;
    }
  }

  Future<void> fetchPaymentMethods(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _paymentService.getPaymentMethods(userId);
      if (res['success'] == true && res['methods'] is List<PaymentMethod>) {
        _methods = res['methods'] as List<PaymentMethod>;
      } else {
        _errorMessage = res['message']?.toString() ?? 'Gagal mengambil metode pembayaran';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addMethod({
    required String userId,
    required String methodType,
    required String provider,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _paymentService.addPaymentMethod(
        userId: userId,
        methodType: methodType,
        provider: provider,
      );
      if (res['success'] == true) {
        await fetchPaymentMethods(userId);
        return true;
      } else {
        _errorMessage = res['message']?.toString() ?? 'Gagal menambah metode pembayaran';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeMethod(String userId, String methodId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _paymentService.removePaymentMethod(methodId);
      if (res['success'] == true) {
        _methods.removeWhere((m) => m.id == methodId);
        return true;
      } else {
        _errorMessage = res['message']?.toString() ?? 'Gagal menghapus metode pembayaran';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setDefaultMethod(String userId, String methodId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _paymentService.setDefaultPaymentMethod(methodId);
      if (res['success'] == true) {
        await fetchPaymentMethods(userId);
        return true;
      } else {
        _errorMessage = res['message']?.toString() ?? 'Gagal mengatur metode pembayaran utama';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

import 'package:flutter/foundation.dart';
import '../../data/services/local_storage_service.dart';

enum AppCurrency {
  inr('INR', '₹', 84.0),
  usd('USD', '\$', 1.0);

  const AppCurrency(this.code, this.symbol, this.rateFromUsd);
  final String code;
  final String symbol;
  final double rateFromUsd;

  static AppCurrency fromCode(String? code) {
    return AppCurrency.values.firstWhere(
      (c) => c.code == code,
      orElse: () => AppCurrency.inr,
    );
  }
}

/// Reactive currency controller defaulting to INR (₹) with live toggle to USD ($).
class CurrencyController extends ChangeNotifier {
  CurrencyController({LocalStorageService? storage})
      : _storage = storage,
        _currency = AppCurrency.fromCode(storage?.currencyCode);

  final LocalStorageService? _storage;
  AppCurrency _currency;

  AppCurrency get currency => _currency;
  bool get isInr => _currency == AppCurrency.inr;

  double convert(double baseUsdAmount) =>
      baseUsdAmount * _currency.rateFromUsd;

  String format(double baseUsdAmount, {int decimals = 0}) {
    final val = convert(baseUsdAmount);
    if (decimals == 0) {
      return '${_currency.symbol}${_withCommas(val.round().toString())}';
    }
    final fixed = val.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    return '${_currency.symbol}${_withCommas(parts[0])}.${parts[1]}';
  }

  String formatExact(double baseUsdAmount) => format(baseUsdAmount, decimals: 2);

  Future<void> setCurrency(AppCurrency next) async {
    if (_currency == next) return;
    _currency = next;
    await _storage?.setCurrencyCode(next.code);
    notifyListeners();
  }

  Future<void> toggle() =>
      setCurrency(isInr ? AppCurrency.usd : AppCurrency.inr);

  static String _withCommas(String digits) {
    final neg = digits.startsWith('-');
    final raw = neg ? digits.substring(1) : digits;
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final posFromRight = raw.length - i;
      buf.write(raw[i]);
      if (posFromRight > 1 && posFromRight % 3 == 1) {
        buf.write(',');
      }
    }
    return neg ? '-${buf.toString()}' : buf.toString();
  }
}

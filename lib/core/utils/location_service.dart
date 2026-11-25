import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/models/service_item.dart';

/// Manages user's current GPS location, nearby radius filter, and distance
/// calculation in kilometers for services.
class LocationController extends ChangeNotifier {
  double _userLat = 28.6139;
  double _userLng = 77.2090;
  bool _hasGpsLock = false;
  bool _isLocating = false;
  String _locationLabel = 'Default Area';
  String? _statusMessage;
  double? _radiusKm; // null = Any distance

  double get userLat => _userLat;
  double get userLng => _userLng;
  bool get hasGpsLock => _hasGpsLock;
  bool get isLocating => _isLocating;
  String get locationLabel => _locationLabel;
  String? get statusMessage => _statusMessage;
  double? get radiusKm => _radiusKm;

  static const List<double?> radiusOptions = [null, 2, 5, 10, 25];

  void setRadius(double? km) {
    if (_radiusKm == km) return;
    _radiusKm = km;
    notifyListeners();
  }

  Future<void> detectCurrentLocation() async {
    _isLocating = true;
    _statusMessage = null;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _statusMessage = 'Turn on device GPS to use live location.';
        _isLocating = false;
        notifyListeners();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _statusMessage = 'Location permission denied. Using area estimate.';
        _isLocating = false;
        notifyListeners();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      _hasGpsLock = true;
      _locationLabel =
          'GPS (${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)})';
      _statusMessage = null;
    } catch (_) {
      _statusMessage = 'Unable to fetch GPS right now. Using area estimate.';
    }

    _isLocating = false;
    notifyListeners();
  }

  /// Computes distance in kilometers between the user's current coordinates and
  /// a deterministic local provider anchor around the user's city/GPS.
  double distanceKmFor(ServiceItem service) {
    if (service.location.toLowerCase().contains('remote')) {
      return 0.0;
    }
    final hash = service.id.codeUnits.fold<int>(0, (a, b) => a * 31 + b);
    final angle = (hash % 360) * pi / 180.0;
    // Spread local providers realistically between ~0.8 km and ~18.5 km
    final baseKm = 0.8 + ((hash.abs() % 177) / 10.0);
    final dLat = (baseKm / 111.0) * cos(angle);
    final dLng =
        (baseKm / (111.0 * cos(_userLat * pi / 180.0).abs().clamp(0.2, 1.0))) *
            sin(angle);
    final meters = Geolocator.distanceBetween(
      _userLat,
      _userLng,
      _userLat + dLat,
      _userLng + dLng,
    );
    return double.parse((meters / 1000.0).toStringAsFixed(1));
  }

  String formatDistanceFor(ServiceItem service) {
    if (service.location.toLowerCase().contains('remote')) {
      return 'Remote / Online';
    }
    final km = distanceKmFor(service);
    if (km < 1.0) {
      return '${(km * 1000).round()} m away';
    }
    return '${km.toStringAsFixed(1)} km away';
  }
}

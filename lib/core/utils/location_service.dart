import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/service_item.dart';

class AreaSuggestion {
  const AreaSuggestion({
    required this.label,
    required this.lat,
    required this.lng,
  });

  final String label;
  final double lat;
  final double lng;
}

/// Manages user's current GPS location, manual area selection, nearby radius
/// filter, and distance calculation in kilometers for services.
class LocationController extends ChangeNotifier {
  double _userLat = 28.6139;
  double _userLng = 77.2090;
  bool _hasGpsLock = false;
  bool _hasManualArea = false;
  bool _isLocating = false;
  String _locationLabel = 'Default Area';
  String? _statusMessage;
  double? _radiusKm; // null = Any distance

  double get userLat => _userLat;
  double get userLng => _userLng;
  bool get hasGpsLock => _hasGpsLock;
  bool get hasManualArea => _hasManualArea;
  bool get hasSelectedArea => _hasGpsLock || _hasManualArea;
  bool get isLocating => _isLocating;
  String get locationLabel => _locationLabel;
  String? get statusMessage => _statusMessage;
  double? get radiusKm => _radiusKm;

  static const List<double?> radiusOptions = [null, 2, 5, 10, 25];

  static const List<AreaSuggestion> presetAreas = [
    AreaSuggestion(label: 'Mumbai', lat: 19.0760, lng: 72.8777),
    AreaSuggestion(label: 'Delhi NCR', lat: 28.6139, lng: 77.2090),
    AreaSuggestion(label: 'Bengaluru', lat: 12.9716, lng: 77.5946),
    AreaSuggestion(label: 'Pune', lat: 18.5204, lng: 73.8567),
    AreaSuggestion(label: 'Hyderabad', lat: 17.3850, lng: 78.4867),
    AreaSuggestion(label: 'San Francisco', lat: 37.7749, lng: -122.4194),
  ];

  void setRadius(double? km) {
    if (_radiusKm == km) return;
    _radiusKm = km;
    notifyListeners();
  }

  void selectArea(AreaSuggestion area) {
    _userLat = area.lat;
    _userLng = area.lng;
    _locationLabel = area.label;
    _hasGpsLock = false;
    _hasManualArea = true;
    _statusMessage = null;
    notifyListeners();
  }

  Future<void> setManualArea(String rawQuery) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return;

    final results = await searchAreas(trimmed);
    if (results.isNotEmpty) {
      selectArea(results.first);
      return;
    }

    // Fallback when offline or custom neighborhood string
    _locationLabel = trimmed;
    _hasGpsLock = false;
    _hasManualArea = true;
    _statusMessage = null;
    notifyListeners();
  }

  Future<List<AreaSuggestion>> searchAreas(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return presetAreas;

    final matches = <AreaSuggestion>[];
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=jsonv2&q=${Uri.encodeQueryComponent(query)}&limit=5&addressdetails=1',
      );
      final resp = await http
          .get(uri, headers: const {'User-Agent': 'ServiceEpicApp/1.0'})
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final lat = double.tryParse(map['lat']?.toString() ?? '');
          final lng = double.tryParse(map['lon']?.toString() ?? '');
          if (lat == null || lng == null) continue;
          final addr = map['address'] as Map<String, dynamic>?;
          final name = (addr?['suburb'] ??
                  addr?['neighbourhood'] ??
                  addr?['town'] ??
                  addr?['city'] ??
                  map['name'] ??
                  query)
              .toString()
              .trim();
          final city = (addr?['city'] ?? addr?['state'] ?? '').toString().trim();
          final label = (city.isNotEmpty && city != name)
              ? '$name, $city'
              : name;
          matches.add(AreaSuggestion(label: label, lat: lat, lng: lng));
        }
      }
    } catch (_) {}

    if (matches.isEmpty && !kIsWeb) {
      try {
        final locs = await locationFromAddress(query);
        if (locs.isNotEmpty) {
          matches.add(
            AreaSuggestion(
              label: query,
              lat: locs.first.latitude,
              lng: locs.first.longitude,
            ),
          );
        }
      } catch (_) {}
    }

    if (matches.isEmpty) {
      final qLower = query.toLowerCase();
      matches.addAll(
        presetAreas.where((a) => a.label.toLowerCase().contains(qLower)),
      );
    }

    return matches;
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
      _hasManualArea = false;
      _locationLabel = await _resolvePlaceName(pos.latitude, pos.longitude);
      _statusMessage = null;
    } catch (_) {
      _statusMessage = 'Unable to fetch GPS right now. Using area estimate.';
    }

    _isLocating = false;
    notifyListeners();
  }

  Future<String> _resolvePlaceName(double lat, double lng) async {
    if (!kIsWeb) {
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if ((p.subLocality ?? '').trim().isNotEmpty)
              p.subLocality!.trim(),
            if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
          ];
          if (parts.isNotEmpty) return parts.join(', ');
          if ((p.administrativeArea ?? '').trim().isNotEmpty) {
            return p.administrativeArea!.trim();
          }
        }
      } catch (_) {}
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=14&addressdetails=1',
      );
      final resp = await http
          .get(uri, headers: const {'User-Agent': 'ServiceEpicApp/1.0'})
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final area = (addr['suburb'] ??
                  addr['neighbourhood'] ??
                  addr['town'] ??
                  addr['city_district'] ??
                  '')
              .toString()
              .trim();
          final city = (addr['city'] ??
                  addr['state_district'] ??
                  addr['state'] ??
                  '')
              .toString()
              .trim();
          final parts = <String>[
            if (area.isNotEmpty) area,
            if (city.isNotEmpty && city != area) city,
          ];
          if (parts.isNotEmpty) return parts.join(', ');
        }
        final display = (data['name'] ?? '').toString().trim();
        if (display.isNotEmpty) return display;
      }
    } catch (_) {}

    return 'Current Location';
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

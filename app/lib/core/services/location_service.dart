import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/layout_widgets.dart';
import 'geo.dart';

/// Why the phone's position could not be read.
enum LocationIssue { serviceOff, denied, deniedForever, unavailable }

sealed class LocationFix {
  const LocationFix();
}

class LocationFound extends LocationFix {
  const LocationFound(this.position, {this.accuracyMeters = 0});
  final LatLng position;
  final double accuracyMeters;
}

class LocationProblem extends LocationFix {
  const LocationProblem(this.issue);
  final LocationIssue issue;
}

/// The phone's real position, read only when the user asks for it ("Gunakan lokasi saat ini", "Ke lokasi saya").
/// Pogung stays the default everywhere else because the mock listings are there.
abstract class DeviceLocator {
  Future<LocationFix> locate();

  /// Live positions while walking a route. Call only after [locate] found a position (permission granted).
  Stream<LatLng> track();

  /// Short place name such as "Sinduadi, Sleman", or null when none is known.
  Future<String?> placeName(LatLng p);

  /// Street-level address for a pickup point ("Jl. Kaliurang No. 5, Sinduadi"), or null.
  Future<String?> address(LatLng p);

  Future<void> openLocationSettings();
  Future<void> openAppSettings();
}

/// GPS through geolocator, names through the platform geocoder (no API key, no server).
class GeolocatorLocator implements DeviceLocator {
  gc.Geocoding? _geocoding;

  @override
  Future<LocationFix> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return const LocationProblem(LocationIssue.serviceOff);
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return const LocationProblem(LocationIssue.deniedForever);
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        return const LocationProblem(LocationIssue.denied);
      }
      try {
        final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
        return LocationFound(LatLng(p.latitude, p.longitude), accuracyMeters: p.accuracy);
      } on TimeoutException {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) return const LocationProblem(LocationIssue.unavailable);
        return LocationFound(LatLng(last.latitude, last.longitude), accuracyMeters: last.accuracy);
      }
    } on Object {
      return const LocationProblem(LocationIssue.unavailable);
    }
  }

  @override
  Stream<LatLng> track() => Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3))
      .map((p) => LatLng(p.latitude, p.longitude))
      .handleError((Object _) {}); // a lost fix just pauses the dot; the route stays

  Future<gc.Placemark?> _placemark(LatLng p) async {
    try {
      _geocoding ??= gc.Geocoding();
      final marks = await _geocoding!.placemarkFromCoordinates(p.latitude, p.longitude).timeout(const Duration(seconds: 6));
      return marks.isEmpty ? null : marks.first;
    } on Object {
      return null; // no geocoder, no network or no result: callers fall back
    }
  }

  @override
  Future<String?> placeName(LatLng p) async => placeNameFrom(await _placemark(p), p);

  @override
  Future<String?> address(LatLng p) async {
    final m = await _placemark(p);
    if (m == null) return null;
    final street = _clean(m.thoroughfare) ?? _clean(m.street);
    final area = _clean(m.subLocality) ?? _clean(m.locality);
    final parts = [?street, ?area];
    return parts.isEmpty ? null : parts.join(', ');
  }

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}

String? _clean(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// `"kelurahan or kecamatan, kabupaten"` from a placemark ("Sinduadi, Sleman"). Without one, the nearest known area
/// within 1.5 km, else null (the caller shows "Lokasi saat ini").
String? placeNameFrom(gc.Placemark? m, LatLng p) {
  if (m != null) {
    final area = _clean(m.subLocality) ?? _clean(m.locality);
    final region = _clean(m.subAdministrativeArea)?.replaceFirst(RegExp(r'^(Kabupaten|Kota|Regency of)\s+', caseSensitive: false), '');
    if (area != null) return region == null || region == area ? area : '$area, $region';
  }
  return nearbyAreaName(p);
}

/// Name of the closest demo area if [p] is within 1.5 km of it.
String? nearbyAreaName(LatLng p) {
  SavedLocation? best;
  for (final l in locations) {
    if (best == null || distanceMeters(p, l.position) < distanceMeters(p, best.position)) best = l;
  }
  return best != null && distanceMeters(p, best.position) <= 1500 ? best.name : null;
}

const currentLocationLabel = 'Lokasi saat ini';

final deviceLocatorProvider = Provider<DeviceLocator>((ref) => GeolocatorLocator());

/// The latest real position, shared by Beranda and the map picker. Null until the user asks for GPS once.
final lastFixProvider = StateProvider<LatLng?>((ref) => null);

/// Snack for a failed GPS read, with a shortcut to the right settings page when that is the fix.
void showLocationProblem(BuildContext context, LocationIssue issue, DeviceLocator locator) {
  switch (issue) {
    case LocationIssue.serviceOff:
      showAppSnack(context, 'Lokasi ponsel mati. Nyalakan lokasi, lalu coba lagi.', actionLabel: 'Setelan', onAction: locator.openLocationSettings);
    case LocationIssue.denied:
      showAppSnack(context, 'Izin lokasi ditolak. PawonFood tetap memakai daerah yang kamu pilih.');
    case LocationIssue.deniedForever:
      showAppSnack(context, 'Izin lokasi diblokir. Buka setelan aplikasi untuk mengizinkan.', actionLabel: 'Setelan', onAction: locator.openAppSettings);
    case LocationIssue.unavailable:
      showAppSnack(context, 'Lokasi belum ketemu. Coba lagi di tempat terbuka.');
  }
}

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Pogung, Sleman (near UGM): default center for the MVP.
const pogung = LatLng(-7.7598, 110.3795);

const double walkableRadiusMeters = 1000;

/// Great-circle distance in meters.
double distanceMeters(LatLng a, LatLng b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude), dLng = rad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

class SavedLocation {
  const SavedLocation(this.name, this.position);
  final String name;
  final LatLng position;
}

/// Locations the user can pick from the header sheet. Condongcatur has no listing within 1 km but one within
/// 2 km, which demos the empty state and "Perluas radius ke 2 km".
const locations = [
  SavedLocation('Pogung, Sleman', pogung),
  SavedLocation('Sagan, Yogyakarta', LatLng(-7.7690, 110.3790)),
  SavedLocation('Condongcatur, Sleman', LatLng(-7.7420, 110.3950)),
];

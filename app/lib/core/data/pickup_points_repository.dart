import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../services/geo.dart';
import 'onboarding_repository.dart';

/// A place where receivers collect food. The user keeps a few saved ones (D18c); a listing can also use a point
/// picked on the map just for that listing (C15d).
class PickupPoint {
  const PickupPoint({required this.id, required this.name, required this.address, required this.position, this.primary = false, this.fromMap = false});

  final String id;
  final String name;
  final String address;
  final LatLng position;

  /// The default point for new listings ("Utama").
  final bool primary;

  /// Picked on the map for one listing ("Dari peta").
  final bool fromMap;

  PickupPoint copyWith({bool? primary, String? name}) =>
      PickupPoint(id: id, name: name ?? this.name, address: address, position: position, primary: primary ?? this.primary, fromMap: fromMap);
}

/// Where "Gunakan lokasi saya" lands in the demo (GPS is simulated near Kos Melati).
const gpsPoint = PickupPoint(id: 'gps', name: 'Lokasi saya sekarang', address: 'Jl. Pogung Baru No. 14', position: LatLng(-7.7597, 110.3799));

/// Places the map search knows (C15d "Cari alamat atau tempat"); mock data around Pogung.
const searchablePlaces = [
  PickupPoint(id: 'srch_1', name: 'Jl. Pogung Baru No. 14', address: 'Pogung, Sleman', position: LatLng(-7.7597, 110.3799)),
  PickupPoint(id: 'srch_2', name: 'Masjid Pogung Raya', address: 'Jl. Pogung Raya, Sleman', position: LatLng(-7.7570, 110.3792)),
  PickupPoint(id: 'srch_3', name: 'Warteg Bu Siti', address: 'Jl. Pogung Lor No. 5', position: LatLng(-7.7576, 110.3809)),
  PickupPoint(id: 'srch_4', name: 'Pos Ronda Pogung Kidul', address: 'Pogung Kidul, Sleman', position: LatLng(-7.7632, 110.3781)),
  PickupPoint(id: 'srch_5', name: 'Gerbang Fakultas Teknik UGM', address: 'Jl. Grafika, Sleman', position: LatLng(-7.7656, 110.3718)),
];

class PickupPointsNotifier extends Notifier<List<PickupPoint>> {
  var _seq = 0;

  @override
  List<PickupPoint> build() => const [
        PickupPoint(id: 'pp_melati', name: 'Kos Melati, Pogung', address: 'Jl. Pogung Baru No. 12', position: pogung, primary: true),
        PickupPoint(id: 'pp_siti', name: 'Warteg Bu Siti, Pogung', address: 'Jl. Pogung Lor No. 5', position: LatLng(-7.7576, 110.3809)),
      ];

  PickupPoint get primary => state.firstWhere((p) => p.primary, orElse: () => state.first);

  /// Saves a point picked on the map ("Simpan ke titik tersimpan").
  PickupPoint save(PickupPoint p) {
    final saved = PickupPoint(id: 'pp_${_seq++}', name: p.name, address: p.address, position: p.position);
    state = [...state, saved];
    return saved;
  }

  void makePrimary(String id) => state = [for (final p in state) p.copyWith(primary: p.id == id)];

  void remove(String id) {
    final removed = state.where((p) => p.id == id).firstOrNull;
    if (removed == null || state.length == 1) return;
    final rest = [for (final p in state) if (p.id != id) p];
    state = removed.primary ? [rest.first.copyWith(primary: true), ...rest.skip(1)] : rest;
  }
}

final pickupPointsProvider = NotifierProvider<PickupPointsNotifier, List<PickupPoint>>(PickupPointsNotifier.new);

/// "Riwayat" in the C15d search: places picked from the search or confirmed on the map, newest first. Kept on the
/// device (memory only in tests, where there are no preferences).
class RecentPlacesNotifier extends Notifier<List<PickupPoint>> {
  static const _key = 'recent_places';
  static const max = 5;

  @override
  List<PickupPoint> build() {
    final raw = ref.read(preferencesProvider)?.getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          PickupPoint(
            id: 'recent_${e['lat']}_${e['lng']}',
            name: e['name'] as String,
            address: e['address'] as String,
            position: LatLng((e['lat'] as num).toDouble(), (e['lng'] as num).toDouble()),
          ),
      ];
    } on Object {
      return const []; // an old or broken entry is not worth a crash
    }
  }

  /// Puts [p] on top; the same spot (within ~10 m) replaces its older entry.
  void add(PickupPoint p) {
    final rest = [for (final r in state) if (distanceMeters(r.position, p.position) > 10) r];
    final entry = PickupPoint(id: 'recent_${p.position.latitude}_${p.position.longitude}', name: p.name, address: p.address, position: p.position);
    state = [entry, ...rest].take(max).toList();
    _persist();
  }

  /// The ✕ on one Riwayat row.
  void remove(PickupPoint p) {
    state = [for (final r in state) if (r.id != p.id) r];
    _persist();
  }

  /// "Hapus semua" above Riwayat.
  void clear() {
    state = const [];
    _persist();
  }

  void _persist() {
    final json = jsonEncode([for (final r in state) {'name': r.name, 'address': r.address, 'lat': r.position.latitude, 'lng': r.position.longitude}]);
    unawaited(ref.read(preferencesProvider)?.setString(_key, json));
  }
}

final recentPlacesProvider = NotifierProvider<RecentPlacesNotifier, List<PickupPoint>>(RecentPlacesNotifier.new);

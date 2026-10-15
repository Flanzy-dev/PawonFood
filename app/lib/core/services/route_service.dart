import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Direction of a turn, for the instruction card icon.
enum TurnKind { depart, straight, slightLeft, left, sharpLeft, slightRight, right, sharpRight, uturn, arrive }

/// One instruction along a walking route. [startsAt] is the distance along the path where it applies.
class RouteStep {
  const RouteStep({required this.startsAt, required this.length, required this.turn, required this.instruction});
  final double startsAt;
  final double length;
  final TurnKind turn;

  /// Indonesian, for example "Belok kiri ke Jalan Kaliurang".
  final String instruction;
}

class WalkRoute {
  const WalkRoute({required this.path, required this.meters, required this.steps, required this.fromStreets});
  final List<LatLng> path;
  final double meters;
  final List<RouteStep> steps;

  /// True for a route along mapped streets; false for the straight-line estimate.
  final bool fromStreets;
}

/// Finds a walking route. Returns null when none can be found (offline, no route): callers use [estimatedRoute].
abstract class RoutePlanner {
  Future<WalkRoute?> walk(LatLng from, LatLng to);
}

/// Walking routes from OpenStreetMap through the FOSSGIS OSRM foot router (routing.openstreetmap.de): free, no key.
class OsrmFootPlanner implements RoutePlanner {
  OsrmFootPlanner({http.Client? client, this.timeout = const Duration(seconds: 10)}) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static const _base = 'https://routing.openstreetmap.de/routed-foot/route/v1/foot';

  @override
  Future<WalkRoute?> walk(LatLng from, LatLng to) async {
    final url = Uri.parse('$_base/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson&steps=true');
    try {
      final res = await _client.get(url, headers: {'User-Agent': 'PawonFood/1.0 (hackathon prototype)'}).timeout(timeout);
      if (res.statusCode != 200) return null;
      return withEnds(parseOsrmRoute(jsonDecode(utf8.decode(res.bodyBytes))), from, to);
    } on Object {
      return null; // network, timeout or an answer that does not fit: the estimate takes over
    }
  }
}

LatLng _lngLat(Object? v) {
  if (v is! List || v.length < 2 || v[0] is! num || v[1] is! num) throw const FormatException('bad coordinate');
  return LatLng((v[1] as num).toDouble(), (v[0] as num).toDouble());
}

/// Reads an OSRM `route` response. Throws [FormatException] when it does not fit.
WalkRoute parseOsrmRoute(Object? json) {
  if (json is! Map || json['code'] != 'Ok') throw const FormatException('no route');
  final routes = json['routes'];
  if (routes is! List || routes.isEmpty || routes.first is! Map) throw const FormatException('no route');
  final route = routes.first as Map;
  final coords = (route['geometry'] as Map?)?['coordinates'];
  if (coords is! List || coords.length < 2) throw const FormatException('no geometry');
  final path = [for (final c in coords) _lngLat(c)];
  final meters = route['distance'];
  if (meters is! num) throw const FormatException('no distance');
  final legs = route['legs'];
  if (legs is! List || legs.isEmpty) throw const FormatException('no legs');

  final steps = <RouteStep>[];
  final total = pathLength(path);
  for (final leg in legs) {
    final raw = (leg as Map)['steps'];
    if (raw is! List) throw const FormatException('no steps');
    for (final s in raw) {
      final m = (s as Map)['maneuver'];
      if (m is! Map || m['type'] is! String || s['distance'] is! num) throw const FormatException('bad step');
      final type = m['type'] as String;
      final modifier = m['modifier'] is String ? m['modifier'] as String : null;
      final name = s['name'] is String ? (s['name'] as String).trim() : '';
      steps.add(RouteStep(
        startsAt: progressAlong(path, _lngLat(m['location'])) * total,
        length: (s['distance'] as num).toDouble(),
        turn: turnKind(type, modifier),
        instruction: instructionFor(type, modifier, name),
      ));
    }
  }
  return WalkRoute(path: path, meters: meters.toDouble(), steps: steps, fromStreets: true);
}

/// OSRM draws the route between the points it snapped to the nearest walkable ways, so the line can start and stop
/// tens of metres from where the person and the pickup point really are. This joins the line to [from] and [to], so
/// it touches both pins at any zoom. The extra legs count towards [WalkRoute.meters], and the steps move with them.
WalkRoute withEnds(WalkRoute r, LatLng from, LatLng to) {
  final head = _distance(from, r.path.first);
  final tail = _distance(r.path.last, to);
  final addHead = head > _endGap, addTail = tail > _endGap;
  if (!addHead && !addTail) return r;
  final path = [if (addHead) from, ...r.path, if (addTail) to];
  final shift = addHead ? head : 0.0;
  final end = pathLength(path);
  final steps = [
    for (final s in r.steps)
      switch (s.turn) {
        TurnKind.depart => RouteStep(startsAt: s.startsAt, length: s.length + shift, turn: s.turn, instruction: s.instruction),
        TurnKind.arrive => RouteStep(startsAt: end, length: s.length, turn: s.turn, instruction: s.instruction),
        _ => RouteStep(startsAt: s.startsAt + shift, length: s.length, turn: s.turn, instruction: s.instruction),
      },
  ];
  return WalkRoute(path: path, meters: r.meters + (addHead ? head : 0) + (addTail ? tail : 0), steps: steps, fromStreets: r.fromStreets);
}

/// Gaps up to this many metres are GPS noise or rounding, not a snapped end worth drawing.
const _endGap = 1.0;

TurnKind turnKind(String type, String? modifier) {
  if (type == 'depart') return TurnKind.depart;
  if (type == 'arrive') return TurnKind.arrive;
  return switch (modifier) {
    'left' => TurnKind.left,
    'right' => TurnKind.right,
    'slight left' => TurnKind.slightLeft,
    'slight right' => TurnKind.slightRight,
    'sharp left' => TurnKind.sharpLeft,
    'sharp right' => TurnKind.sharpRight,
    'uturn' => TurnKind.uturn,
    _ => TurnKind.straight,
  };
}

/// Indonesian instruction from the OSRM maneuver (its English text is never shown).
String instructionFor(String type, String? modifier, String name) {
  if (type == 'arrive') return 'Sampai di titik ambil';
  if (type == 'depart') return name.isEmpty ? 'Mulai jalan' : 'Mulai jalan di $name';
  final verb = type.startsWith('roundabout') || type == 'rotary'
      ? 'Masuk bundaran'
      : switch (modifier) {
          'left' => 'Belok kiri',
          'right' => 'Belok kanan',
          'slight left' => 'Agak ke kiri',
          'slight right' => 'Agak ke kanan',
          'sharp left' => 'Belok tajam ke kiri',
          'sharp right' => 'Belok tajam ke kanan',
          'straight' => 'Lurus',
          'uturn' => 'Putar balik',
          _ => 'Lanjutkan',
        };
  return name.isEmpty ? verb : '$verb ke $name';
}

// ---------- estimate (offline / while loading) ----------

/// Start → east → north → east, like walking along the kampung streets. Shown while the real route loads and when
/// none can be found; its steps name no streets.
WalkRoute estimatedRoute(LatLng a, LatLng b) {
  final midLng = a.longitude + (b.longitude - a.longitude) * 0.55;
  final path = [a, LatLng(a.latitude, midLng), LatLng(b.latitude, midLng), b];
  final total = pathLength(path);
  final steps = <RouteStep>[RouteStep(startsAt: 0, length: _distance(path[0], path[1]), turn: TurnKind.depart, instruction: 'Mulai jalan')];
  var at = 0.0;
  for (var i = 1; i < path.length - 1; i++) {
    at += _distance(path[i - 1], path[i]);
    final p = path[i - 1], q = path[i], r = path[i + 1];
    final cross = (q.longitude - p.longitude) * (r.latitude - q.latitude) - (q.latitude - p.latitude) * (r.longitude - q.longitude);
    final left = cross > 0;
    steps.add(RouteStep(startsAt: at, length: _distance(q, r), turn: left ? TurnKind.left : TurnKind.right, instruction: left ? 'Belok kiri' : 'Belok kanan'));
  }
  steps.add(RouteStep(startsAt: total, length: 0, turn: TurnKind.arrive, instruction: 'Sampai di titik ambil'));
  return WalkRoute(path: path, meters: total, steps: steps, fromStreets: false);
}

final routePlannerProvider = Provider<RoutePlanner>((ref) => OsrmFootPlanner());

// ---------- geometry ----------

const _distance = Distance();

double pathLength(List<LatLng> p) {
  var d = 0.0;
  for (var i = 1; i < p.length; i++) {
    d += _distance(p[i - 1], p[i]);
  }
  return d;
}

/// Point at fraction [t] of the path's length.
LatLng pointAlong(List<LatLng> p, double t) {
  var left = pathLength(p) * t;
  for (var i = 1; i < p.length; i++) {
    final seg = _distance(p[i - 1], p[i]);
    if (left <= seg || i == p.length - 1) {
      final f = seg == 0 ? 0.0 : (left / seg).clamp(0.0, 1.0);
      return LatLng(p[i - 1].latitude + (p[i].latitude - p[i - 1].latitude) * f, p[i - 1].longitude + (p[i].longitude - p[i - 1].longitude) * f);
    }
    left -= seg;
  }
  return p.last;
}

/// The part still to walk, from the point at fraction [t] to the end.
List<LatLng> remainingPath(List<LatLng> p, double t) {
  final here = pointAlong(p, t);
  var walked = pathLength(p) * t;
  for (var i = 1; i < p.length; i++) {
    final seg = _distance(p[i - 1], p[i]);
    if (walked <= seg) return [here, ...p.sublist(i)];
    walked -= seg;
  }
  return [p.last];
}

/// Fraction of the path walked when standing at [pos]: the point is projected onto the nearest segment. Plane
/// geometry in local metres is accurate enough over a walk of a few kilometres.
double progressAlong(List<LatLng> p, LatLng pos) {
  if (p.length < 2) return 0;
  final cosLat = math.cos(pos.latitude * math.pi / 180);
  (double, double) xy(LatLng q) => ((q.longitude - pos.longitude) * cosLat * 111320, (q.latitude - pos.latitude) * 110540);
  var bestDist = double.infinity;
  var bestAlong = 0.0;
  var acc = 0.0;
  for (var i = 1; i < p.length; i++) {
    final (ax, ay) = xy(p[i - 1]);
    final (bx, by) = xy(p[i]);
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final f = len2 == 0 ? 0.0 : ((-ax * dx - ay * dy) / len2).clamp(0.0, 1.0);
    final cx = ax + dx * f, cy = ay + dy * f;
    final d = cx * cx + cy * cy;
    final seg = _distance(p[i - 1], p[i]);
    if (d < bestDist) {
      bestDist = d;
      bestAlong = acc + seg * f;
    }
    acc += seg;
  }
  return acc == 0 ? 0 : (bestAlong / acc).clamp(0.0, 1.0);
}

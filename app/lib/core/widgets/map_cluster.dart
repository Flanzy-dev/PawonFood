import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/listing.dart';
import '../services/geo.dart';

/// Listings grouped for display: a single listing renders as a price pin, several as a count cluster.
class MapCluster {
  MapCluster(Listing first)
      : listings = [first],
        center = first.position;

  final List<Listing> listings;
  LatLng center;

  bool get isSingle => listings.length == 1;
  int get count => listings.length;

  void _add(Listing l) {
    listings.add(l);
    final n = listings.length;
    center = LatLng(
      listings.fold<double>(0, (s, e) => s + e.position.latitude) / n,
      listings.fold<double>(0, (s, e) => s + e.position.longitude) / n,
    );
  }
}

/// Greedy distance clustering. Listings closer than [thresholdMeters] to a cluster's center join it.
List<MapCluster> clusterListings(List<Listing> items, double thresholdMeters) {
  final clusters = <MapCluster>[];
  for (final l in items) {
    MapCluster? home;
    for (final c in clusters) {
      if (distanceMeters(c.center, l.position) <= thresholdMeters) {
        home = c;
        break;
      }
    }
    if (home == null) {
      clusters.add(MapCluster(l));
    } else {
      home._add(l);
    }
  }
  return clusters;
}

/// Meters covered by one screen pixel at [zoom] (Web Mercator, 256px tiles).
double metersPerPixel(double latitude, double zoom) => 156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);

/// Zoom level at which [meters] spans [pixels] on screen.
double zoomForSpan(double latitude, double meters, double pixels) => math.log(156543.03392 * math.cos(latitude * math.pi / 180) * pixels / meters) / math.ln2;

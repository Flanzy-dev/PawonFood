import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../mock/mock_data.dart';
import '../models/enums.dart';
import '../models/listing.dart';
import '../services/geo.dart';
import '../services/validators.dart';
import 'providers.dart';

/// Data typed by the provider in the share form (step 2 of 3).
class PublishDraft {
  const PublishDraft({
    required this.name,
    required this.category,
    required this.portions,
    required this.price,
    required this.negotiable,
    required this.pickupBy,
    required this.pickupPoint,
    this.photoPath,
    this.aiConfidence = 0,
    this.aiStatus = AiStatus.approved,
  });

  final String name;
  final FoodCategory category;
  final int portions;
  final int price;
  final bool negotiable;
  final DateTime pickupBy;
  final String pickupPoint;
  final String? photoPath;
  final double aiConfidence;
  final AiStatus aiStatus;
}

class ListingsNotifier extends Notifier<List<Listing>> {
  @override
  List<Listing> build() => ref.read(mockDataProvider).listings;

  Listing? byId(String id) {
    for (final l in state) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Takes [portions] out of a listing after a pickup; the listing becomes "habis" at zero.
  void consume(String id, int portions) {
    state = [
      for (final l in state)
        if (l.id == id)
          l.copyWith(
            portionsLeft: (l.portionsLeft - portions).clamp(0, 9999),
            status: l.portionsLeft - portions <= 0 ? ListingStatus.habis : l.status,
          )
        else
          l,
    ];
  }

  /// Validates and publishes. Returns the listing, or an Indonesian error message.
  ({Listing? listing, String? error}) publish(PublishDraft d) {
    final now = ref.read(clockProvider)();
    final error = (d.name.trim().isEmpty ? 'Nama makanan wajib diisi' : null) ??
        Validators.portions(d.portions) ??
        Validators.price(d.price) ??
        Validators.pickupTime(d.pickupBy, now);
    if (error != null) return (listing: null, error: error);
    final people = ref.read(mockDataProvider).people;
    final own = state.where((l) => l.isOwn).length;
    final listing = Listing(
      id: 'l_u${own + 1}_${now.millisecondsSinceEpoch}',
      provider: people[meId]!,
      photo: '',
      localPhotoPath: d.photoPath,
      name: d.name.trim(),
      category: d.category,
      portionsLeft: d.portions,
      price: d.price,
      negotiable: d.negotiable,
      pickupBy: d.pickupBy,
      pickupPoint: d.pickupPoint,
      position: LatLng(pogung.latitude - 0.0001 * (own + 1), pogung.longitude + 0.0002 * (own + 1)),
      aiStatus: d.aiStatus,
      aiConfidence: d.aiConfidence,
      cookedAt: now,
      isOwn: true,
    );
    state = [listing, ...state];
    return (listing: listing, error: null);
  }
}

final listingsProvider = NotifierProvider<ListingsNotifier, List<Listing>>(ListingsNotifier.new);

final listingByIdProvider = Provider.family<Listing?, String>((ref, id) {
  for (final l in ref.watch(listingsProvider)) {
    if (l.id == id) return l;
  }
  return null;
});

// ---------------- location, filters and the feed ----------------

class LocationNotifier extends Notifier<SavedLocation> {
  @override
  SavedLocation build() => locations.first;

  void select(SavedLocation l) => state = l;
}

final locationProvider = NotifierProvider<LocationNotifier, SavedLocation>(LocationNotifier.new);

/// Search radius in meters (1 km by default, "Perluas radius ke 2 km" sets 2 km).
final radiusMetersProvider = StateProvider<double>((ref) => walkableRadiusMeters);

enum FeedFilter {
  walkable('Bisa jalan kaki'),
  warm('Sedang hangat'),
  free('Makan gratis'),
  raw('Bahan mentah');

  const FeedFilter(this.label);
  final String label;
}

final feedFiltersProvider = StateProvider<Set<FeedFilter>>((ref) => {FeedFilter.walkable});

final searchQueryProvider = StateProvider<String>((ref) => '');

class FeedItem {
  const FeedItem(this.listing, this.distance);
  final Listing listing;
  final double distance;
}

bool isVisibleListing(Listing l, DateTime now) => !l.isSoldOut && !l.isExpired(now);

/// Listings near the chosen location, filtered, most urgent first ("Segera habis di sekitarmu").
final feedProvider = Provider<List<FeedItem>>((ref) {
  final now = ref.watch(clockProvider)();
  final here = ref.watch(locationProvider).position;
  final radius = ref.watch(radiusMetersProvider);
  final filters = ref.watch(feedFiltersProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final items = <FeedItem>[];
  for (final l in ref.watch(listingsProvider)) {
    if (!isVisibleListing(l, now)) continue;
    final d = distanceMeters(here, l.position);
    if (d > radius) continue;
    if (filters.contains(FeedFilter.walkable) && d > walkableRadiusMeters) continue;
    if (filters.contains(FeedFilter.warm) && !l.isWarm(now)) continue;
    if (filters.contains(FeedFilter.free) && !l.isFree) continue;
    if (filters.contains(FeedFilter.raw) && l.category != FoodCategory.bahanMentah) continue;
    if (query.isNotEmpty && !l.name.toLowerCase().contains(query) && !l.provider.name.toLowerCase().contains(query)) continue;
    items.add(FeedItem(l, d));
  }
  items.sort((a, b) {
    final byPortions = a.listing.portionsLeft.compareTo(b.listing.portionsLeft);
    return byPortions != 0 ? byPortions : a.distance.compareTo(b.distance);
  });
  return items;
});

enum FeedSort {
  nearest('Terdekat'),
  urgent('Segera habis');

  const FeedSort(this.label);
  final String label;
}

/// Sort order of the full list ("Semua makanan"); Beranda always shows the most urgent first.
final feedSortProvider = StateProvider<FeedSort>((ref) => FeedSort.nearest);

/// The feed (same filters as Beranda) in the chosen sort order.
final sortedFeedProvider = Provider<List<FeedItem>>((ref) {
  final items = [...ref.watch(feedProvider)];
  switch (ref.watch(feedSortProvider)) {
    case FeedSort.nearest:
      items.sort((a, b) => a.distance.compareTo(b.distance));
    case FeedSort.urgent:
      items.sort((a, b) {
        final byPortions = a.listing.portionsLeft.compareTo(b.listing.portionsLeft);
        return byPortions != 0 ? byPortions : a.distance.compareTo(b.distance);
      });
  }
  return items;
});

/// "Perluas radius ke 2 km": widens the radius and drops the walking-distance chip.
void expandRadius(WidgetRef ref) {
  ref.read(radiusMetersProvider.notifier).state = 2000;
  ref.read(feedFiltersProvider.notifier).state = {...ref.read(feedFiltersProvider)}..remove(FeedFilter.walkable);
}

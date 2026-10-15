import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../mock/mock_data.dart';
import '../models/enums.dart';
import '../models/listing.dart';
import '../models/recipe.dart';
import '../services/food_score.dart';
import '../services/fyp.dart';
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
    this.pickupPosition,
    this.description,
    this.bestBefore,
    this.photoPath,
    this.aiConfidence = 0,
    this.aiStatus = AiStatus.approved,
    this.aiCategory,
    this.healthTags = const {},
    this.recipe,
    this.deliveryFee,
    this.allowsPickup = true,
  });

  final String name;
  final FoodCategory category;
  final int portions;
  final int price;
  final bool negotiable;
  final DateTime pickupBy;
  final String pickupPoint;

  /// Where the pickup point is; null keeps the demo position near Pogung.
  final LatLng? pickupPosition;
  final String? description;
  final DateTime? bestBefore;
  final String? photoPath;
  final double aiConfidence;
  final AiStatus aiStatus;

  /// The category the AI suggested; differs from [category] when the provider corrected it via "Ubah".
  final FoodCategory? aiCategory;

  /// "Pilihan sehat" tags, pre-filled by the AI and confirmed by the provider.
  final Set<HealthTag> healthTags;

  /// Recipe idea attached for fresh ingredients ("Ide resep").
  final Recipe? recipe;

  /// "Bisa diantar (< 1 km)" with its fee; null keeps the food pickup only.
  final int? deliveryFee;

  /// "Ambil di tempat"; off for delivery-only food.
  final bool allowsPickup;
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

  /// Reserves [portions] for a receiver: "Sisa N porsi" drops right away, and at zero the listing shows as sold out.
  /// Returns false, changing nothing, when fewer portions are left.
  bool hold(String id, int portions) {
    final l = byId(id);
    if (l == null || portions < 1 || l.portionsLeft < portions) return false;
    state = [for (final x in state) x.id == id ? x.copyWith(portionsLeft: x.portionsLeft - portions) : x];
    return true;
  }

  /// Gives back portions held by a reservation that expired, so the food can be taken by someone else.
  void release(String id, int portions) {
    if (portions < 1) return;
    state = [for (final x in state) x.id == id ? x.copyWith(portionsLeft: x.portionsLeft + portions) : x];
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
    final error = (d.aiStatus == AiStatus.rejected ? 'Foto belum lolos pengecekan AI.' : null) ??
        (d.name.trim().isEmpty ? 'Nama makanan wajib diisi' : null) ??
        Validators.portions(d.portions) ??
        Validators.price(d.price) ??
        Validators.pickupTime(d.pickupBy, now) ??
        Validators.deliveryFee(d.deliveryFee) ??
        Validators.handover(d.allowsPickup, d.deliveryFee);
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
      position: d.pickupPosition ?? LatLng(pogung.latitude - 0.0001 * (own + 1), pogung.longitude + 0.0002 * (own + 1)),
      description: d.description,
      bestBefore: d.bestBefore,
      aiStatus: d.aiStatus,
      aiConfidence: d.aiConfidence,
      aiCategory: d.aiCategory,
      healthTags: d.healthTags,
      recipe: d.category == FoodCategory.bahanMentah ? d.recipe : null,
      cookedAt: now,
      isOwn: true,
      deliveryFee: d.deliveryFee,
      allowsPickup: d.allowsPickup,
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

/// Filter chips of the full list (B5b). Beranda filters by [categoryFilterProvider] instead.
enum FeedFilter {
  walkable('Bisa jalan kaki'),
  warm('Sedang hangat'),
  free('Makan gratis'),
  delivery('Bisa diantar');

  const FeedFilter(this.label);
  final String label;
}

final feedFiltersProvider = StateProvider<Set<FeedFilter>>((ref) => {FeedFilter.walkable});

/// Beranda category chip (All · Ready-to-Eat · Fresh Ingredient · Sealed Food). Null is "All".
final categoryFilterProvider = StateProvider<FoodCategory?>((ref) => null);

final searchQueryProvider = StateProvider<String>((ref) => '');

class FeedItem {
  const FeedItem(this.listing, this.distance, [this.score = 0]);
  final Listing listing;
  final double distance;

  /// [feedScore] within the search radius; higher comes first.
  final double score;
}

/// Highest [FeedItem.score] first; equal scores go nearest first.
int byScore(FeedItem a, FeedItem b) {
  final s = b.score.compareTo(a.score);
  return s != 0 ? s : a.distance.compareTo(b.distance);
}

bool isVisibleListing(Listing l, DateTime now) => !l.isSoldOut && !l.isExpired(now);

/// How much the user is likely to want [l], from the recommender's [ranking] (item id → position). 1 for everyone when
/// there is no ranking (the feed is then proximity × urgency); neutral for a listing the model does not rank.
double affinityOf(Listing l, Map<String, int> ranking) {
  if (ranking.isEmpty) return 1;
  final rank = l.fypItem == null ? null : ranking[l.fypItem];
  return rank == null ? neutralAffinity : affinityFromRank(rank, ranking.length);
}

/// Listings near the chosen location, filtered and ranked by [feedScore] (Beranda "Pilihan untukmu di sekitar"):
/// affinity from the FYP recommender × proximity × urgency, as in the PRD.
final feedProvider = Provider<List<FeedItem>>((ref) {
  final ranking = ref.watch(fypRankingProvider).valueOrNull ?? const <String, int>{};
  final now = ref.watch(clockProvider)();
  final here = ref.watch(locationProvider).position;
  final radius = ref.watch(radiusMetersProvider);
  final filters = ref.watch(feedFiltersProvider);
  final category = ref.watch(categoryFilterProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final items = <FeedItem>[];
  for (final l in ref.watch(listingsProvider)) {
    if (!isVisibleListing(l, now)) continue;
    final d = distanceMeters(here, l.position);
    if (d > radius) continue;
    if (filters.contains(FeedFilter.walkable) && d > walkableRadiusMeters) continue;
    if (filters.contains(FeedFilter.warm) && !l.isWarm(now)) continue;
    if (filters.contains(FeedFilter.free) && !l.isFree) continue;
    if (filters.contains(FeedFilter.delivery) && !l.canDeliver) continue;
    if (category != null && l.category != category) continue;
    if (query.isNotEmpty && !matchesQuery(l, query)) continue;
    items.add(FeedItem(l, d, feedScore(l, d, radius, now, affinity: affinityOf(l, ranking))));
  }
  items.sort(byScore);
  return items;
});

/// Beranda search rule: the typed words (lower case) are part of the food name or the provider's name.
bool matchesQuery(Listing l, String query) => l.name.toLowerCase().contains(query) || l.provider.name.toLowerCase().contains(query);

/// Visible listings inside the search radius around the chosen location (no category, search or chip filter): what the
/// search page draws its suggestions and popular words from.
final nearbyListingsProvider = Provider<List<Listing>>((ref) {
  final now = ref.watch(clockProvider)();
  final here = ref.watch(locationProvider).position;
  final radius = ref.watch(radiusMetersProvider);
  return [
    for (final l in ref.watch(listingsProvider))
      if (isVisibleListing(l, now) && distanceMeters(here, l.position) <= radius) l,
  ];
});

/// Words people look for ("Populer di sekitarmu" on the search page).
const popularVocabulary = ['Nasi', 'Ayam', 'Roti', 'Sayur', 'Telur', 'Lodeh', 'Wortel', 'Kol', 'Kue', 'Mie', 'Tempe', 'Tahu', 'Ikan', 'Buah'];

/// The [popularVocabulary] words that match at least one listing nearby, most matches first (ties keep vocabulary order).
final popularKeywordsProvider = Provider<List<String>>((ref) {
  final nearby = ref.watch(nearbyListingsProvider);
  final counts = <String, int>{};
  for (final w in popularVocabulary) {
    final n = nearby.where((l) => matchesQuery(l, w.toLowerCase())).length;
    if (n > 0) counts[w] = n;
  }
  final words = counts.keys.toList();
  words.sort((a, b) {
    final byCount = counts[b]!.compareTo(counts[a]!);
    return byCount != 0 ? byCount : popularVocabulary.indexOf(a).compareTo(popularVocabulary.indexOf(b));
  });
  return words.take(6).toList();
});

enum FeedSort {
  recommended('Rekomendasi', 'Pilihan untukmu, dekat dan segera habis'),
  nearest('Terdekat'),
  urgent('Segera habis');

  const FeedSort(this.label, [this.hint]);
  final String label;

  /// One-line explanation in the "Urutkan" sheet.
  final String? hint;
}

/// Sort order of the full list ("Semua makanan"); Beranda always uses the ranking ([FeedSort.recommended]).
final feedSortProvider = StateProvider<FeedSort>((ref) => FeedSort.recommended);

/// The feed (same filters as Beranda) in the chosen sort order.
final sortedFeedProvider = Provider<List<FeedItem>>((ref) {
  final items = [...ref.watch(feedProvider)];
  switch (ref.watch(feedSortProvider)) {
    case FeedSort.recommended:
      items.sort(byScore);
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

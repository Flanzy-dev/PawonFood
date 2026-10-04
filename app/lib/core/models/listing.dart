import 'package:latlong2/latlong.dart';

import 'enums.dart';
import 'person.dart';

class Listing {
  const Listing({
    required this.id,
    required this.provider,
    required this.photo,
    required this.name,
    required this.category,
    required this.portionsLeft,
    required this.price,
    required this.pickupBy,
    required this.pickupPoint,
    required this.position,
    this.originalPrice,
    this.negotiable = true,
    this.aiStatus = AiStatus.approved,
    this.aiConfidence = 0.9,
    this.status = ListingStatus.available,
    this.cookedAt,
    this.isOwn = false,
    this.localPhotoPath,
  });

  final String id;
  final Person provider;

  /// Asset path of the photo (mock data) or empty when [localPhotoPath] is used.
  final String photo;

  /// Path of a photo taken by the live camera (listings published in the app).
  final String? localPhotoPath;
  final String name;
  final FoodCategory category;
  final int portionsLeft;
  final int? originalPrice;
  final int price;
  final bool negotiable;
  final DateTime pickupBy;
  final String pickupPoint;
  final LatLng position;
  final AiStatus aiStatus;
  final double aiConfidence;
  final ListingStatus status;
  final DateTime? cookedAt;
  final bool isOwn;

  bool get isFree => price == 0;
  bool get isSoldOut => status == ListingStatus.habis || portionsLeft <= 0;
  bool isExpired(DateTime now) => status == ListingStatus.expired || now.isAfter(pickupBy);

  /// "Sedang hangat": cooked within the last 90 minutes.
  bool isWarm(DateTime now) => category == FoodCategory.makananMatang && cookedAt != null && now.difference(cookedAt!).inMinutes <= 90;

  Listing copyWith({int? portionsLeft, ListingStatus? status}) => Listing(
        id: id,
        provider: provider,
        photo: photo,
        localPhotoPath: localPhotoPath,
        name: name,
        category: category,
        portionsLeft: portionsLeft ?? this.portionsLeft,
        originalPrice: originalPrice,
        price: price,
        negotiable: negotiable,
        pickupBy: pickupBy,
        pickupPoint: pickupPoint,
        position: position,
        aiStatus: aiStatus,
        aiConfidence: aiConfidence,
        status: status ?? this.status,
        cookedAt: cookedAt,
        isOwn: isOwn,
      );

  /// Builds a listing from mock JSON. Times are relative to [now] so the data never goes stale.
  factory Listing.fromJson(Map<String, dynamic> j, Person provider, DateTime now, {String? ownerId}) => Listing(
        id: j['id'] as String,
        provider: provider,
        photo: j['photo'] as String,
        name: j['name'] as String,
        category: FoodCategory.fromKey(j['category'] as String),
        portionsLeft: (j['portions'] as num).toInt(),
        originalPrice: (j['originalPrice'] as num?)?.toInt(),
        price: (j['price'] as num).toInt(),
        negotiable: (j['negotiable'] ?? true) as bool,
        pickupBy: now.add(Duration(minutes: (j['pickupInMinutes'] as num).toInt())),
        pickupPoint: (j['pickupPoint'] ?? '') as String,
        position: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        aiConfidence: (j['aiConfidence'] as num?)?.toDouble() ?? 0.9,
        status: (j['soldOut'] ?? false) as bool ? ListingStatus.habis : ListingStatus.available,
        cookedAt: j['cookedMinutesAgo'] == null ? null : now.subtract(Duration(minutes: (j['cookedMinutesAgo'] as num).toInt())),
        isOwn: provider.id == ownerId,
      );
}

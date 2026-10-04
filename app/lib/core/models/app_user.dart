import 'enums.dart';
import '../services/points.dart';

/// The signed-in user.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.roles = const {UserRole.receiver, UserRole.provider},
    this.points = 0,
    this.pickupPoint = 'Kos Melati, Pogung',
    this.portionsShared = 0,
    this.portionsSaved = 0,
  });

  final String id;
  final String name;
  final String email;
  final Set<UserRole> roles;
  final int points;
  final String pickupPoint;
  final int portionsShared;
  final int portionsSaved;

  Tier get tier => tierFor(points);

  String get roleLabel {
    if (roles.contains(UserRole.receiver) && roles.contains(UserRole.provider)) return 'Penerima dan penyedia';
    return roles.contains(UserRole.provider) ? 'Penyedia' : 'Penerima';
  }

  double get kgSaved => (portionsSaved) * kgPerPortion;

  AppUser copyWith({String? name, String? email, Set<UserRole>? roles, int? points, String? pickupPoint, int? portionsShared, int? portionsSaved}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        roles: roles ?? this.roles,
        points: points ?? this.points,
        pickupPoint: pickupPoint ?? this.pickupPoint,
        portionsShared: portionsShared ?? this.portionsShared,
        portionsSaved: portionsSaved ?? this.portionsSaved,
      );

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: (j['email'] ?? '') as String,
        points: (j['points'] as num?)?.toInt() ?? 0,
        pickupPoint: (j['pickupPoint'] ?? 'Kos Melati, Pogung') as String,
        portionsShared: (j['portionsShared'] as num?)?.toInt() ?? 0,
        portionsSaved: (j['portionsSaved'] as num?)?.toInt() ?? 0,
      );
}

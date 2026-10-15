import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'listings_repository.dart';

/// App settings (D18d, D18f-D18h). Kept in memory for the MVP.
class AppSettings {
  const AppSettings({
    this.newMessages = true,
    this.offerUpdates = true,
    this.pickupReminder = true,
    this.nearbyFood = true,
    this.quietHours = true,
    this.quietFrom = const TimeOfDay(hour: 22, minute: 0),
    this.quietTo = const TimeOfDay(hour: 6, minute: 0),
    this.radiusMeters = 1000,
  });

  final bool newMessages;
  final bool offerUpdates;
  final bool pickupReminder;
  final bool nearbyFood;
  final bool quietHours;
  final TimeOfDay quietFrom;
  final TimeOfDay quietTo;
  final double radiusMeters;

  AppSettings copyWith({bool? newMessages, bool? offerUpdates, bool? pickupReminder, bool? nearbyFood, bool? quietHours, TimeOfDay? quietFrom, TimeOfDay? quietTo, double? radiusMeters}) =>
      AppSettings(
        newMessages: newMessages ?? this.newMessages,
        offerUpdates: offerUpdates ?? this.offerUpdates,
        pickupReminder: pickupReminder ?? this.pickupReminder,
        nearbyFood: nearbyFood ?? this.nearbyFood,
        quietHours: quietHours ?? this.quietHours,
        quietFrom: quietFrom ?? this.quietFrom,
        quietTo: quietTo ?? this.quietTo,
        radiusMeters: radiusMeters ?? this.radiusMeters,
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void update(AppSettings Function(AppSettings s) f) => state = f(state);

  /// "Radius default" also applies to Beranda and Peta right away.
  void setRadius(double meters) {
    state = state.copyWith(radiusMeters: meters);
    ref.read(radiusMetersProvider.notifier).state = meters;
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// `500 m`, `1 km`, `2 km`.
String formatRadius(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(m % 1000 == 0 ? 0 : 1).replaceAll('.', ',')} km';

/// `22.00`
String formatTimeOfDay(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

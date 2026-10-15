/// Three pickup deadline chips: the next half hour at least 45 minutes away, then +90 and +180 minutes.
/// (The mockups show 19.00 / 20.30 / 22.00.)
List<DateTime> suggestPickupTimes(DateTime now) {
  var t = now.add(const Duration(minutes: 45));
  final rem = t.minute % 30;
  if (rem != 0 || t.second != 0 || t.millisecond != 0) t = t.add(Duration(minutes: 30 - rem));
  t = DateTime(t.year, t.month, t.day, t.hour, t.minute);
  return [t, t.add(const Duration(minutes: 90)), t.add(const Duration(minutes: 180))];
}

/// The provider may set any pickup deadline ("Atur jam") from [pickupMinLead] to [pickupMaxLead] after now, in
/// [pickupStepMinutes] steps (PRD Core Feature 2, Proposed).
const pickupMinLead = Duration(minutes: 30);
const pickupMaxLead = Duration(hours: 6);
const pickupStepMinutes = 5;

DateTime _minute(DateTime t) => DateTime(t.year, t.month, t.day, t.hour, t.minute);

/// Earliest allowed deadline: now + 30 minutes, rounded up to the picker step.
DateTime pickupEarliest(DateTime now) {
  final t = _minute(now.add(pickupMinLead));
  final rem = t.minute % pickupStepMinutes;
  return rem == 0 && t.isAtSameMomentAs(now.add(pickupMinLead)) ? t : t.add(Duration(minutes: pickupStepMinutes - rem));
}

/// Latest allowed deadline: now + 6 hours, rounded down to the picker step.
DateTime pickupLatest(DateTime now) {
  final t = _minute(now.add(pickupMaxLead));
  return t.subtract(Duration(minutes: t.minute % pickupStepMinutes));
}

/// The wheel only knows hour and minute: the next time that hour and minute occur (today, or tomorrow when it has passed).
DateTime nextOccurrence(DateTime now, int hour, int minute) {
  final t = DateTime(now.year, now.month, now.day, hour, minute);
  return t.isAfter(now) ? t : t.add(const Duration(days: 1));
}

/// Three pickup deadline chips: the next half hour at least 45 minutes away, then +90 and +180 minutes.
/// (The mockups show 19.00 / 20.30 / 22.00.)
List<DateTime> suggestPickupTimes(DateTime now) {
  var t = now.add(const Duration(minutes: 45));
  final rem = t.minute % 30;
  if (rem != 0 || t.second != 0 || t.millisecond != 0) t = t.add(Duration(minutes: 30 - rem));
  t = DateTime(t.year, t.month, t.day, t.hour, t.minute);
  return [t, t.add(const Duration(minutes: 90)), t.add(const Duration(minutes: 180))];
}

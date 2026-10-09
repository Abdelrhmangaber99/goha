/// Inventory quantities are stored as integers in thousandths ("milli")
/// of the ingredient unit, so 1.5 pieces == 1500 and sums never suffer from
/// floating-point drift.
const int kMilli = 1000;

int milli(num value) => (value * kMilli).round();

const _arabicDigits = {
  '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
  '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
  '٫': '.', '،': '.', ',': '.',
};

/// Parses user input (Latin or Arabic-Indic digits, `.`/`٫`/`,` as decimal
/// separator, up to 3 decimals) into milli units. Returns null when invalid
/// or negative.
int? parseMilli(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  s = s.split('').map((c) => _arabicDigits[c] ?? c).join();
  if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(s)) return null;
  final parts = s.split('.');
  final whole = int.parse(parts[0]);
  final frac = parts.length == 2 ? int.parse(parts[1].padRight(3, '0')) : 0;
  return whole * kMilli + frac;
}

/// Parses a whole non-negative number (e.g. a bag count).
int? parseWhole(String input) {
  final m = parseMilli(input);
  if (m == null || m % kMilli != 0) return null;
  return m ~/ kMilli;
}

/// 1500 -> "1.5", 25000 -> "25".
String formatMilli(int value) {
  final negative = value < 0;
  final abs = value.abs();
  final whole = abs ~/ kMilli;
  final frac = abs % kMilli;
  var text = '$whole';
  if (frac != 0) {
    text += '.${frac.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '')}';
  }
  return negative ? '-$text' : text;
}

String formatQty(int value, String unit) => '${formatMilli(value)} $unit';

/// Splits a quantity into whole bags and the loose remainder of an opened bag.
({int fullBags, int looseMilli}) bagBreakdown(int total, int capacity) {
  if (capacity <= 0 || total <= 0) return (fullBags: 0, looseMilli: total < 0 ? 0 : total);
  return (fullBags: total ~/ capacity, looseMilli: total % capacity);
}

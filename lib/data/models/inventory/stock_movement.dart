enum MovementType {
  opening('رصيد بداية الشيفت'),
  orderConsumption('استهلاك أوردر'),
  orderReversal('رد مخزون (إلغاء/تعديل أوردر)'),
  addition('إضافة برسلة'),
  adjustment('تسوية المخزون'),
  correction('تصحيح بعد الإغلاق'),
  closing('إغلاق الشيفت');

  final String label;
  const MovementType(this.label);
}

/// One append-only ledger entry. [delta] is signed (milli units);
/// [before]/[after] are the ingredient balance around the movement.
class StockMovement {
  final int id;
  final int shiftId;
  final String ingredientId;
  final MovementType type;
  final int delta;
  final int before;
  final int after;
  final String unit;
  final int? orderId;
  final String employee;
  final DateTime time;
  final String note;
  final String refKey;

  const StockMovement({
    required this.id,
    required this.shiftId,
    required this.ingredientId,
    required this.type,
    required this.delta,
    required this.before,
    required this.after,
    required this.unit,
    required this.employee,
    required this.time,
    required this.refKey,
    this.orderId,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'shiftId': shiftId,
        'ingredientId': ingredientId,
        'type': type.name,
        'delta': delta,
        'before': before,
        'after': after,
        'unit': unit,
        'orderId': orderId,
        'employee': employee,
        'time': time.toIso8601String(),
        'note': note,
        'refKey': refKey,
      };

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
        id: j['id'] as int,
        shiftId: j['shiftId'] as int,
        ingredientId: j['ingredientId'] as String,
        type: MovementType.values.byName(j['type'] as String),
        delta: j['delta'] as int,
        before: j['before'] as int,
        after: j['after'] as int,
        unit: j['unit'] as String,
        orderId: j['orderId'] as int?,
        employee: j['employee'] as String? ?? '',
        time: DateTime.parse(j['time'] as String),
        note: j['note'] as String? ?? '',
        refKey: j['refKey'] as String,
      );
}

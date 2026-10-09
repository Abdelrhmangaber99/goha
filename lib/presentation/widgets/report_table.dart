import 'package:flutter/material.dart';

import '../../logic/shift/shift_state.dart';

/// Renders one category's sales table for either the restaurant or goha side.
class ReportCategoryTable extends StatelessWidget {
  final String category;
  final List<ShiftItemSales> rows;
  final bool isRestaurant;

  const ReportCategoryTable({
    super.key,
    required this.category,
    required this.rows,
    required this.isRestaurant,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              border: const Border(right: BorderSide(color: Color(0xFF333333), width: 4)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Table(
            border: TableBorder.all(color: const Color(0xFFDDDDDD)),
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1.4),
            },
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Color(0xFFFAFAFA)),
                children: [
                  _Cell('الصنف', bold: true),
                  _Cell('الكمية', bold: true),
                  _Cell('المبلغ', bold: true),
                ],
              ),
              for (final row in rows)
                TableRow(
                  children: [
                    _Cell(row.itemKey, align: TextAlign.right),
                    _Cell('${isRestaurant ? row.restQty : row.gohaQty}'),
                    _Cell('${(isRestaurant ? row.restPrice : row.gohaPrice).toStringAsFixed(0)} ج.م'),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool bold;
  final TextAlign align;

  const _Cell(this.text, {this.bold = false, this.align = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: 12.5),
      ),
    );
  }
}

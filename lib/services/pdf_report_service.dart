import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;

import '../logic/shift/shift_state.dart';

/// Builds the end-of-shift PDF report, mirroring the on-screen report.
class PdfReportService {
  const PdfReportService();

  Future<Uint8List> build({
    required ShiftState shift,
    required String cashierName,
  }) async {
    final arabicFont = await PdfGoogleFonts.notoNaskhArabicRegular();
    final arabicBold = await PdfGoogleFonts.notoNaskhArabicBold();

    final doc = pw.Document(
      // The Arabic font alone has no glyphs for Western digits, "/", ":",
      // "AM/PM", "|", etc. (all used in dates/prices/quantities), which
      // rendered as black tofu boxes. Helvetica is bundled with the `pdf`
      // package (no download) and covers all of that as a fallback.
      theme: pw.ThemeData.withFont(
        base: arabicFont,
        bold: arabicBold,
        fontFallback: [pw.Font.helvetica(), pw.Font.helveticaBold()],
      ),
    );

    final salesByCategory = shift.salesByCategory;

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'تقرير نهاية الشيفت التفصيلي',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'الكاشير: $cashierName   |   التاريخ: ${DateFormat('yyyy/MM/dd hh:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 14),
          _sectionHeader('1. مبيعات المطعم (فقط)', PdfColors.green700),
          ..._categoryTables(salesByCategory, isRestaurant: true),
          _totalBanner(
            'إجمالي مبيعات المطعم: ${shift.restaurantRevenue.toStringAsFixed(0)} ج.م',
            PdfColors.green50,
            PdfColors.green200,
          ),
          pw.SizedBox(height: 18),
          _sectionHeader('2. مبيعات جحا (فقط)', PdfColors.purple700),
          ..._categoryTables(salesByCategory, isRestaurant: false),
          _totalBanner(
            'إجمالي مبيعات جحا: ${shift.gohaRevenue.toStringAsFixed(0)} ج.م',
            PdfColors.purple50,
            PdfColors.purple200,
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue700,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'الإجمالي الكلي (المطعم + جحا): ${shift.grandTotal.toStringAsFixed(0)} ج.م',
                  style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'إجمالي عدد الطلبات: ${shift.orders.length}',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _sectionHeader(String title, PdfColor color) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Text(
          title,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 13),
        ),
      );

  pw.Widget _totalBanner(String text, PdfColor bg, PdfColor border) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: bg,
          border: pw.Border.all(color: border),
        ),
        child: pw.Text(text, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
      );

  List<pw.Widget> _categoryTables(
    Map<String, Map<String, ShiftItemSales>> salesByCategory, {
    required bool isRestaurant,
  }) {
    final widgets = <pw.Widget>[];
    bool hasAny = false;

    for (final entry in salesByCategory.entries) {
      final rows = entry.value.values
          .where((r) => (isRestaurant ? r.restQty : r.gohaQty) > 0)
          .toList();
      if (rows.isEmpty) continue;
      hasAny = true;
      widgets.add(pw.Container(
        margin: const pw.EdgeInsets.only(top: 8, bottom: 2),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: PdfColors.grey200,
        child: pw.Text(entry.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      ));
      widgets.add(
        pw.TableHelper.fromTextArray(
          headers: const ['الصنف', 'الكمية', 'المبلغ'],
          data: [
            for (final r in rows)
              [
                r.itemKey,
                '${isRestaurant ? r.restQty : r.gohaQty}',
                '${(isRestaurant ? r.restPrice : r.gohaPrice).toStringAsFixed(0)} ج.م',
              ],
          ],
          cellAlignment: pw.Alignment.center,
          cellAlignments: {0: pw.Alignment.centerRight},
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        ),
      );
    }

    if (!hasAny) {
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Center(
          child: pw.Text(
            isRestaurant ? 'لا توجد مبيعات للمطعم' : 'لا توجد مبيعات لجحا',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 11),
          ),
        ),
      ));
    }

    return widgets;
  }
}

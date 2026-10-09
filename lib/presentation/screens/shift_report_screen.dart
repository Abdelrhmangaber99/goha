import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../app/theme.dart';
import '../../logic/cashier/cashier_cubit.dart';
import '../../logic/shift/shift_cubit.dart';
import '../../logic/shift/shift_state.dart';
import '../../services/pdf_report_service.dart';
import '../widgets/order_manage_card.dart';
import '../widgets/report_table.dart';

class ShiftReportScreen extends StatelessWidget {
  const ShiftReportScreen({super.key});

  Future<bool> _confirm(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _downloadPdf(BuildContext context, ShiftState shift, String cashierName) async {
    HapticFeedback.mediumImpact();
    try {
      final bytes = await const PdfReportService().build(shift: shift, cashierName: cashierName);
      final fileName = 'Shift_Report_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.pdf';
      if (!context.mounted) return;
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء التقرير: يرجى التأكد من الاتصال بالإنترنت أولاً.\n$e')),
      );
    }
  }

  Future<void> _resetShift(BuildContext context, ShiftCubit cubit) async {
    HapticFeedback.mediumImpact();
    final ok = await _confirm(context, 'هل أنت متأكد من تصفير الشيفت الحالي؟');
    if (!ok) return;
    final error = await cubit.resetShift();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'تم تصفير مبيعات الشيفت بنجاح!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cashierName = context.watch<CashierCubit>().state.name;

    return Scaffold(
      appBar: AppBar(title: const Text('تقرير نهاية الشيفت')),
      body: BlocBuilder<ShiftCubit, ShiftState>(
        builder: (context, shift) {
          final salesByCategory = shift.salesByCategory;
          final restCategories = salesByCategory.entries
              .where((e) => e.value.values.any((r) => r.restQty > 0))
              .toList();
          final gohaCategories = salesByCategory.entries
              .where((e) => e.value.values.any((r) => r.gohaQty > 0))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Center(
                child: Text(
                  'تقرير نهاية الشيفت التفصيلي',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'الكاشير: $cashierName   |   ${DateFormat('yyyy/MM/dd hh:mm a').format(DateTime.now())}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _SectionHeader(title: '1. مبيعات المطعم (فقط)', color: AppColors.restaurant),
              if (restCategories.isEmpty)
                const _EmptyNote(text: 'لا توجد مبيعات للمطعم')
              else
                for (final entry in restCategories)
                  ReportCategoryTable(
                    category: entry.key,
                    rows: entry.value.values.where((r) => r.restQty > 0).toList(),
                    isRestaurant: true,
                  ),
              _TotalBanner(
                text: 'إجمالي مبيعات المطعم: ${shift.restaurantRevenue.toStringAsFixed(0)} ج.م',
                bg: const Color(0xFFEAFAF1),
                border: const Color(0xFFD4EFDF),
              ),
              const SizedBox(height: 18),
              _SectionHeader(title: '2. مبيعات جحا (فقط)', color: AppColors.goha),
              if (gohaCategories.isEmpty)
                const _EmptyNote(text: 'لا توجد مبيعات لجحا')
              else
                for (final entry in gohaCategories)
                  ReportCategoryTable(
                    category: entry.key,
                    rows: entry.value.values.where((r) => r.gohaQty > 0).toList(),
                    isRestaurant: false,
                  ),
              _TotalBanner(
                text: 'إجمالي مبيعات جحا: ${shift.gohaRevenue.toStringAsFixed(0)} ج.م',
                bg: const Color(0xFFF4ECF7),
                border: const Color(0xFFEBDEF0),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.info, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Text(
                      'الإجمالي الكلي (المطعم + جحا): ${shift.grandTotal.toStringAsFixed(0)} ج.م',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text('إجمالي عدد الطلبات: ${shift.orders.length}', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(thickness: 2),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'إدارة الطلبات المسجلة (إلغاء أوردر أو صنف محدد)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15),
                ),
              ),
              if (shift.orders.isEmpty)
                const _EmptyNote(text: 'لا توجد طلبات مسجلة حتى الآن.')
              else
                for (final order in shift.orders.reversed)
                  OrderManageCard(
                    order: order,
                    isExpanded: shift.expandedOrderIds.contains(order.id),
                  ),
              const SizedBox(height: 90),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: BlocBuilder<ShiftCubit, ShiftState>(
            builder: (context, shift) {
              final cubit = context.read<ShiftCubit>();
              return Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5BC0DE)),
                      onPressed: () => _downloadPdf(context, shift, cashierName),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('مشاركة/تحميل PDF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5CB85C)),
                      onPressed: () => _resetShift(context, cubit),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('تصفير الشيفت'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}

class _TotalBanner extends StatelessWidget {
  final String text;
  final Color bg;
  final Color border;

  const _TotalBanner({required this.text, required this.bg, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
      child: Text(text, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;

  const _EmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: Text(text, style: TextStyle(color: Colors.grey.shade600))),
    );
  }
}

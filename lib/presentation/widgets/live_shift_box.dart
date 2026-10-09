import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/shift/shift_cubit.dart';

class LiveShiftBox extends StatelessWidget {
  const LiveShiftBox({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ShiftCubit>().state;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF7FF),
        border: Border.all(color: const Color(0xFFBCE8F1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مبيعات الشيفت الحالية: ${state.grandTotal.toStringAsFixed(0)} ج.م',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF31708F)),
          ),
          const SizedBox(height: 2),
          Text(
            'المطعم: ${state.restaurantRevenue.toStringAsFixed(0)} ج.م | جحا: ${state.gohaRevenue.toStringAsFixed(0)} ج.م',
            style: const TextStyle(fontSize: 12, color: Color(0xFF31708F)),
          ),
        ],
      ),
    );
  }
}

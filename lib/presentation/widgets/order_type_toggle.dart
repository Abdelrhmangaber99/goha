import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../../data/models/order.dart';
import '../../logic/cart/cart_cubit.dart';

class OrderTypeToggle extends StatelessWidget {
  const OrderTypeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<CartCubit>().state.orderType;
    return Row(
      children: [
        Expanded(
          child: _TypeButton(
            label: 'المطعم',
            icon: Icons.restaurant,
            color: AppColors.restaurant,
            isActive: selected == OrderType.restaurant,
            onTap: () {
              HapticFeedback.lightImpact();
              context.read<CartCubit>().setOrderType(OrderType.restaurant);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TypeButton(
            label: 'جحا',
            icon: Icons.storefront,
            color: AppColors.goha,
            isActive: selected == OrderType.goha,
            onTap: () {
              HapticFeedback.lightImpact();
              context.read<CartCubit>().setOrderType(OrderType.goha);
            },
          ),
        ),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? color : const Color(0xFFCCCCCC), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? Colors.white : Colors.black54),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

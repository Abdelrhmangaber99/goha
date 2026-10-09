import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../../logic/cart/cart_cubit.dart';

class CustomItemForm extends StatefulWidget {
  const CustomItemForm({super.key});

  @override
  State<CustomItemForm> createState() => _CustomItemFormState();
}

class _CustomItemFormState extends State<CustomItemForm> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _add() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    if (name.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم صنف صحيح وسعر أكبر من صفر!')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    context.read<CartCubit>().addItem(
          name: name,
          size: 'عادي',
          price: price,
          category: 'أصناف خاصة / خارجية',
        );
    _nameController.clear();
    _priceController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.warning, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'إضافة صنف غير مدرج بالقائمة',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم الصنف'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'السعر (ج.م)'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                onPressed: _add,
                child: const Text('إضافة إلى السلة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

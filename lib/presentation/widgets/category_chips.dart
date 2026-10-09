import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../../data/models/menu_category.dart';
import '../../logic/menu_nav/menu_nav_cubit.dart';

class CategoryChips extends StatelessWidget {
  final List<MenuCategory> categories;

  const CategoryChips({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<MenuNavCubit>().state;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isActive = index == selected;
          final isCustom = category.isCustom;
          return ChoiceChip(
            label: Text(category.name),
            selected: isActive,
            onSelected: (_) => context.read<MenuNavCubit>().select(index),
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive
                  ? Colors.white
                  : (isCustom ? AppColors.warning : Colors.black87),
            ),
            selectedColor: isCustom ? const Color(0xFFEC971F) : AppColors.primary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isCustom ? AppColors.warning : const Color(0xFFCCCCCC),
            ),
          );
        },
      ),
    );
  }
}

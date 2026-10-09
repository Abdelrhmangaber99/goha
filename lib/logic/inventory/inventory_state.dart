import 'package:equatable/equatable.dart';

import '../../data/models/inventory/ingredient.dart';
import '../../data/models/inventory/inventory_shift.dart';
import '../../data/models/inventory/recipe.dart';

class InventoryState extends Equatable {
  final List<Ingredient> ingredients;
  final List<Recipe> recipes;
  final List<InventoryShift> shifts;
  final int nextShiftId;
  final int nextMovementId;
  final String? managerPin;
  final bool managerUnlocked;
  final bool isLoading;
  final int revision;

  const InventoryState({
    required this.ingredients,
    required this.recipes,
    required this.shifts,
    required this.nextShiftId,
    required this.nextMovementId,
    this.managerPin,
    this.managerUnlocked = false,
    this.isLoading = false,
    this.revision = 0,
  });

  static const initial = InventoryState(
    ingredients: [],
    recipes: [],
    shifts: [],
    nextShiftId: 1,
    nextMovementId: 1,
    isLoading: true,
  );

  InventoryShift? get activeShift {
    for (final s in shifts.reversed) {
      if (s.isOpen) return s;
    }
    return null;
  }

  List<InventoryShift> get closedShifts => shifts.where((s) => !s.isOpen).toList().reversed.toList();

  Ingredient? ingredient(String id) {
    for (final i in ingredients) {
      if (i.id == id) return i;
    }
    return null;
  }

  Recipe? recipeFor(String name, String size) {
    final key = recipeKey(name, size);
    for (final r in recipes) {
      if (r.key == key) return r;
    }
    return null;
  }

  InventoryState copyWith({
    List<Ingredient>? ingredients,
    List<Recipe>? recipes,
    List<InventoryShift>? shifts,
    int? nextShiftId,
    int? nextMovementId,
    String? managerPin,
    bool? managerUnlocked,
    bool? isLoading,
  }) =>
      InventoryState(
        ingredients: ingredients ?? this.ingredients,
        recipes: recipes ?? this.recipes,
        shifts: shifts ?? this.shifts,
        nextShiftId: nextShiftId ?? this.nextShiftId,
        nextMovementId: nextMovementId ?? this.nextMovementId,
        managerPin: managerPin ?? this.managerPin,
        managerUnlocked: managerUnlocked ?? this.managerUnlocked,
        isLoading: isLoading ?? this.isLoading,
        revision: revision + 1,
      );

  @override
  List<Object?> get props => [revision, managerUnlocked, isLoading];
}

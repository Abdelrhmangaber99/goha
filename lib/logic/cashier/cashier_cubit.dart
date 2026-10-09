import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/local_storage_service.dart';

class CashierState {
  final String name;
  final bool isLoading;

  const CashierState({required this.name, required this.isLoading});

  bool get isSet => name.trim().isNotEmpty;

  CashierState copyWith({String? name, bool? isLoading}) => CashierState(
        name: name ?? this.name,
        isLoading: isLoading ?? this.isLoading,
      );

  static const initial = CashierState(name: '', isLoading: true);
}

class CashierCubit extends Cubit<CashierState> {
  final LocalStorageService _storage;

  CashierCubit(this._storage) : super(CashierState.initial) {
    _load();
  }

  Future<void> _load() async {
    final name = await _storage.loadCashierName();
    emit(state.copyWith(name: name ?? '', isLoading: false));
  }

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    emit(state.copyWith(name: trimmed));
    await _storage.saveCashierName(trimmed);
  }
}

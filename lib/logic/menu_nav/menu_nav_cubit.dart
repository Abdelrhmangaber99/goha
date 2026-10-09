import 'package:flutter_bloc/flutter_bloc.dart';

/// Tracks which menu category tab is currently selected.
class MenuNavCubit extends Cubit<int> {
  MenuNavCubit() : super(0);

  void select(int index) => emit(index);
}
///
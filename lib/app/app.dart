import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/local_storage_service.dart';
import '../logic/cart/cart_cubit.dart';
import '../logic/cashier/cashier_cubit.dart';
import '../logic/inventory/inventory_cubit.dart';
import '../logic/menu_nav/menu_nav_cubit.dart';
import '../logic/shift/shift_cubit.dart';
import '../presentation/screens/cashier_gate_screen.dart';
import 'theme.dart';

class CasherApp extends StatelessWidget {
  const CasherApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = LocalStorageService();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CashierCubit(storage)),
        BlocProvider(create: (_) => CartCubit(storage)),
        BlocProvider(create: (_) => InventoryCubit(storage)),
        BlocProvider(create: (ctx) => ShiftCubit(storage, ctx.read<InventoryCubit>())),
        BlocProvider(create: (_) => MenuNavCubit()),
      ],
      child: MaterialApp(
        title: 'نظام الكاشير - جحا',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: const CashierGateScreen(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'state/work_order_store.dart';

void main() {
  runApp(const FirstApp());
}

class FirstApp extends StatelessWidget {
  const FirstApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkOrderStore(createApiClient(useMock: true))..refresh(),
      child: MaterialApp(
        title: 'Leidingwerk',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF0064C8),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/hero_provider.dart';
import 'repositories/hero_repository.dart';
import 'screens/home_screen.dart';
import 'data/hero_database.dart';
import 'providers/squad_provider.dart';
import 'repositories/squad_repository.dart';
import 'providers/mission_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final database = HeroDatabase();
    final heroRepository = HeroRepository(database: database);
    final squadRepository = SquadRepository(database);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => HeroProvider(heroRepository)..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => SquadProvider(squadRepository, heroRepository),
        ),
        ChangeNotifierProvider(
          create: (context) => MissionProvider(
            heroRepository,
            squadRepository,
            onMemberUpdated: context.read<SquadProvider>().updateMember,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Agentes',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF285C70)),
          scaffoldBackgroundColor: const Color(0xFFF3F6F8),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

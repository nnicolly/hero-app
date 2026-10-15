import 'package:flutter/material.dart';

import 'agents_screen.dart';
import 'daily_contract_screen.dart';
import 'squad_screen.dart';
import 'missions_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Central de Agentes')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _entry(
                context,
                'Agentes',
                Icons.people_outline,
                const AgentsScreen(),
              ),
              _entry(
                context,
                'Contrato Diário',
                Icons.event_available,
                const DailyContractScreen(),
              ),
              _entry(
                context,
                'Meu Esquadrão',
                Icons.groups,
                const SquadScreen(),
              ),
              _entry(
                context,
                'Missões',
                Icons.flag_outlined,
                const MissionsScreen(),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _entry(
    BuildContext context,
    String title,
    IconData icon,
    Widget screen,
  ) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
    ),
  );
}

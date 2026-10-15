import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hero.dart' as model;
import '../providers/squad_provider.dart';
import '../widgets/hero_details_content.dart';

class SquadAgentDetailsScreen extends StatelessWidget {
  final int heroId;
  const SquadAgentDetailsScreen({super.key, required this.heroId});

  Future<void> _confirmDismiss(BuildContext context, model.Hero hero) async {
    var confirmed = false;
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      headerAnimationLoop: false,
      title: 'Dispensar agente?',
      desc: 'Deseja realmente dispensar ${hero.name} do esquadrão?',
      btnCancelText: 'Cancelar',
      btnCancelOnPress: () {},
      btnOkText: 'Confirmar',
      btnOkColor: Theme.of(context).colorScheme.error,
      btnOkOnPress: () => confirmed = true,
    ).show();
    if (!confirmed || !context.mounted) return;
    final provider = context.read<SquadProvider>();
    final success = await provider.dismissMember(hero.id);
    if (!context.mounted) return;
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${hero.name} foi dispensado do Esquadrão.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.dismissalError ??
                'Aguarde a operação atual e tente novamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalhes do Meu Agente')),
    body: SafeArea(
      child: Consumer<SquadProvider>(
        builder: (context, provider, child) {
          final matches = provider.members.where((hero) => hero.id == heroId);
          if (matches.isEmpty) {
            return const Center(
              child: Text('Este agente não faz mais parte do esquadrão.'),
            );
          }
          final hero = matches.first;
          return HeroDetailsContent(
            hero: hero,
            action: FilledButton.icon(
              onPressed: provider.dismissing
                  ? null
                  : () => _confirmDismiss(context, hero),
              icon: const Icon(Icons.person_remove),
              label: Text(
                provider.dismissing ? 'Dispensando…' : 'Dispensar do Esquadrão',
              ),
            ),
          );
        },
      ),
    ),
  );
}

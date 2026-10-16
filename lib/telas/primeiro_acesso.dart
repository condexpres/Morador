import 'package:flutter/material.dart';

import '../dados/store.dart';
import '../tema.dart';
import '../util/formatos.dart';
import '../widgets/componentes.dart';
import '../widgets/marca.dart';
import 'dialogos.dart';

/// Primeiro acesso: o morador entrou com a senha provisória gerada pela
/// administração e precisa criar a própria senha (ou vincular o Google).
/// Não há abas nesta tela: nada aparece clicável sem funcionar.
class TelaPrimeiroAcesso extends StatefulWidget {
  const TelaPrimeiroAcesso({super.key});

  @override
  State<TelaPrimeiroAcesso> createState() => _TelaPrimeiroAcessoState();
}

class _TelaPrimeiroAcessoState extends State<TelaPrimeiroAcesso> {
  final _nova = TextEditingController();
  final _confirma = TextEditingController();
  String? _erro;

  bool _salvando = false;

  Future<void> _criar() async {
    setState(() => _salvando = true);
    final msg = await StoreScope.ler(context).criarSenha(_nova.text, _confirma.text);
    if (!mounted) return;
    setState(() => _salvando = false);
    if (msg != null) return setState(() => _erro = msg);
    avisar(context, 'Senha criada. Bem-vindo(a) ao Condexpress!');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final perfil = store.perfil;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [SimboloCondexpress(tamanho: 30), SizedBox(width: 10), Flexible(child: Text('Primeiro acesso', overflow: TextOverflow.ellipsis))]),
        actions: [TextButton(onPressed: store.sair, child: const Text('Sair'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Cores.primaria.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.key_outlined, color: Cores.primaria, size: 28),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Olá, ${primeiroNome(perfil.nome)}!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Você entrou com a senha provisória enviada pela administração. Para proteger sua conta, crie uma senha só sua.'),
                const SizedBox(height: 20),
                CampoSenha(controle: _nova, rotulo: 'Nova senha', dica: 'Ex.: casa2025azul', aoMudar: (_) => setState(() => _erro = null)),
                MedidorSenha(_nova.text),
                const SizedBox(height: 10),
                CampoSenha(controle: _confirma, rotulo: 'Repita a nova senha', dica: 'Digite a mesma senha'),
                if (_erro != null)
                  Padding(padding: const EdgeInsets.only(top: 10), child: Text(_erro!, style: const TextStyle(color: Cores.erro, fontWeight: FontWeight.w600))),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: _salvando ? null : _criar, icon: const Icon(Icons.check), label: const Text('Criar senha e continuar')),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('ou')), Expanded(child: Divider())]),
                ),
                OutlinedButton.icon(
                  onPressed: () => abrirGoogle(context, entrar: false),
                  icon: const Icon(Icons.link),
                  label: const Text('Vincular conta Google'),
                ),
                const SizedBox(height: 8),
                Text('Com o Google vinculado, você entra sem digitar senha.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../dados/store.dart';
import '../tema.dart';
import '../util/formatos.dart';
import '../widgets/componentes.dart';
import '../widgets/marca.dart';

/// [Prova] Termo de uso: o morador lê e aceita antes de usar o app.
/// O aceite fica registrado no servidor com data, hora e hash (não pode ser apagado).
/// Não há abas nesta tela: nada aparece clicável sem funcionar.
class TelaTermo extends StatefulWidget {
  const TelaTermo({super.key});

  @override
  State<TelaTermo> createState() => _TelaTermoState();
}

class _TelaTermoState extends State<TelaTermo> {
  bool _aceito = false;
  bool _salvando = false;
  String? _erro;

  Future<void> _aceitar() async {
    if (!_aceito) return setState(() => _erro = 'Marque "Li e aceito" para continuar.');
    setState(() => _salvando = true);
    final erro = await StoreScope.ler(context).aceitarTermo();
    if (!mounted) return;
    setState(() {
      _salvando = false;
      _erro = erro;
    });
    if (erro == null) avisar(context, 'Termo aceito. Bem-vindo(a) ao Condexpress!');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [SimboloCondexpress(tamanho: 30), SizedBox(width: 10), Flexible(child: Text('Termo de uso', overflow: TextOverflow.ellipsis))]),
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
                    child: const Icon(Icons.verified_user_outlined, color: Cores.primaria, size: 28),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Olá, ${primeiroNome(store.perfil.nome)}!', style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Antes de começar, leia como o Condexpress registra as suas encomendas.'),
                const SizedBox(height: 16),
                for (var i = 0; i < termoTexto.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 24, child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Expanded(child: Text(termoTexto[i], style: const TextStyle(height: 1.45))),
                    ]),
                  ),
                const SizedBox(height: 6),
                CheckboxListTile(
                  value: _aceito,
                  onChanged: (v) => setState(() {
                    _aceito = v ?? false;
                    _erro = null;
                  }),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Li e aceito o termo de uso', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Versão $termoVersao · o aceite fica registrado com data e hora'),
                ),
                if (_erro != null)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(_erro!, style: const TextStyle(color: Cores.erro, fontWeight: FontWeight.w600))),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _salvando ? null : _aceitar,
                  icon: const Icon(Icons.check),
                  label: const Text('Aceitar e continuar'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

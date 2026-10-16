import 'package:flutter/material.dart';

import '../dados/store.dart';
import '../tema.dart';
import '../util/formatos.dart';
import '../widgets/componentes.dart';

/// [REQ-11] Pré-cadastro: o morador avisa a portaria sobre uma compra a caminho.
class TelaAvisarCompra extends StatefulWidget {
  const TelaAvisarCompra({super.key});

  @override
  State<TelaAvisarCompra> createState() => _TelaAvisarCompraState();
}

class _TelaAvisarCompraState extends State<TelaAvisarCompra> {
  final _loja = TextEditingController();
  final _descricao = TextEditingController();
  bool _tentou = false;

  void _avisar() {
    setState(() => _tentou = true);
    if (_loja.text.trim().isEmpty || _descricao.text.trim().isEmpty) return;
    StoreScope.ler(context).avisarCompra(_loja.text, _descricao.text);
    _loja.clear();
    _descricao.clear();
    setState(() => _tentou = false);
    FocusScope.of(context).unfocus();
    avisar(context, 'Portaria avisada da sua compra.');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final compras = store.conta!.compras;
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Text('Avisar compra', style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Comprou algo? Avise a portaria e a triagem fica mais rápida quando o pacote chegar.', style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Nova compra a caminho', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 14),
              TextField(
                controller: _loja,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Loja ou remetente',
                  hintText: 'Ex.: Amazon, Shopee',
                  errorText: _tentou && _loja.text.trim().isEmpty ? 'Informe a loja' : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descricao,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _avisar(),
                decoration: InputDecoration(
                  labelText: 'O que é?',
                  hintText: 'Ex.: Fone de ouvido',
                  errorText: _tentou && _descricao.text.trim().isEmpty ? 'Descreva a compra' : null,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(onPressed: _avisar, icon: const Icon(Icons.add), label: const Text('Avisar portaria')),
            ]),
          ),
        ),
        const TituloSecao('Compras avisadas'),
        if (compras.isEmpty)
          const EstadoVazio(icone: Icons.assignment_outlined, titulo: 'Nenhuma compra avisada', texto: 'Use o formulário acima para avisar a portaria.')
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < compras.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (compras[i].recebido ? Cores.ok : Cores.alerta).withValues(alpha: 0.12),
                    child: Icon(compras[i].recebido ? Icons.check : Icons.schedule, color: compras[i].recebido ? Cores.ok : Cores.alerta),
                  ),
                  title: Text(compras[i].loja, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${compras[i].descricao} · avisado ${tempoRelativo(compras[i].criadoEm)}\n'
                      '${compras[i].recebido ? 'Chegou na portaria' : 'Portaria avisada'}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Remover',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      final compra = compras[i];
                      final desfazer = store.removerCompra(compra);
                      avisar(context, 'Compra removida.', rotulo: 'Desfazer', acao: desfazer);
                    },
                  ),
                ),
              ],
            ]),
          ),
      ],
    );
  }
}

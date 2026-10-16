import 'package:flutter/material.dart';

import '../dados/modelos.dart';
import '../dados/store.dart';
import '../tema.dart';
import '../util/formatos.dart';
import '../widgets/componentes.dart';

/// Detalhes da encomenda numa "gaveta" que sobe de baixo.
void abrirDetalhes(BuildContext context, Encomenda e) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      builder: (ctx, rolagem) {
        final tema = Theme.of(ctx);
        return ListView(
          controller: rolagem,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text(e.codigo, style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [StatusEncomendaTag(e, grande: true), ...selos(e)]),
            const SizedBox(height: 20),
            StepperRastreio(e),
            const SizedBox(height: 20),
            if (e.naPortaria)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: tema.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mostre este código ao porteiro', style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  CodigoCaixas(e.token),
                ]),
              ),
            // [REQ-04] Foto tirada pela portaria (fica no Storage, só o morador dono vê)
            ImagemServidor(
              foto: e.foto,
              construir: (imagem) => ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image(
                  image: imagem,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  semanticLabel: 'Foto do pacote',
                  errorBuilder: (_, _, _) => _SemFoto(e),
                ),
              ),
              reserva: _SemFoto(e),
            ),
            const SizedBox(height: 12),
            LinhaInfo('Remetente', e.remetente),
            LinhaInfo('Descrição', e.descricao),
            LinhaInfo('Recebida por', e.recebidaPor),
            if (!e.naPortaria) LinhaInfo('Retirada por', e.retiradoPor ?? '—'),
            const SizedBox(height: 16),
            Text('Linha do tempo', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (var i = 0; i < e.eventos.length; i++) _ItemLinhaDoTempo(e.eventos[i], ultimo: i == e.eventos.length - 1),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => abrirComprovante(ctx, e, entrega: false),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Comprovante de recebimento'),
            ),
            if (!e.naPortaria) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => abrirComprovante(ctx, e, entrega: true),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Comprovante de entrega'),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _ItemLinhaDoTempo extends StatelessWidget {
  const _ItemLinhaDoTempo(this.evento, {required this.ultimo});

  final Evento evento;
  final bool ultimo;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 22,
            child: Column(children: [
              Container(margin: const EdgeInsets.only(top: 4), width: 10, height: 10, decoration: const BoxDecoration(color: Cores.primaria, shape: BoxShape.circle)),
              if (!ultimo) Expanded(child: Container(width: 2, color: Theme.of(context).dividerColor)),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dataHora(evento.data), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text(evento.texto),
              ]),
            ),
          ),
        ]),
      );
}

/// [REQ-06] Comprovante digital de recebimento ou de entrega
void abrirComprovante(BuildContext context, Encomenda e, {required bool entrega}) {
  final perfil = StoreScope.ler(context).perfil;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.inventory_2_outlined, color: Cores.primaria),
        const SizedBox(width: 8),
        Expanded(child: Text('Comprovante de ${entrega ? 'entrega' : 'recebimento'}')),
      ]),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Residencial Jardim das Flores · CNPJ 12.345.678/0001-95', style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          const Divider(height: 24),
          LinhaInfo('Encomenda', e.codigo),
          LinhaInfo('Destinatário', '${perfil.nome} · ${perfil.unidade}'),
          LinhaInfo('Remetente', e.remetente),
          LinhaInfo('Descrição', e.descricao + (e.fragil ? ' (frágil)' : '') + (e.grande ? ' (grande porte)' : '')),
          if (!entrega) ...[
            LinhaInfo('Recebida em', dataHora(e.recebidaEm)),
            LinhaInfo('Recebida por', e.recebidaPor),
          ] else ...[
            LinhaInfo('Entregue em', dataHora(e.entregueEm!)),
            LinhaInfo('Retirada por', e.retiradoPor ?? '—'),
            const LinhaInfo('Validação', 'Código conferido ✔'),
          ],
          const SizedBox(height: 10),
          Text('Documento gerado em ${dataHora(DateTime.now())}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        ]),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
    ),
  );
}

/// [REQ-13] Avaliação da portaria e da logística
void abrirAvaliacao(BuildContext context, {Encomenda? encomenda, int notaInicial = 0}) {
  var portaria = notaInicial, logistica = notaInicial;
  final comentario = TextEditingController();
  String? erro;
  const rotulos = ['', 'Ruim', 'Regular', 'Bom', 'Muito bom', 'Excelente'];

  Widget estrelas(int nota, ValueChanged<int> aoMudar) => Row(children: [
        for (var n = 1; n <= 5; n++)
          IconButton(
            tooltip: '$n de 5 estrelas',
            visualDensity: VisualDensity.compact,
            onPressed: () => aoMudar(n),
            icon: Icon(Icons.star_rounded, size: 36, color: n <= nota ? Cores.estrela : const Color(0xFFD6D6D6)),
          ),
        const SizedBox(width: 6),
        Text(rotulos[nota], style: const TextStyle(fontWeight: FontWeight.w700)),
      ]);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Avaliar serviço', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (encomenda != null) Text('Retirada da ${encomenda.codigo} · ${encomenda.remetente}'),
          const SizedBox(height: 14),
          const Text('Atendimento da portaria', style: TextStyle(fontWeight: FontWeight.w700)),
          estrelas(portaria, (n) => setState(() {
                portaria = n;
                erro = null;
              })),
          const Text('Agilidade e cuidado com o pacote', style: TextStyle(fontWeight: FontWeight.w700)),
          estrelas(logistica, (n) => setState(() {
                logistica = n;
                erro = null;
              })),
          const SizedBox(height: 8),
          TextField(controller: comentario, maxLines: 3, decoration: const InputDecoration(labelText: 'Quer contar mais?', hintText: 'Elogio, sugestão ou problema')),
          if (erro != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(erro!, style: const TextStyle(color: Cores.erro, fontWeight: FontWeight.w600))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Agora não'))),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (portaria == 0 || logistica == 0) return setState(() => erro = 'Toque nas estrelas para dar nota aos dois itens.');
                  StoreScope.ler(context).avaliar(encomendaId: encomenda?.id, portaria: portaria, logistica: logistica, comentario: comentario.text);
                  Navigator.pop(ctx);
                  avisar(context, 'Obrigado pela avaliação!');
                },
                child: const Text('Enviar'),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}

/// Espaço da foto enquanto ela carrega (ou quando não há foto)
class _SemFoto extends StatelessWidget {
  const _SemFoto(this.e);
  final Encomenda e;

  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        decoration: BoxDecoration(color: (e.grande ? Cores.info : Cores.primaria).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(e.grande ? Icons.local_shipping_outlined : Icons.inventory_2_outlined, size: 48, color: e.grande ? Cores.info : Cores.primaria),
          const SizedBox(height: 6),
          Text('Foto do pacote tirada pela portaria', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        ]),
      );
}

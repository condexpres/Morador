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
            if (e.rastreio.isNotEmpty) LinhaInfo('Rastreio', e.rastreio),
            LinhaInfo('Recebida por', e.recebidaPor),
            if (!e.naPortaria) LinhaInfo('Retirada por', e.retiradoPor ?? '—'),
            const SizedBox(height: 16),
            Text('Linha do tempo', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (var i = 0; i < e.eventos.length; i++) _ItemLinhaDoTempo(e.eventos[i], ultimo: i == e.eventos.length - 1),
            const SizedBox(height: 16),
            Text('Registro oficial', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _RegistroOficial(e.codigo),
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
          if (e.rastreio.isNotEmpty) LinhaInfo('Rastreio', e.rastreio),
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

/// [Prova] Registro oficial conferido no servidor: eventos que não podem ser
/// alterados, encadeados por hash. Mostra se a corrente está íntegra.
class _RegistroOficial extends StatefulWidget {
  const _RegistroOficial(this.codigo);
  final String codigo;

  @override
  State<_RegistroOficial> createState() => _RegistroOficialState();
}

class _RegistroOficialState extends State<_RegistroOficial> {
  late final Future<Map<String, dynamic>?> _registro = StoreScope.ler(context).verificarRegistro(widget.codigo);

  static const _tipos = {'recebida': 'Recebida', 'corrigida': 'Corrigida', 'entregue': 'Entregue', 'cancelada': 'Cancelada', 'reaberta': 'Reaberta'};
  static String _hashCurto(Object? h) => '$h'.padRight(16).substring(0, 16).replaceAllMapped(RegExp(r'(.{4})(?=.)'), (m) => '${m[1]} ');

  @override
  Widget build(BuildContext context) {
    final suave = Theme.of(context).colorScheme.onSurfaceVariant;
    return FutureBuilder<Map<String, dynamic>?>(
      future: _registro,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return Text('Conferindo o registro no servidor…', style: TextStyle(color: suave, fontSize: 13));
        }
        final r = s.data;
        if (r == null || r['encontrado'] != true) {
          return Text(r == null ? 'Não foi possível conferir o registro agora.' : 'Registro anterior à autenticação eletrônica.',
              style: TextStyle(color: suave, fontSize: 13));
        }
        final integro = r['integro'] == true;
        final cor = integro ? Cores.ok : Cores.erro;
        final eventos = [for (final e in (r['eventos'] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(integro ? Icons.verified_user_outlined : Icons.error_outline, color: cor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(integro ? 'Registro íntegro' : 'Registro com divergência', style: TextStyle(fontWeight: FontWeight.w800, color: cor)),
                  Text(integro ? 'Nenhum evento foi alterado desde que foi gravado.' : 'A corrente de autenticação não confere: avise a administração.',
                      style: const TextStyle(fontSize: 13)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          for (final ev in eventos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_tipos[ev['tipo']] ?? ev['tipo']} · ${dataHora(DateTime.parse('${ev['em']}').toLocal())}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text([
                  'por ${ev['porteiro'] ?? ev['por']}',
                  if (ev['retirado_por'] != null) 'retirada por ${ev['retirado_por']}',
                ].join(' · '), style: TextStyle(color: suave, fontSize: 13)),
                Text('Autenticação: ${_hashCurto(ev['hash'])}', style: TextStyle(color: suave, fontSize: 12, fontFamily: 'monospace')),
              ]),
            ),
        ]);
      },
    );
  }
}

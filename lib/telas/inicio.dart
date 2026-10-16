import 'package:flutter/material.dart';

import '../dados/modelos.dart';
import '../dados/store.dart';
import '../tema.dart';
import '../util/formatos.dart';
import '../widgets/componentes.dart';
import 'detalhes.dart';

/// Início: encomendas na portaria em destaque + lista com busca e filtros.
class TelaInicio extends StatefulWidget {
  const TelaInicio({super.key, required this.aoAvisarCompra});

  final VoidCallback aoAvisarCompra;

  @override
  State<TelaInicio> createState() => _TelaInicioState();
}

class _TelaInicioState extends State<TelaInicio> {
  String _filtro = 'todas';
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final conta = store.conta!;
    final tema = Theme.of(context);
    final pendentes = conta.naPortaria..sort((a, b) => (b.grande ? 1 : 0) - (a.grande ? 1 : 0));
    final paraAvaliar = conta.encomendas.where((e) => !e.naPortaria && !store.jaAvaliou(e)).firstOrNull;
    final termo = _busca.trim().toLowerCase();
    final lista = conta.encomendas.where((e) {
      if (_filtro == 'portaria' && !e.naPortaria) return false;
      if (_filtro == 'entregues' && e.naPortaria) return false;
      return '${e.codigo} ${e.remetente} ${e.descricao}'.toLowerCase().contains(termo);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Text('Olá, ${primeiroNome(conta.perfil.nome)}!', style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          pendentes.isEmpty ? 'Nenhuma encomenda esperando por você agora.' : 'Você tem ${plural(pendentes.length, 'encomenda', 'encomendas')} na portaria.',
          style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        for (final e in pendentes) CartaoDestaque(key: ValueKey(e.id), encomenda: e),
        if (paraAvaliar != null) _CartaoAvaliar(encomenda: paraAvaliar),
        const TituloSecao('Suas encomendas'),
        TextField(
          onChanged: (v) => setState(() => _busca = v),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar por loja, descrição ou código'),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final (id, nome) in [('todas', 'Todas'), ('portaria', 'Na portaria'), ('entregues', 'Entregues')])
            ChoiceChip(
              label: Text(nome),
              selected: _filtro == id,
              onSelected: (_) => setState(() => _filtro = id),
              selectedColor: Cores.primaria,
              labelStyle: TextStyle(color: _filtro == id ? Colors.white : null, fontWeight: FontWeight.w600),
              showCheckmark: false,
            ),
        ]),
        const SizedBox(height: 12),
        if (lista.isEmpty)
          termo.isNotEmpty || _filtro != 'todas'
              ? const EstadoVazio(icone: Icons.search_off, titulo: 'Nada encontrado', texto: 'Tente outro termo ou limpe o filtro.')
              : EstadoVazio(
                  icone: Icons.inventory_2_outlined,
                  titulo: 'Nenhuma encomenda ainda',
                  texto: 'Quando algo chegar na portaria, você vê aqui e recebe um aviso.',
                  acao: OutlinedButton.icon(onPressed: widget.aoAvisarCompra, icon: const Icon(Icons.assignment_outlined), label: const Text('Avisar uma compra')),
                )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < lista.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _LinhaEncomenda(encomenda: lista[i]),
              ],
            ]),
          ),
      ],
    );
  }
}

/// Cartão vermelho (ou azul, se for grande porte) da encomenda na portaria
class CartaoDestaque extends StatelessWidget {
  const CartaoDestaque({super.key, required this.encomenda});

  final Encomenda encomenda;

  @override
  Widget build(BuildContext context) {
    final e = encomenda;
    final cores = e.grande ? const [Color(0xFF1E40AF), Color(0xFF172554)] : const [Cores.primaria, Cores.primariaEscura];
    // Entra deslizando e crescendo (animação de chegada)
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (_, t, filho) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: filho),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: cores, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: cores.first.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(e.grande ? Icons.local_shipping_outlined : Icons.inventory_2_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(e.grande ? 'Grande porte: retire logo' : 'Chegou! Está na portaria',
                        overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Text(tempoRelativo(e.recebidaEm), style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: e.remetente, style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: ' · ${e.descricao}', style: const TextStyle(fontWeight: FontWeight.w400, color: Colors.white70)),
            ]),
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 18),
          StepperRastreio(e, sobreFundoColorido: true),
          const SizedBox(height: 18),
          const Text('Código de retirada', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CodigoCaixas(e.token, sobreFundoColorido: true),
              FilledButton(
                onPressed: () => abrirDetalhes(context, e),
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: cores.first, minimumSize: const Size(0, 46)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Ver detalhes'), Icon(Icons.chevron_right)]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(children: [
            Icon(Icons.shield_outlined, color: Colors.white70, size: 16),
            SizedBox(width: 6),
            Expanded(child: Text('Informe o código só ao porteiro. Nunca compartilhe com estranhos.', style: TextStyle(color: Colors.white70, fontSize: 12.5))),
          ]),
        ]),
      ),
    );
  }
}

class _LinhaEncomenda extends StatelessWidget {
  const _LinhaEncomenda({required this.encomenda});

  final Encomenda encomenda;

  @override
  Widget build(BuildContext context) {
    final e = encomenda;
    final suave = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => abrirDetalhes(context, e),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          FotoPacote(encomenda: e),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.remetente, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text('${e.descricao} · ${e.codigo}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: suave, fontSize: 13)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [StatusEncomendaTag(e), ...selos(e)]),
            ]),
          ),
          Text(e.naPortaria ? tempoRelativo(e.recebidaEm) : diaHora(e.entregueEm!), style: TextStyle(color: suave, fontSize: 12)),
          Icon(Icons.chevron_right, color: suave),
        ]),
      ),
    );
  }
}

/// "Como foi a retirada?" – pedido de avaliação após a entrega
class _CartaoAvaliar extends StatelessWidget {
  const _CartaoAvaliar({required this.encomenda});

  final Encomenda encomenda;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Como foi a retirada da ${encomenda.codigo}?', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('Sua nota ajuda a melhorar a portaria.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(children: [
              for (var n = 1; n <= 5; n++)
                IconButton(
                  tooltip: '$n de 5 estrelas',
                  onPressed: () => abrirAvaliacao(context, encomenda: encomenda, notaInicial: n),
                  icon: const Icon(Icons.star_rounded, size: 34, color: Color(0xFFD6D6D6)),
                ),
            ]),
          ]),
        ),
      );
}

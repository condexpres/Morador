import 'dart:async';

import 'package:flutter/material.dart';

import '../dados/store.dart';
import '../tema.dart';
import '../util/formatos.dart';
import '../widgets/aviso_chegada.dart';
import '../widgets/componentes.dart';
import '../widgets/marca.dart';
import 'avisar_compra.dart';
import 'comunidade.dart';
import 'detalhes.dart';
import 'inicio.dart';
import 'perfil.dart';

/// Estrutura do app depois do login: topo + 4 abas na barra inferior.
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _aba = 0;
  AppStore? _store;
  StreamSubscription<String>? _erros;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = StoreScope.ler(context);
    if (_store != store) {
      _store?.removeListener(_verificarChegadas);
      _store = store..addListener(_verificarChegadas);
      // Falha ao gravar (ex.: sem internet): avisa na barra de baixo
      _erros?.cancel();
      _erros = store.erros.listen((msg) {
        if (mounted) avisar(context, msg, erro: true);
      });
      // Ao abrir o app, mostra a animação do que chegou enquanto a pessoa estava fora
      WidgetsBinding.instance.addPostFrameCallback((_) => _verificarChegadas());
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_verificarChegadas);
    _erros?.cancel();
    super.dispose();
  }

  void _verificarChegadas() {
    if (!mounted || _store?.conta == null) return;
    for (final e in _store!.chegadasParaCelebrar().take(1)) {
      mostrarChegada(context, e, aoVer: () {
        setState(() => _aba = 0);
        abrirDetalhes(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final conta = store.conta!;
    final naPortaria = conta.naPortaria.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          const SimboloCondexpress(tamanho: 34),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sua unidade', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text(conta.perfil.unidade, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: 'Notificações',
            onPressed: () => _abrirNotificacoes(context),
            icon: Badge(
              isLabelVisible: conta.naoLidas > 0,
              label: Text('${conta.naoLidas}'),
              backgroundColor: Cores.destaque,
              child: const Icon(Icons.notifications_none),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _aba = 3),
              child: Avatar(nome: conta.perfil.nome, foto: conta.perfil.foto, tamanho: 38),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _aba,
        children: [
          TelaInicio(aoAvisarCompra: () => setState(() => _aba = 1)),
          const TelaAvisarCompra(),
          const TelaComunidade(),
          const TelaPerfil(),
        ],
      ),
      // [H6] Ícone + rótulo + contador em cada aba
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: [
          NavigationDestination(
            icon: Badge(isLabelVisible: naPortaria > 0, label: Text('$naPortaria'), backgroundColor: Cores.destaque, child: const Icon(Icons.home_outlined)),
            selectedIcon: Badge(isLabelVisible: naPortaria > 0, label: Text('$naPortaria'), backgroundColor: Cores.destaque, child: const Icon(Icons.home)),
            label: 'Início',
          ),
          const NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Avisar compra'),
          const NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Comunidade'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  /// [REQ-07] Central de notificações
  void _abrirNotificacoes(BuildContext context) {
    final store = StoreScope.ler(context);
    final lista = store.conta!.notificacoes.take(20).toList();
    final naoLidas = {for (final n in lista) if (!n.lida) n.id};
    store.marcarNotificacoesLidas();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, rolagem) => ListView(
          controller: rolagem,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('Notificações', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (lista.isEmpty)
              const EstadoVazio(icone: Icons.notifications_none, titulo: 'Nada por aqui', texto: 'Avisaremos assim que chegar uma encomenda.')
            else
              for (final n in lista)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: (n.tipo == 'urgente' ? Cores.info : n.tipo == 'entregue' ? Cores.ok : Cores.primaria).withValues(alpha: 0.12),
                    child: Icon(
                      n.tipo == 'urgente' ? Icons.local_shipping_outlined : n.tipo == 'entregue' ? Icons.check : Icons.inventory_2_outlined,
                      color: n.tipo == 'urgente' ? Cores.info : n.tipo == 'entregue' ? Cores.ok : Cores.primaria,
                    ),
                  ),
                  title: Text(n.texto, style: TextStyle(fontWeight: naoLidas.contains(n.id) ? FontWeight.w700 : FontWeight.w400)),
                  subtitle: Text(tempoRelativo(n.data)),
                  trailing: naoLidas.contains(n.id) ? const CircleAvatar(radius: 5, backgroundColor: Cores.primaria) : null,
                  onTap: n.encomendaId == null
                      ? null
                      : () {
                          final e = store.encomendaPorId(n.encomendaId!);
                          if (e == null) return;
                          Navigator.pop(ctx);
                          abrirDetalhes(context, e);
                        },
                ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../dados/modelos.dart';
import '../dados/store.dart';
import '../tema.dart';
import '../util/formatos.dart';
import '../widgets/componentes.dart';

/// [REQ-09] Comunidade: fórum interno entre moradores e administração.
class TelaComunidade extends StatefulWidget {
  const TelaComunidade({super.key});

  @override
  State<TelaComunidade> createState() => _TelaComunidadeState();
}

class _TelaComunidadeState extends State<TelaComunidade> {
  final _texto = TextEditingController();

  void _publicar() {
    if (_texto.text.trim().isEmpty) return;
    StoreScope.ler(context).publicar(_texto.text);
    _texto.clear();
    FocusScope.of(context).unfocus();
    avisar(context, 'Mensagem publicada.');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final perfil = store.perfil;
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Text('Comunidade', style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Converse com vizinhos e envie sugestões à administração.', style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Avatar(nome: perfil.nome, foto: perfil.foto),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  TextField(
                    controller: _texto,
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Compartilhe uma sugestão, dúvida ou aviso…'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _publicar, style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), child: const Text('Publicar')),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        if (store.forum.isEmpty)
          const EstadoVazio(icone: Icons.chat_bubble_outline, titulo: 'Nenhuma conversa ainda', texto: 'Seja o primeiro a publicar!')
        else
          for (final p in store.forum) _CartaoPost(key: ValueKey(p.id), post: p),
      ],
    );
  }
}

class _CartaoPost extends StatefulWidget {
  const _CartaoPost({super.key, required this.post});

  final Post post;

  @override
  State<_CartaoPost> createState() => _CartaoPostState();
}

class _CartaoPostState extends State<_CartaoPost> {
  final _resposta = TextEditingController();

  void _responder() {
    if (_resposta.text.trim().isEmpty) return;
    StoreScope.ler(context).responder(widget.post, _resposta.text);
    _resposta.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final tema = Theme.of(context);
    final suave = tema.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(nome: p.autor, foto: p.foto),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.autor, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Row(children: [
                    if (p.admin) const Etiqueta('Administração', cor: Cores.info) else Text(p.rotulo, style: TextStyle(color: suave, fontSize: 13)),
                    Text(' · ${tempoRelativo(p.data)}', style: TextStyle(color: suave, fontSize: 13)),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Text(p.texto),
            if (p.respostas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: tema.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  for (final r in p.respostas)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Avatar(nome: r.autor, foto: r.foto, tamanho: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text.rich(TextSpan(children: [
                              TextSpan(text: r.autor, style: const TextStyle(fontWeight: FontWeight.w700)),
                              TextSpan(text: ' · ${tempoRelativo(r.data)}', style: TextStyle(color: suave, fontSize: 12)),
                            ])),
                            Text(r.texto),
                          ]),
                        ),
                      ]),
                    ),
                ]),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _resposta,
                  onSubmitted: (_) => _responder(),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Escreva uma resposta…', isDense: true),
                ),
              ),
              IconButton(tooltip: 'Enviar resposta', onPressed: _responder, icon: const Icon(Icons.send, color: Cores.primaria)),
            ]),
          ]),
        ),
      ),
    );
  }
}

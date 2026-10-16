import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../dados/modelos.dart';
import '../dados/store.dart';
import '../tema.dart';
import '../widgets/componentes.dart';
import 'detalhes.dart';
import 'dialogos.dart';

enum _AcaoFoto { galeria, camera, remover }

/// Perfil: foto, preferência de entrega, pessoas autorizadas, aparência e conta.
class TelaPerfil extends StatelessWidget {
  const TelaPerfil({super.key});

  static const _icones = {Diretriz.maos: Icons.person_outline, Diretriz.unidade: Icons.groups_outlined, Diretriz.porta: Icons.door_front_door_outlined};

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final perfil = store.perfil;
    final tema = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // ---------- Cabeçalho com foto ----------
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                Avatar(nome: perfil.nome, foto: perfil.foto, tamanho: 72),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Material(
                    color: Cores.primaria,
                    shape: CircleBorder(side: BorderSide(color: tema.colorScheme.surface, width: 3)),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _alterarFoto(context),
                      child: const Padding(padding: EdgeInsets.all(7), child: Icon(Icons.photo_camera_outlined, size: 16, color: Colors.white)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(perfil.nome, style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text(perfil.unidade, style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
                  Text(perfil.email, style: TextStyle(color: tema.colorScheme.onSurfaceVariant, fontSize: 13)),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                    onPressed: () => _alterarFoto(context),
                    child: Text(perfil.foto == null ? 'Adicionar foto' : 'Alterar foto'),
                  ),
                ]),
              ),
            ]),
          ),
        ),

        // ---------- [REQ-12] Preferência de entrega ----------
        const TituloSecao('Como prefere receber?'),
        for (final d in Diretriz.values)
          OpcaoCard(
            icone: _icones[d]!,
            titulo: d.titulo,
            descricao: d.descricao,
            selecionada: perfil.diretriz == d,
            aoTocar: () {
              store.definirDiretriz(d);
              avisar(context, 'Preferência salva: ${d.titulo}.');
            },
          ),

        // ---------- Pessoas autorizadas ----------
        const TituloSecao('Quem pode retirar por você'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Familiares cadastrados aqui aparecem para o porteiro na hora da entrega. Eles retiram com o seu código.',
                  style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
              if (perfil.diretriz == Diretriz.maos) ...[
                const SizedBox(height: 12),
                const Faixa(
                  icone: Icons.warning_amber_rounded,
                  cor: Cores.erro,
                  texto: 'Sua preferência é "Somente em mãos", então a portaria não entrega para estas pessoas.',
                ),
              ],
              for (final a in perfil.autorizados)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(nome: a.nome),
                  title: Text(a.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(a.parentesco),
                  trailing: IconButton(
                    tooltip: 'Remover ${a.nome}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      final desfazer = store.removerAutorizado(a);
                      avisar(context, '${a.nome} foi removido(a).', rotulo: 'Desfazer', acao: desfazer);
                    },
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: () => _adicionarAutorizado(context), icon: const Icon(Icons.person_add_alt), label: const Text('Adicionar pessoa')),
            ]),
          ),
        ),

        // ---------- Aparência ----------
        const TituloSecao('Aparência'),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Automático')),
            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Claro')),
            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Escuro')),
          ],
          selected: {store.modoTema},
          onSelectionChanged: (s) => store.definirTema(s.first),
        ),

        // ---------- Conta ----------
        const TituloSecao('Mais opções'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            _Opcao(icone: Icons.key_outlined, titulo: 'Alterar senha', subtitulo: 'Troque a senha de acesso ao app', aoTocar: () => abrirAlterarSenha(context)),
            const Divider(height: 1),
            _Opcao(
              icone: Icons.link,
              titulo: 'Conta Google',
              subtitulo: perfil.google == null ? 'Vincule para entrar sem digitar senha' : 'Vinculada a ${perfil.google} · toque para desvincular',
              aoTocar: () => perfil.google == null ? abrirGoogle(context, entrar: false) : _desvincularGoogle(context),
            ),
            const Divider(height: 1),
            _Opcao(icone: Icons.star_outline, titulo: 'Avaliar serviço', subtitulo: 'Portaria e logística', aoTocar: () => abrirAvaliacao(context)),
            const Divider(height: 1),
            _Opcao(icone: Icons.logout, titulo: 'Sair', subtitulo: 'Encerrar sessão neste aparelho', aoTocar: store.sair),
          ]),
        ),

      ],
    );
  }

  Future<void> _alterarFoto(BuildContext context) async {
    final store = StoreScope.ler(context);
    final acao = await showModalBottomSheet<_AcaoFoto>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Escolher da galeria'), onTap: () => Navigator.pop(ctx, _AcaoFoto.galeria)),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Tirar foto'), onTap: () => Navigator.pop(ctx, _AcaoFoto.camera)),
          if (store.perfil.foto != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Cores.erro),
              title: const Text('Remover foto', style: TextStyle(color: Cores.erro)),
              onTap: () => Navigator.pop(ctx, _AcaoFoto.remover),
            ),
        ]),
      ),
    );
    if (acao == null || !context.mounted) return;
    if (acao == _AcaoFoto.remover) {
      final antiga = store.perfil.foto;
      store.voltarFoto(null);
      avisar(context, 'Foto removida.', rotulo: 'Desfazer', acao: () => store.voltarFoto(antiga));
      return;
    }
    try {
      final arquivo = await ImagePicker().pickImage(
        source: acao == _AcaoFoto.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (arquivo == null) return;
      if (context.mounted) avisar(context, 'Enviando foto…');
      final erro = await store.definirFoto(await arquivo.readAsBytes());
      if (context.mounted) avisar(context, erro ?? 'Foto do perfil atualizada.', erro: erro != null);
    } catch (_) {
      if (context.mounted) avisar(context, 'Não foi possível abrir a câmera ou a galeria.', erro: true);
    }
  }

  void _adicionarAutorizado(BuildContext context) {
    final nome = TextEditingController();
    var parentesco = parentescos.first;
    String? erro;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Adicionar pessoa'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nome,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Nome', hintText: 'Ex.: Maria Souza', errorText: erro),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: parentesco,
              decoration: const InputDecoration(labelText: 'Parentesco'),
              items: [for (final p in parentescos) DropdownMenuItem(value: p, child: Text(p))],
              onChanged: (v) => parentesco = v ?? parentesco,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (nome.text.trim().split(' ').where((p) => p.isNotEmpty).length < 2) {
                  return setState(() => erro = 'Informe nome e sobrenome.');
                }
                StoreScope.ler(context).adicionarAutorizado(nome.text, parentesco);
                Navigator.pop(ctx);
                avisar(context, '${nome.text.trim().split(' ').first} pode retirar suas encomendas com o seu código.');
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  void _desvincularGoogle(BuildContext context) {
    final store = StoreScope.ler(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular Google?'),
        content: Text('Você deixará de entrar com ${store.perfil.google}. Continue usando seu e-mail e sua senha.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cores.erro),
            onPressed: () async {
              Navigator.pop(ctx);
              final erro = await store.desvincularGoogle();
              if (context.mounted) avisar(context, erro ?? 'Google desvinculado.', erro: erro != null);
            },
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({required this.icone, required this.titulo, required this.subtitulo, required this.aoTocar});

  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: aoTocar,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: Cores.primaria.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
          child: Icon(icone, color: Cores.primaria),
        ),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
      );
}

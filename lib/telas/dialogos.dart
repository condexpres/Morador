import 'package:flutter/material.dart';

import '../dados/store.dart';
import '../tema.dart';
import '../widgets/componentes.dart';

/// Campo de senha com botão de mostrar/ocultar.
class CampoSenha extends StatefulWidget {
  const CampoSenha({super.key, required this.controle, required this.rotulo, this.dica, this.aoMudar, this.aoEnviar, this.autofocus = false});

  final TextEditingController controle;
  final String rotulo;
  final String? dica;
  final ValueChanged<String>? aoMudar;
  final VoidCallback? aoEnviar;
  final bool autofocus;

  @override
  State<CampoSenha> createState() => _CampoSenhaState();
}

class _CampoSenhaState extends State<CampoSenha> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controle,
        obscureText: _oculta,
        autofocus: widget.autofocus,
        onChanged: widget.aoMudar,
        onSubmitted: widget.aoEnviar == null ? null : (_) => widget.aoEnviar!(),
        autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(
          labelText: widget.rotulo,
          hintText: widget.dica,
          suffixIcon: IconButton(
            tooltip: _oculta ? 'Mostrar senha' : 'Ocultar senha',
            icon: Icon(_oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _oculta = !_oculta),
          ),
        ),
      );
}

/// [H1] Medidor de força da senha enquanto a pessoa digita
class MedidorSenha extends StatelessWidget {
  const MedidorSenha(this.senha, {super.key});

  final String senha;

  @override
  Widget build(BuildContext context) {
    var pontos = 0;
    if (senha.length >= 8) pontos++;
    if (RegExp(r'[a-zA-Z]').hasMatch(senha) && RegExp(r'\d').hasMatch(senha)) pontos++;
    if (senha.length >= 12 || RegExp(r'[^a-zA-Z0-9]').hasMatch(senha)) pontos++;
    final cor = pontos <= 1 ? Cores.erro : pontos == 2 ? Cores.alerta : Cores.ok;
    final texto = senha.isEmpty ? 'Mínimo 8 caracteres, com letras e números' : ['Muito fraca', 'Fraca', 'Boa', 'Forte'][pontos];
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                decoration: BoxDecoration(
                  color: senha.isNotEmpty && i < (pontos == 0 ? 1 : pontos) ? cor : Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text(texto, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

/// Janela para alterar a senha (Perfil → Alterar senha)
Future<void> abrirAlterarSenha(BuildContext context) {
  final atual = TextEditingController();
  final nova = TextEditingController();
  final confirma = TextEditingController();
  String? erro;
  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Alterar senha'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CampoSenha(controle: atual, rotulo: 'Senha atual', dica: 'A senha que você usa hoje', autofocus: true),
            const SizedBox(height: 12),
            CampoSenha(controle: nova, rotulo: 'Nova senha', dica: 'Ex.: casa2025azul', aoMudar: (_) => setState(() => erro = null)),
            MedidorSenha(nova.text),
            const SizedBox(height: 8),
            CampoSenha(controle: confirma, rotulo: 'Repita a nova senha'),
            if (erro != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(erro!, style: const TextStyle(color: Cores.erro, fontWeight: FontWeight.w600))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final msg = await StoreScope.ler(context).alterarSenha(atual.text, nova.text, confirma.text);
              if (msg != null) return setState(() => erro = msg);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) avisar(context, 'Senha alterada.');
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}

/// Conta Google: abre a tela oficial do Google (pelo Supabase).
/// [entrar] = true: fazer login; false: vincular à conta logada.
/// No celular o Google abre no navegador e devolve o morador ao app.
Future<void> abrirGoogle(BuildContext context, {required bool entrar}) async {
  final store = StoreScope.ler(context);
  final erro = entrar ? await store.entrarComGoogle() : await store.vincularGoogle();
  if (erro != null && context.mounted) avisar(context, erro, erro: true);
}

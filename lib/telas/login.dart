import 'package:flutter/material.dart';

import '../dados/store.dart';
import '../tema.dart';
import '../widgets/marca.dart';
import 'dialogos.dart';

/// [REQ-03] Login do morador: logo em destaque e só o essencial.
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  String? _erro;

  Future<void> _entrar() async {
    // [H9] Erro claro, junto do formulário, dizendo o que fazer
    setState(() => _erro = null);
    final erro = await StoreScope.ler(context).entrar(_email.text, _senha.text);
    if (mounted) setState(() => _erro = erro);
  }

  Future<void> _google() async {
    final erro = await StoreScope.ler(context).entrarComGoogle();
    if (erro != null && mounted) setState(() => _erro = erro);
  }

  // [H10] Ajuda: explica o que fazer quando esquece a senha
  void _esqueci() => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.lock_reset, color: Cores.primaria, size: 32),
          title: const Text('Esqueceu a senha?'),
          content: const Text('Peça à administração do condomínio uma nova senha provisória. No próximo acesso você cria uma senha nova.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendi'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final store = StoreScope.of(context);
    final escuro = tema.brightness == Brightness.dark;
    final topo = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: tema.colorScheme.surface,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---------- Área da marca ----------
          SizedBox(
            height: 330 + topo,
            child: Stack(children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: escuro
                          ? [const Color(0xFF0D2726), tema.colorScheme.surface]
                          : [const Color(0xFFDDF1F0), tema.colorScheme.surface],
                    ),
                  ),
                ),
              ),
              // Formas decorativas com as cores da logo
              _Bolha(esquerda: -60, topo: topo - 40, tamanho: 190, cor: Cores.maoClara.withValues(alpha: 0.28)),
              _Bolha(direita: -40, topo: topo + 30, tamanho: 120, cor: Cores.amarelo.withValues(alpha: 0.30)),
              _Bolha(direita: 40, topo: topo + 250, tamanho: 26, cor: Cores.destaque.withValues(alpha: 0.35)),
              _Bolha(esquerda: 36, topo: topo + 230, tamanho: 14, cor: Cores.primaria.withValues(alpha: 0.35)),
              Positioned(
                top: topo + 4,
                right: 4,
                child: IconButton(
                  tooltip: escuro ? 'Modo claro' : 'Modo escuro',
                  icon: Icon(escuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                  onPressed: () => store.definirTema(escuro ? ThemeMode.light : ThemeMode.dark),
                ),
              ),
              Positioned.fill(
                top: topo + 30,
                child: const Center(child: LogoCondexpress(largura: 300)),
              ),
            ]),
          ),

          // ---------- Formulário ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Entrar', style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'E-mail', hintText: 'voce@email.com', prefixIcon: Icon(Icons.mail_outline)),
                ),
                const SizedBox(height: 12),
                CampoSenha(controle: _senha, rotulo: 'Senha', dica: 'Sua senha', aoEnviar: _entrar),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _esqueci, child: const Text('Esqueci minha senha')),
                ),
                if ((_erro ?? store.avisoLogin) != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Cores.erro, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text((_erro ?? store.avisoLogin)!, style: const TextStyle(color: Cores.erro, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                // [H1] Mostra que está conectando
                FilledButton(
                  onPressed: store.entrando ? null : _entrar,
                  child: Text(store.entrando ? 'Entrando…' : 'Entrar'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('ou')),
                    Expanded(child: Divider()),
                  ]),
                ),
                OutlinedButton.icon(
                  onPressed: store.entrando ? null : _google,
                  icon: const Icon(Icons.link),
                  label: const Text('Continuar com Google'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bolha extends StatelessWidget {
  const _Bolha({this.esquerda, this.direita, required this.topo, required this.tamanho, required this.cor});

  final double? esquerda;
  final double? direita;
  final double topo;
  final double tamanho;
  final Color cor;

  @override
  Widget build(BuildContext context) => Positioned(
        left: esquerda,
        right: direita,
        top: topo,
        child: ExcludeSemantics(
          child: Container(width: tamanho, height: tamanho, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        ),
      );
}

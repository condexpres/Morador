import 'package:flutter/material.dart';

/// Logo completa do Condexpress (símbolo + nome + slogan).
/// Usa a versão clara ou escura conforme o tema.
class LogoCondexpress extends StatelessWidget {
  const LogoCondexpress({super.key, this.largura = 260});

  final double largura;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      escuro ? 'assets/marca/logo_escuro.png' : 'assets/marca/logo.png',
      width: largura,
      semanticLabel: 'Condexpress – envio de mercadorias para condomínio',
    );
  }
}

/// Só o símbolo (caixa sobre a mão), para o topo das telas.
class SimboloCondexpress extends StatelessWidget {
  const SimboloCondexpress({super.key, this.tamanho = 34});

  final double tamanho;

  @override
  Widget build(BuildContext context) => Image.asset('assets/marca/simbolo.png', height: tamanho, semanticLabel: 'Condexpress');
}

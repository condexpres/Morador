import 'dart:convert';

import 'package:flutter/material.dart';

import '../dados/modelos.dart';
import '../dados/store.dart';
import '../tema.dart';
import '../util/formatos.dart';

/// [H4] Consistência: os mesmos componentes em todas as telas.

/// Imagem guardada no servidor ("sb:…" no Storage) ou embutida (versão antiga).
/// Enquanto o link temporário não chega, mostra [reserva].
class ImagemServidor extends StatelessWidget {
  const ImagemServidor({super.key, required this.foto, required this.construir, required this.reserva});

  final String? foto;
  final Widget Function(ImageProvider imagem) construir;
  final Widget reserva;

  @override
  Widget build(BuildContext context) {
    final ref = foto;
    if (ref == null || ref.isEmpty) return reserva;
    if (!ref.startsWith('sb:')) {
      try {
        return construir(MemoryImage(base64Decode(ref.contains(',') ? ref.split(',').last : ref)));
      } catch (_) {
        return reserva;
      }
    }
    final store = StoreScope.ler(context);
    final pronto = store.linkFotoPronto(ref);
    if (pronto != null) return construir(NetworkImage(pronto));
    return FutureBuilder<String?>(
      future: store.linkFoto(ref),
      builder: (context, s) => s.data == null ? reserva : construir(NetworkImage(s.data!)),
    );
  }
}

/// Avatar com a foto do perfil ou as iniciais.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.nome, this.foto, this.tamanho = 40});

  final String nome;
  final String? foto;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    CircleAvatar circulo(ImageProvider? imagem) => CircleAvatar(
          radius: tamanho / 2,
          backgroundColor: Cores.primaria.withValues(alpha: 0.12),
          foregroundImage: imagem,
          onForegroundImageError: imagem == null ? null : (_, _) {},
          child: Text(
            iniciais(nome),
            style: TextStyle(color: Cores.primaria, fontWeight: FontWeight.w800, fontSize: tamanho * 0.36),
          ),
        );
    return ImagemServidor(foto: foto, construir: circulo, reserva: circulo(null));
  }
}

/// Etiqueta colorida (status, frágil, grande porte…)
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, required this.cor, this.icone});

  final String texto;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icone != null) ...[Icon(icone, size: 13, color: cor), const SizedBox(width: 4)],
        Text(texto, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// "● Na portaria" (amarelo) ou "● Entregue" (verde)
class StatusEncomendaTag extends StatelessWidget {
  const StatusEncomendaTag(this.encomenda, {super.key, this.grande = false});

  final Encomenda encomenda;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final cor = encomenda.naPortaria ? Cores.alerta : Cores.ok;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(encomenda.naPortaria ? 'Na portaria' : 'Entregue',
          style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: grande ? 16 : 13)),
    ]);
  }
}

List<Widget> selos(Encomenda e) => [
      if (e.fragil) const Etiqueta('Frágil', cor: Cores.erro, icone: Icons.warning_amber_rounded),
      if (e.grande) const Etiqueta('Grande porte', cor: Cores.info, icone: Icons.local_shipping_outlined),
    ];

/// Rastreamento em etapas, no estilo de acompanhamento de pedido.
class StepperRastreio extends StatelessWidget {
  const StepperRastreio(this.encomenda, {super.key, this.sobreFundoColorido = false});

  final Encomenda encomenda;
  final bool sobreFundoColorido;

  @override
  Widget build(BuildContext context) {
    final passos = [
      ('Recebida', encomenda.recebidaEm),
      ('Morador avisado', encomenda.recebidaEm),
      ('Retirada', encomenda.entregueEm),
    ];
    final corFeito = sobreFundoColorido ? Colors.white : Cores.ok;
    final corPendente = sobreFundoColorido ? Colors.white38 : Theme.of(context).dividerColor;
    final corTexto = sobreFundoColorido ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final corSuave = sobreFundoColorido ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < passos.length; i++)
          Expanded(
            child: Column(children: [
              SizedBox(
                height: 18,
                child: Row(children: [
                  Expanded(child: i == 0 ? const SizedBox() : Container(height: 4, color: passos[i].$2 != null ? corFeito : corPendente)),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: passos[i].$2 != null ? corFeito : Colors.transparent,
                      border: Border.all(color: passos[i].$2 != null ? corFeito : corPendente, width: 3),
                    ),
                  ),
                  Expanded(
                    child: i == passos.length - 1
                        ? const SizedBox()
                        : Container(height: 4, color: passos[i + 1].$2 != null ? corFeito : corPendente),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              Text(passos[i].$1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: passos[i].$2 != null ? corTexto : corSuave,
                    fontWeight: passos[i].$2 != null ? FontWeight.w700 : FontWeight.w400,
                  )),
              Text(passos[i].$2 == null ? 'aguardando' : diaHora(passos[i].$2!), style: TextStyle(fontSize: 11, color: corSuave)),
            ]),
          ),
      ],
    );
  }
}

/// Código de retirada em caixinhas: 4 8 2 7
class CodigoCaixas extends StatelessWidget {
  const CodigoCaixas(this.codigo, {super.key, this.sobreFundoColorido = false});

  final String codigo;
  final bool sobreFundoColorido;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Semantics(
      label: 'Código de retirada ${codigo.split('').join(' ')}',
      child: ExcludeSemantics(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final d in codigo.split(''))
            Container(
              width: 46,
              height: 56,
              margin: const EdgeInsets.only(right: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sobreFundoColorido ? Colors.white.withValues(alpha: 0.16) : tema.colorScheme.surface,
                border: Border.all(color: sobreFundoColorido ? Colors.white38 : tema.dividerColor, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(d,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: sobreFundoColorido ? Colors.white : tema.colorScheme.onSurface,
                  )),
            ),
        ]),
      ),
    );
  }
}

/// Imagem do pacote (as encomendas de demonstração não têm foto)
class FotoPacote extends StatelessWidget {
  const FotoPacote({super.key, required this.encomenda, this.tamanho = 60});

  final Encomenda encomenda;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final cor = encomenda.grande ? Cores.info : Cores.primaria;
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(tamanho / 5)),
      child: Icon(encomenda.grande ? Icons.local_shipping_outlined : Icons.inventory_2_outlined, color: cor, size: tamanho * 0.45),
    );
  }
}

/// [H10] Estado vazio que explica o próximo passo
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({super.key, required this.icone, required this.titulo, required this.texto, this.acao});

  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        child: Column(children: [
          CircleAvatar(radius: 32, backgroundColor: Cores.primaria.withValues(alpha: 0.12), child: Icon(icone, color: Cores.primaria, size: 28)),
          const SizedBox(height: 14),
          Text(titulo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(texto, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (acao != null) ...[const SizedBox(height: 16), acao!],
        ]),
      ),
    );
  }
}

/// Opção em card grande, fácil de tocar (substitui o radio button pequeno)
class OpcaoCard extends StatelessWidget {
  const OpcaoCard({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.selecionada,
    required this.aoTocar,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final bool selecionada;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selecionada,
        button: true,
        child: InkWell(
          onTap: aoTocar,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selecionada ? Cores.primaria.withValues(alpha: 0.08) : null,
              border: Border.all(color: selecionada ? Cores.primaria : tema.dividerColor, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(icone, color: selecionada ? Cores.primaria : tema.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(descricao, style: TextStyle(fontSize: 13, color: tema.colorScheme.onSurfaceVariant)),
                ]),
              ),
              if (selecionada) const Icon(Icons.check_circle, color: Cores.primaria),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Título de seção ("Suas encomendas", "Mais opções"…)
class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Text(texto, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );
}

/// Faixa de aviso (informação ou alerta)
class Faixa extends StatelessWidget {
  const Faixa({super.key, required this.texto, this.icone = Icons.info_outline, this.cor = Cores.info});

  final String texto;
  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icone, color: cor, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: cor, fontSize: 13.5, fontWeight: FontWeight.w500))),
        ]),
      );
}

/// Linha "rótulo .......... valor"
class LinhaInfo extends StatelessWidget {
  const LinhaInfo(this.rotulo, this.valor, {super.key});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rotulo, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 16),
          Expanded(child: Text(valor, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

/// Mensagem rápida com ação opcional (ex.: "Desfazer")
void avisar(BuildContext context, String texto, {String? rotulo, VoidCallback? acao, bool erro = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: erro ? Cores.erro : null,
      action: rotulo == null ? null : SnackBarAction(label: rotulo.toUpperCase(), onPressed: acao ?? () {}),
    ));
}

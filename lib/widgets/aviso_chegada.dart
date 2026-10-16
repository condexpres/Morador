import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/modelos.dart';
import '../tema.dart';

/// [H1] Feedback forte quando a portaria registra uma encomenda:
/// o aviso desce do topo com confetes, a caixa pula e o celular vibra.
void mostrarChegada(BuildContext context, Encomenda encomenda, {required VoidCallback aoVer}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entrada;
  var removida = false;
  void remover() {
    if (removida) return;
    removida = true;
    entrada.remove();
  }

  entrada = OverlayEntry(
    builder: (_) => AvisoChegada(
      encomenda: encomenda,
      aoFechar: remover,
      aoVer: () {
        remover();
        aoVer();
      },
    ),
  );
  overlay.insert(entrada);
  HapticFeedback.mediumImpact();
}

class AvisoChegada extends StatefulWidget {
  const AvisoChegada({super.key, required this.encomenda, required this.aoFechar, required this.aoVer});

  final Encomenda encomenda;
  final VoidCallback aoFechar;
  final VoidCallback aoVer;

  @override
  State<AvisoChegada> createState() => _AvisoChegadaState();
}

class _AvisoChegadaState extends State<AvisoChegada> with TickerProviderStateMixin {
  late final _entrada = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final _pulo = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final _confete = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final _tempo = AnimationController(vsync: this, duration: const Duration(seconds: 7));
  Timer? _atrasoPulo;
  bool _semAnimacao = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeita "reduzir movimento" do aparelho
    _semAnimacao = MediaQuery.of(context).disableAnimations;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_semAnimacao) {
        _entrada.value = 1;
      } else {
        _entrada.forward();
        _confete.forward();
        _atrasoPulo = Timer(const Duration(milliseconds: 500), () {
          if (mounted) _pulo.repeat(count: 3);
        });
      }
      _tempo.forward().whenComplete(_fechar);
    });
  }

  Future<void> _fechar() async {
    if (!mounted) return;
    if (!_semAnimacao) await _entrada.reverse();
    widget.aoFechar();
  }

  @override
  void dispose() {
    _atrasoPulo?.cancel();
    _entrada.dispose();
    _pulo.dispose();
    _confete.dispose();
    _tempo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.encomenda;
    final cor = e.grande ? Cores.info : Cores.primaria;
    final tema = Theme.of(context);
    final deslize = Tween(begin: const Offset(0, -1.6), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entrada, curve: Curves.elasticOut, reverseCurve: Curves.easeIn));

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: SlideTransition(
          position: deslize,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Material(
              color: tema.colorScheme.surface,
              elevation: 12,
              shadowColor: Colors.black45,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                decoration: BoxDecoration(border: Border.all(color: cor, width: 2), borderRadius: BorderRadius.circular(20)),
                child: Stack(children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _confete,
                        builder: (_, _) => CustomPaint(painter: _Confetes(_confete.value, e.codigo.hashCode)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 8, 16),
                    child: Row(children: [
                      AnimatedBuilder(
                        animation: _pulo,
                        builder: (_, filho) {
                          final t = _pulo.value;
                          final altura = -12 * sin(t * pi);
                          final giro = 0.14 * sin(t * 2 * pi);
                          return Transform.translate(offset: Offset(0, altura), child: Transform.rotate(angle: giro, child: filho));
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(16)),
                          child: Icon(e.grande ? Icons.local_shipping_outlined : Icons.inventory_2_outlined, color: Colors.white, size: 30),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.grande ? 'Encomenda grande chegou!' : 'Sua encomenda chegou!',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text('${e.remetente} · ${e.descricao}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: tema.colorScheme.onSurfaceVariant, fontSize: 13)),
                        ]),
                      ),
                      FilledButton(
                        onPressed: widget.aoVer,
                        style: FilledButton.styleFrom(backgroundColor: cor, minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                        child: const Text('Ver código'),
                      ),
                      IconButton(onPressed: _fechar, icon: const Icon(Icons.close, size: 18), tooltip: 'Fechar aviso'),
                    ]),
                  ),
                  // Barra que mostra quanto tempo falta para o aviso sumir
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedBuilder(
                      animation: _tempo,
                      builder: (_, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(widthFactor: 1 - _tempo.value, child: Container(height: 3, color: cor)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Confetes caindo (desenhados à mão com CustomPainter)
class _Confetes extends CustomPainter {
  _Confetes(this.progresso, this.semente);

  final double progresso;
  final int semente;
  static const _cores = [Cores.primaria, Cores.estrela, Color(0xFF22C55E), Color(0xFF3B82F6), Color(0xFFA855F7)];

  @override
  void paint(Canvas canvas, Size tamanho) {
    if (progresso == 0 || progresso == 1) return;
    final aleatorio = Random(semente);
    for (var i = 0; i < 20; i++) {
      final x = aleatorio.nextDouble() * tamanho.width;
      final atraso = aleatorio.nextDouble() * 0.3;
      final t = ((progresso - atraso) / (1 - atraso)).clamp(0.0, 1.0);
      if (t == 0) continue;
      final y = -10 + t * (tamanho.height + 60);
      final paint = Paint()..color = _cores[i % _cores.length].withValues(alpha: 1 - t);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(t * 9 + i)
        ..drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -6, 8, 12), const Radius.circular(2)), paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_Confetes antigo) => antigo.progresso != progresso;
}

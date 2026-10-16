/// Funções de texto e data usadas em várias telas.
library;

String _dois(int n) => n.toString().padLeft(2, '0');

/// 14/10 22:50
String diaHora(DateTime d) => '${_dois(d.day)}/${_dois(d.month)} ${_dois(d.hour)}:${_dois(d.minute)}';

/// 14/10/2026 22:50
String dataHora(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}/${d.year} ${_dois(d.hour)}:${_dois(d.minute)}';

/// [H2] Linguagem do mundo real: "agora", "há 5 min", "ontem"
String tempoRelativo(DateTime d) {
  final min = DateTime.now().difference(d).inMinutes;
  if (min < 1) return 'agora';
  if (min < 60) return 'há $min min';
  final h = (min / 60).round();
  if (h < 24) return 'há $h h';
  final dias = (h / 24).round();
  return dias == 1 ? 'ontem' : 'há $dias dias';
}

String iniciais(String nome) => nome
    .split(' ')
    .where((p) => p.isNotEmpty)
    .take(2)
    .map((p) => p[0].toUpperCase())
    .join();

String primeiroNome(String nome) => nome.split(' ').first;

String plural(int n, String um, String varios) => '$n ${n == 1 ? um : varios}';

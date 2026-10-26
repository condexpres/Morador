import 'dart:async';

import 'package:flutter/foundation.dart';

import 'servidor.dart';

/// Servidor de mentira, em memória, usado nos testes automáticos.
/// Imita o Supabase: as mesmas tabelas, no mesmo formato, e regras parecidas
/// (o morador só lê o que é dele).
class ServidorMemoria implements Servidor {
  ServidorMemoria({Map<String, ({String id, String senha})>? contas, Map<String, List<Map<String, dynamic>>>? tabelas})
      : contas = contas ?? contasDemonstracao(),
        tabelas = tabelas ?? tabelasDemonstracao();

  final Map<String, ({String id, String senha})> contas;
  final Map<String, List<Map<String, dynamic>>> tabelas;
  final _sessao = StreamController<void>.broadcast();
  VoidCallback? _ouvinte;
  String? _id;
  String? _google;

  /// Liga/desliga a "internet" para testar falhas
  bool online = true;

  @override
  String? get usuarioId => _id;
  @override
  String? get emailUsuario => contas.entries.where((c) => c.value.id == _id).firstOrNull?.key;
  @override
  String? get googleVinculado => _google;
  @override
  Stream<void> get mudouSessao => _sessao.stream;

  void _conferirRede() {
    if (!online) throw ErroServidor('Sem conexão com o servidor. Confira a internet e tente de novo.');
  }

  @override
  Future<String?> entrar(String email, String senha) async {
    if (!online) return 'Sem conexão com o servidor. Confira a internet e tente de novo.';
    final c = contas[email];
    if (c == null || c.senha != senha) return 'E-mail ou senha incorretos. Confira e tente de novo.';
    _id = c.id;
    return null;
  }

  @override
  Future<void> sair() async {
    _id = null;
    _ouvinte = null;
  }

  @override
  Future<String?> trocarSenha(String nova) async {
    final email = emailUsuario!;
    if (contas[email]!.senha == nova) return 'A nova senha precisa ser diferente da atual.';
    contas[email] = (id: _id!, senha: nova);
    return null;
  }

  @override
  Future<String?> entrarComGoogle() async => 'Login com Google indisponível nos testes.';
  @override
  Future<String?> vincularGoogle() async {
    _google = 'teste@gmail.com';
    _sessao.add(null);
    return null;
  }

  @override
  Future<String?> desvincularGoogle() async {
    _google = null;
    return null;
  }

  bool _podeVer(String tabela, Map<String, dynamic> l) => switch (tabela) {
        'perfis' => l['id'] == _id,
        'encomendas' || 'pre_cadastros' || 'avaliacoes' => l['morador_id'] == _id,
        'notificacoes' => l['para'] == _id,
        _ => true,
      };

  @override
  Future<List<Map<String, dynamic>>> ler(String tabela, {String? ordem, int? limite}) async {
    _conferirRede();
    if (tabela == 'perfis_publicos') {
      return [
        for (final p in tabelas['perfis']!)
          {
            'id': p['id'],
            'tipo': p['tipo'],
            'dados': {for (final k in ['nome', 'bloco', 'apto', 'foto']) if ((p['dados'] as Map)[k] != null) k: (p['dados'] as Map)[k]},
          },
      ];
    }
    final linhas = [for (final l in tabelas[tabela] ?? const <Map<String, dynamic>>[]) if (_podeVer(tabela, l)) _copia(l)];
    return limite == null ? linhas : linhas.take(limite).toList();
  }

  Map<String, dynamic> _copia(Map<String, dynamic> l) => {
        for (final e in l.entries) e.key: e.value is Map ? _copiaProfunda(e.value) : e.value,
      };
  static dynamic _copiaProfunda(dynamic v) => v is Map
      ? {for (final e in v.entries) e.key as String: _copiaProfunda(e.value)}
      : v is List
          ? [for (final x in v) _copiaProfunda(x)]
          : v;

  @override
  Future<void> inserir(String tabela, Map<String, dynamic> linha) async {
    _conferirRede();
    tabelas.putIfAbsent(tabela, () => []).add(_copia(linha));
    _ouvinte?.call();
  }

  @override
  Future<void> atualizar(String tabela, String id, Map<String, dynamic> campos) async {
    _conferirRede();
    final l = tabelas[tabela]?.where((x) => x['id'] == id).firstOrNull;
    if (l == null) throw ErroServidor('Você não tem permissão para esta ação.');
    l.addAll(_copia(campos));
    _ouvinte?.call();
  }

  @override
  Future<void> apagar(String tabela, String id) async {
    _conferirRede();
    tabelas[tabela]?.removeWhere((x) => x['id'] == id);
    _ouvinte?.call();
  }

  @override
  Future<void> chamar(String funcao) async {}

  final aceites = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> verificarRegistro(String codigo) async => null;

  @override
  Future<Map<String, dynamic>> aceitarTermo(String versao, String textoHash) async {
    _conferirRede();
    final a = {'usuario_id': _id, 'versao': versao, 'texto_hash': textoHash, 'hash': 'h${aceites.length}', 'criado_em': DateTime.now().toIso8601String()};
    aceites.add(a);
    return a;
  }

  @override
  void escutar(VoidCallback aoMudar) => _ouvinte = aoMudar;
  @override
  void pararDeEscutar() => _ouvinte = null;

  @override
  Future<String> enviarFoto(String pasta, Uint8List bytes) async {
    _conferirRede();
    return 'sb:$pasta/${idAleatorio()}.jpg';
  }

  @override
  Future<String?> linkFoto(String caminho) async => null;

  /// Simula a portaria registrando uma encomenda para o morador (tempo real)
  void portariaRegistra({required String moradorId, required String id, required String codigo, required String token, String remetente = 'Amazon'}) {
    final agora = DateTime.now().millisecondsSinceEpoch;
    tabelas['encomendas']!.add({
      'id': id,
      'morador_id': moradorId,
      'dados': {
        'codigo': codigo, 'moradorId': moradorId, 'remetente': remetente, 'descricao': 'Caixa pequena', 'token': token,
        'status': 'aguardando', 'recebidaEm': agora, 'porteiroRecebeu': 'P001',
        'eventos': [{'data': agora, 'texto': 'Recebida na portaria por José Pereira (P001)'}],
      },
    });
    tabelas['notificacoes']!.add({
      'id': 'n-$id',
      'para': moradorId,
      'dados': {'moradorId': moradorId, 'texto': 'Chegou! $remetente · Caixa pequena. Seu código de retirada é $token.', 'tipo': 'chegou', 'encId': id, 'data': agora, 'lida': false},
    });
    _ouvinte?.call();
  }
}

// ---------------------------------------------------------------- Demonstração
const idAna = 'ana-0000';
const idPedro = 'pedro-0000';
const idSindico = 'sindico-0000';
const idCarlos = 'carlos-0000';

Map<String, ({String id, String senha})> contasDemonstracao() => {
      'ana@email.com': (id: idAna, senha: 'ana12345'),
      'pedro@email.com': (id: idPedro, senha: 'Qbe5RjDs'),
      'jose.pereira@condexpress.com.br': (id: 'jose-0000', senha: 'P0011985'),
    };

Map<String, List<Map<String, dynamic>>> tabelasDemonstracao() {
  int ha({int dias = 0, int horas = 0}) => DateTime.now().subtract(Duration(days: dias, hours: horas)).millisecondsSinceEpoch;
  final chegou = ha(horas: 2), entregue1 = ha(dias: 2, horas: 3), entregue2 = ha(dias: 6);
  Map<String, dynamic> enc(String id, Map<String, dynamic> d) => {'id': id, 'morador_id': idAna, 'dados': {'moradorId': idAna, ...d}};
  return {
    'perfis': [
      {'id': idAna, 'tipo': 'morador', 'email': 'ana@email.com', 'dados': {'nome': 'Ana Souza', 'bloco': 'A', 'apto': '12', 'diretriz': 'maos', 'termoAceito': {'versao': '1.0', 'em': 0, 'hash': 'h'}}},
      {'id': idPedro, 'tipo': 'morador', 'email': 'pedro@email.com', 'dados': {'nome': "Pedro D'Ávila", 'bloco': 'C', 'apto': '101', 'deveTrocarSenha': true}},
      {'id': idCarlos, 'tipo': 'morador', 'email': 'carlos@email.com', 'dados': {'nome': 'Carlos Lima', 'bloco': 'B', 'apto': '34'}},
      {'id': idSindico, 'tipo': 'admin', 'email': 'admin@condexpress.com', 'dados': {'nome': 'Síndico Roberto'}},
      {'id': 'jose-0000', 'tipo': 'portaria', 'email': 'jose.pereira@condexpress.com.br', 'porteiro_id': 'P001', 'dados': {'nome': 'José Pereira'}},
    ],
    'porteiros_publicos': [
      {'id': 'P001', 'dados': {'nome': 'José Pereira'}},
      {'id': 'P002', 'dados': {'nome': 'Marta Rocha'}},
    ],
    'encomendas': [
      enc('e12', {
        'codigo': 'CX-0012', 'remetente': 'Correios', 'descricao': 'Caixa média', 'rastreio': 'BR123456789BR', 'token': '4827', 'fragil': true,
        'status': 'aguardando', 'recebidaEm': chegou, 'porteiroRecebeu': 'P001',
        'eventos': [
          {'data': chegou, 'texto': 'Recebida na portaria por José Pereira (P001)'},
          {'data': chegou, 'texto': 'Sinalizada como frágil: armazenada separadamente'},
          {'data': chegou, 'texto': 'Morador notificado'},
        ],
      }),
      enc('e09', {
        'codigo': 'CX-0009', 'remetente': 'Shopee', 'descricao': 'Capinha de celular', 'token': '1903', 'status': 'entregue',
        'recebidaEm': entregue1 - 5 * 3600000, 'porteiroRecebeu': 'P002', 'entregueEm': entregue1, 'retiradoPor': 'Ana Souza',
        'eventos': [
          {'data': entregue1 - 5 * 3600000, 'texto': 'Recebida na portaria por Marta Rocha (P002)'},
          {'data': entregue1, 'texto': 'Retirada por Ana Souza com o código ✔ · liberada por José Pereira (P001)'},
        ],
      }),
      enc('e07', {
        'codigo': 'CX-0007', 'remetente': 'Mercado Livre', 'descricao': 'Fone de ouvido', 'token': '5561', 'status': 'entregue',
        'recebidaEm': entregue2 - 3 * 3600000, 'porteiroRecebeu': 'P001', 'entregueEm': entregue2, 'retiradoPor': 'Ana Souza',
        'eventos': [
          {'data': entregue2 - 3 * 3600000, 'texto': 'Recebida na portaria por José Pereira (P001)'},
          {'data': entregue2, 'texto': 'Retirada por Ana Souza com o código ✔ · liberada por Marta Rocha (P002)'},
        ],
      }),
    ],
    'notificacoes': [
      {'id': 'n3', 'para': idAna, 'dados': {'moradorId': idAna, 'tipo': 'chegou', 'encId': 'e12', 'data': chegou, 'lida': false, 'texto': 'Chegou! Correios · Caixa média. Seu código de retirada é 4827.'}},
      {'id': 'n2', 'para': idAna, 'dados': {'moradorId': idAna, 'tipo': 'entregue', 'encId': 'e09', 'data': entregue1, 'lida': true, 'texto': 'Encomenda CX-0009 entregue para você.'}},
    ],
    'pre_cadastros': [
      {'id': 'c1', 'morador_id': idAna, 'dados': {'moradorId': idAna, 'loja': 'Amazon', 'descricao': 'Livro "Clean Code"', 'criadoEm': ha(dias: 1), 'recebido': false}},
    ],
    'avaliacoes': [
      {'id': 'a1', 'morador_id': idAna, 'dados': {'moradorId': idAna, 'encomendaId': 'e07', 'portaria': 5, 'logistica': 4, 'data': entregue2}},
    ],
    'forum': [
      {'id': 'p2', 'autor_id': idCarlos, 'dados': {
        'autorId': idCarlos, 'texto': 'Alguém sabe se a portaria recebe encomendas no domingo à noite?', 'data': ha(horas: 5),
        'respostas': [{'autorId': idSindico, 'texto': 'Recebe sim, Carlos. A portaria funciona 24 horas.', 'data': ha(horas: 4)}],
      }},
      {'id': 'p1', 'autor_id': idSindico, 'dados': {
        'autorId': idSindico, 'texto': 'Bem-vindos à comunidade do condomínio! Usem este espaço para sugestões, dúvidas e avisos.',
        'data': ha(dias: 3), 'respostas': [],
      }},
    ],
  };
}

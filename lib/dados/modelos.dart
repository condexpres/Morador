/// Modelos de dados do app do morador.
/// Os registros vêm do Supabase no mesmo formato que o site da portaria e do
/// síndico grava (campo "dados" de cada tabela, datas em milissegundos).
/// [deServidor] lê esse formato; [paraServidor] grava de volta.
library;

enum StatusEncomenda { aguardando, entregue }

/// [REQ-12] Diretrizes de entrega
enum Diretriz {
  maos('Somente em mãos', 'Apenas eu posso retirar, com o código'),
  unidade('Qualquer morador da unidade', 'Familiares também retiram com o código'),
  porta('Deixar na porta', 'A portaria leva até a porta da unidade');

  const Diretriz(this.titulo, this.descricao);
  final String titulo;
  final String descricao;

  static Diretriz deNome(Object? nome) => Diretriz.values.firstWhere((d) => d.name == nome, orElse: () => Diretriz.maos);
}

const parentescos = ['Cônjuge', 'Filho(a)', 'Pai/Mãe', 'Irmão(ã)', 'Outro familiar', 'Funcionário(a) da casa'];

DateTime _data(Object? v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : DateTime.tryParse('$v') ?? DateTime.now();
int _ms(DateTime d) => d.millisecondsSinceEpoch;

class Evento {
  Evento(this.data, this.texto);
  final DateTime data;
  final String texto;

  factory Evento.deServidor(Map<String, dynamic> j) => Evento(_data(j['data']), '${j['texto'] ?? ''}');
}

class Encomenda {
  Encomenda({
    required this.id,
    required this.codigo,
    required this.remetente,
    required this.descricao,
    this.rastreio = '',
    required this.token,
    required this.recebidaEm,
    required this.recebidaPor,
    required this.eventos,
    this.fragil = false,
    this.grande = false,
    this.status = StatusEncomenda.aguardando,
    this.entregueEm,
    this.retiradoPor,
    this.foto,
  });

  final String id;
  final String codigo;
  final String remetente;
  final String descricao;

  /// Código de rastreio da transportadora (opcional).
  final String rastreio;

  /// [RD 03] Código de retirada que o morador mostra ao porteiro
  final String token;
  final bool fragil;
  final bool grande;
  StatusEncomenda status;
  final DateTime recebidaEm;
  final String recebidaPor;
  DateTime? entregueEm;
  String? retiradoPor;

  /// [REQ-04] Foto tirada pela portaria ("sb:encomendas/…" no Storage)
  final String? foto;

  /// [REQ-05] Histórico completo do volume
  final List<Evento> eventos;

  bool get naPortaria => status == StatusEncomenda.aguardando;

  /// [nomePorteiro] traduz a matrícula (P001) no nome de quem recebeu
  factory Encomenda.deServidor(String id, Map<String, dynamic> j, {String Function(String matricula)? nomePorteiro}) {
    final matricula = j['porteiroRecebeu'] as String?;
    final parentesco = j['parentesco'] as String?;
    final retirado = j['retiradoPor'] as String?;
    return Encomenda(
      id: id,
      codigo: '${j['codigo'] ?? ''}',
      remetente: '${j['remetente'] ?? ''}',
      descricao: '${j['descricao'] ?? ''}',
      rastreio: '${j['rastreio'] ?? ''}',
      token: '${j['token'] ?? ''}',
      fragil: j['fragil'] == true,
      grande: j['grande'] == true,
      status: j['status'] == 'entregue' ? StatusEncomenda.entregue : StatusEncomenda.aguardando,
      recebidaEm: _data(j['recebidaEm']),
      recebidaPor: matricula == null ? 'Portaria' : nomePorteiro?.call(matricula) ?? matricula,
      entregueEm: j['entregueEm'] == null ? null : _data(j['entregueEm']),
      retiradoPor: retirado == null ? null : parentesco == null ? retirado : '$retirado ($parentesco)',
      foto: j['foto'] as String?,
      eventos: [for (final e in (j['eventos'] as List? ?? const [])) Evento.deServidor(Map<String, dynamic>.from(e as Map))],
    );
  }
}

/// tipo: chegou | urgente | entregue | cancelada
class Notificacao {
  Notificacao({required this.id, required this.texto, required this.tipo, required this.data, this.encomendaId, this.lida = false});

  final String id;
  final String texto;
  final String tipo;
  final DateTime data;
  final String? encomendaId;
  bool lida;

  factory Notificacao.deServidor(String id, Map<String, dynamic> j) => Notificacao(
        id: id,
        texto: '${j['texto'] ?? ''}',
        tipo: '${j['tipo'] ?? 'chegou'}',
        data: _data(j['data']),
        encomendaId: j['encId'] as String?,
        lida: j['lida'] == true,
      );

  Map<String, dynamic> paraServidor(String para) =>
      {'moradorId': para, 'texto': texto, 'tipo': tipo, 'encId': encomendaId, 'data': _ms(data), 'lida': lida};
}

/// [REQ-11] Compra avisada à portaria
class PreCadastro {
  PreCadastro({required this.id, required this.loja, required this.descricao, required this.criadoEm, this.recebido = false});

  final String id;
  final String loja;
  final String descricao;
  final DateTime criadoEm;
  bool recebido;

  factory PreCadastro.deServidor(String id, Map<String, dynamic> j) => PreCadastro(
        id: id,
        loja: '${j['loja'] ?? ''}',
        descricao: '${j['descricao'] ?? ''}',
        criadoEm: _data(j['criadoEm']),
        recebido: j['recebido'] == true,
      );

  Map<String, dynamic> paraServidor(String moradorId) =>
      {'moradorId': moradorId, 'loja': loja, 'descricao': descricao, 'criadoEm': _ms(criadoEm), 'recebido': recebido};
}

/// Pessoa autorizada pelo morador a retirar encomendas
class Autorizado {
  Autorizado({required this.id, required this.nome, required this.parentesco});

  final String id;
  final String nome;
  final String parentesco;

  Map<String, dynamic> paraServidor() => {'id': id, 'nome': nome, 'parentesco': parentesco};
  factory Autorizado.deServidor(Map<String, dynamic> j) => Autorizado(id: '${j['id']}', nome: '${j['nome']}', parentesco: '${j['parentesco']}');
}

/// [REQ-13] Avaliação da portaria e da logística
class Avaliacao {
  Avaliacao({required this.portaria, required this.logistica, required this.data, this.encomendaId, this.comentario = ''});

  final String? encomendaId;
  final int portaria;
  final int logistica;
  final String comentario;
  final DateTime data;

  factory Avaliacao.deServidor(Map<String, dynamic> j) => Avaliacao(
        encomendaId: j['encomendaId'] as String?,
        portaria: (j['portaria'] as num?)?.toInt() ?? 0,
        logistica: (j['logistica'] as num?)?.toInt() ?? 0,
        comentario: '${j['comentario'] ?? ''}',
        data: _data(j['data']),
      );

  Map<String, dynamic> paraServidor(String moradorId) => {
        'moradorId': moradorId,
        'encomendaId': encomendaId,
        'portaria': portaria,
        'logistica': logistica,
        'comentario': comentario,
        'data': _ms(data),
      };
}

/// Nome, unidade e foto de quem escreve na comunidade
class Pessoa {
  const Pessoa({required this.nome, required this.rotulo, this.admin = false, this.foto});
  final String nome;
  final String rotulo;
  final bool admin;
  final String? foto;

  static const desconhecida = Pessoa(nome: 'Ex-morador', rotulo: '');
}

class Resposta {
  Resposta({required this.autorId, required this.autor, required this.texto, required this.data, this.foto});

  final String? autorId;
  final String autor;
  final String? foto;
  final String texto;
  final DateTime data;

  Map<String, dynamic> paraServidor() => {'autorId': autorId, 'texto': texto, 'data': _ms(data)};
}

/// [REQ-09] Mensagem da comunidade (fórum)
class Post {
  Post({
    required this.id,
    required this.autorId,
    required this.autor,
    required this.rotulo,
    required this.texto,
    required this.data,
    this.admin = false,
    this.foto,
    List<Resposta>? respostas,
  }) : respostas = respostas ?? [];

  final String id;
  final String? autorId;
  final String autor;

  /// Unidade do morador ou "Administração"
  final String rotulo;
  final bool admin;
  final String? foto;
  final String texto;
  final DateTime data;
  final List<Resposta> respostas;

  factory Post.deServidor(String id, Map<String, dynamic> j, Pessoa Function(String? id) pessoa) {
    final autor = pessoa(j['autorId'] as String?);
    return Post(
      id: id,
      autorId: j['autorId'] as String?,
      autor: autor.nome,
      rotulo: autor.rotulo,
      admin: autor.admin,
      foto: autor.foto,
      texto: '${j['texto'] ?? ''}',
      data: _data(j['data']),
      respostas: [
        for (final r in (j['respostas'] as List? ?? const []))
          () {
            final m = Map<String, dynamic>.from(r as Map);
            final p = pessoa(m['autorId'] as String?);
            return Resposta(autorId: m['autorId'] as String?, autor: p.nome, foto: p.foto, texto: '${m['texto'] ?? ''}', data: _data(m['data']));
          }(),
      ],
    );
  }

  Map<String, dynamic> paraServidor() =>
      {'autorId': autorId, 'texto': texto, 'data': _ms(data), 'respostas': [for (final r in respostas) r.paraServidor()]};
}

class Morador {
  Morador({
    required this.nome,
    required this.email,
    required this.bloco,
    required this.apto,
    this.diretriz = Diretriz.maos,
    this.foto,
    this.google,
    this.deveTrocarSenha = false,
    this.termoAceito,
    List<Autorizado>? autorizados,
  }) : autorizados = autorizados ?? [];

  String nome;
  String email;
  String bloco;
  String apto;
  Diretriz diretriz;

  /// Foto do perfil ("sb:perfis/…" no Storage)
  String? foto;
  String? google;

  /// Verdadeiro enquanto o morador usa a senha provisória gerada pela administração
  bool deveTrocarSenha;

  /// Aceite do termo de uso: versão, data e hora (servidor) e hash do aceite
  Map<String, dynamic>? termoAceito;
  final List<Autorizado> autorizados;

  String get unidade => 'Bloco $bloco · Apto $apto';

  factory Morador.deServidor(String email, Map<String, dynamic> j) => Morador(
        nome: '${j['nome'] ?? ''}',
        email: email,
        bloco: '${j['bloco'] ?? ''}',
        apto: '${j['apto'] ?? ''}',
        diretriz: Diretriz.deNome(j['diretriz']),
        foto: j['foto'] as String?,
        google: j['google'] as String?,
        deveTrocarSenha: j['deveTrocarSenha'] == true,
        termoAceito: j['termoAceito'] is Map ? Map<String, dynamic>.from(j['termoAceito'] as Map) : null,
        autorizados: [for (final a in (j['autorizados'] as List? ?? const [])) Autorizado.deServidor(Map<String, dynamic>.from(a as Map))],
      );

  /// Junta as mudanças do app com o que já estava no servidor (sem perder campos)
  Map<String, dynamic> paraServidor(Map<String, dynamic> antes) {
    final d = Map<String, dynamic>.from(antes)
      ..['nome'] = nome
      ..['bloco'] = bloco
      ..['apto'] = apto
      ..['diretriz'] = diretriz.name
      ..['autorizados'] = [for (final a in autorizados) a.paraServidor()];
    foto == null ? d.remove('foto') : d['foto'] = foto;
    google == null ? d.remove('google') : d['google'] = google;
    deveTrocarSenha ? d['deveTrocarSenha'] = true : d.remove('deveTrocarSenha');
    termoAceito == null ? d.remove('termoAceito') : d['termoAceito'] = termoAceito;
    return d;
  }
}

/// Tudo o que pertence ao morador logado: perfil, encomendas, avisos, compras e avaliações.
class ContaMorador {
  ContaMorador({
    required this.id,
    required this.perfil,
    List<Encomenda>? encomendas,
    List<Notificacao>? notificacoes,
    List<PreCadastro>? compras,
    List<Avaliacao>? avaliacoes,
  })  : encomendas = encomendas ?? [],
        notificacoes = notificacoes ?? [],
        compras = compras ?? [],
        avaliacoes = avaliacoes ?? [];

  final String id;
  final Morador perfil;
  final List<Encomenda> encomendas;
  final List<Notificacao> notificacoes;
  final List<PreCadastro> compras;
  final List<Avaliacao> avaliacoes;

  List<Encomenda> get naPortaria => encomendas.where((e) => e.naPortaria).toList();
  int get naoLidas => notificacoes.where((n) => !n.lida).length;
}

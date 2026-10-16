import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'modelos.dart';
import 'servidor.dart';

/// Estado do app do morador.
///
/// Os dados ficam no Supabase, o mesmo banco do site da portaria e do síndico:
/// quando o porteiro registra uma encomenda, ela aparece aqui na hora (tempo real).
/// Só a preferência de aparência (claro/escuro) fica guardada no aparelho.
class AppStore extends ChangeNotifier with WidgetsBindingObserver {
  AppStore._(this._servidor, this._prefs, this.modoTema);

  static const _chaveTema = 'condexpress_tema';
  final Servidor _servidor;
  final SharedPreferences _prefs;

  ThemeMode modoTema;
  ContaMorador? conta;
  List<Post> forum = [];

  /// Login em andamento (a tela de login mostra "Entrando…")
  bool entrando = false;

  /// Mensagem para a tela de login (ex.: voltou do Google sem cadastro)
  String? avisoLogin;

  Map<String, dynamic> _dadosPerfil = {};
  final Set<String> _celebradas = {};
  final _erros = StreamController<String>.broadcast();
  final Map<String, String> _links = {};
  Future<String?>? _abrindo;
  Timer? _recarga;
  StreamSubscription<void>? _sessao;

  /// Erros de gravação (ex.: sem internet) para a tela mostrar
  Stream<String> get erros => _erros.stream;

  static Future<AppStore> carregar(Servidor servidor) async {
    final prefs = await SharedPreferences.getInstance();
    final tema = ThemeMode.values.asNameMap()[prefs.getString(_chaveTema)] ?? ThemeMode.system;
    final store = AppStore._(servidor, prefs, tema);
    if (servidor.usuarioId != null) store.avisoLogin = await store._abrirSessao();
    store._sessao = servidor.mudouSessao.listen((_) => store._sessaoMudou());
    WidgetsBinding.instance.addObserver(store);
    return store;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessao?.cancel();
    _recarga?.cancel();
    _servidor.pararDeEscutar();
    _erros.close();
    super.dispose();
  }

  Morador get perfil => conta!.perfil;
  String get _id => conta!.id;

  // ---------------------------------------------------------------- Sessão
  /// Entrou ou saiu por fora da tela de login (ex.: voltou da tela do Google)
  Future<void> _sessaoMudou() async {
    final id = _servidor.usuarioId;
    if (id == null) {
      if (conta != null) _encerrar();
    } else if (conta?.id != id) {
      avisoLogin = await _abrirSessao();
      notifyListeners();
    } else {
      _conferirGoogle(); // ex.: acabou de vincular o Google
    }
  }

  Future<String?> _abrirSessao() => _abrindo ??= _carregarConta().whenComplete(() => _abrindo = null);

  Future<String?> _carregarConta() async {
    final id = _servidor.usuarioId;
    if (id == null) return null;
    try {
      final meu = (await _servidor.ler('perfis')).where((p) => p['id'] == id).firstOrNull;
      if (meu == null) {
        // Ex.: entrou com um Google que não está vinculado a nenhuma conta → apaga o login vazio
        final porGoogle = _servidor.googleVinculado != null;
        await _servidor.chamar('descartar_login_sem_cadastro').catchError((_) {});
        await _servidor.sair();
        return porGoogle
            ? 'Este Google não está vinculado a nenhuma conta do condomínio. Entre com e-mail e senha e vincule em Perfil → Conta Google.'
            : 'Esta conta não tem cadastro no condomínio. Fale com a administração.';
      }
      if (meu['tipo'] != 'morador') {
        await _servidor.sair();
        return 'Este app é dos moradores. Portaria e síndico usam o site do Condexpress.';
      }
      await _ler(id, meu);
      _celebradas.clear();
      _servidor.escutar(_mudouNoServidor);
      _conferirGoogle();
      notifyListeners();
      return null;
    } on ErroServidor catch (e) {
      return e.mensagem;
    }
  }

  /// Lê tudo o que o morador pode ver (as regras do banco filtram o resto)
  Future<void> _ler(String id, Map<String, dynamic> meu) async {
    final r = await Future.wait([
      _servidor.ler('perfis_publicos'),
      _servidor.ler('porteiros_publicos'),
      _servidor.ler('encomendas', ordem: 'recebida_em', limite: 200),
      _servidor.ler('notificacoes', ordem: 'criada_em', limite: 60),
      _servidor.ler('pre_cadastros', ordem: 'criado_em', limite: 100),
      _servidor.ler('avaliacoes'),
      _servidor.ler('forum', ordem: 'criada_em', limite: 50),
    ]);
    Map<String, dynamic> dados(Map<String, dynamic> l) => Map<String, dynamic>.from(l['dados'] as Map? ?? const {});
    final pessoas = {
      for (final p in r[0])
        p['id'] as String: () {
          final d = dados(p);
          final tipo = p['tipo'];
          return Pessoa(
            nome: '${d['nome'] ?? ''}',
            rotulo: tipo == 'admin' ? 'Administração' : tipo == 'portaria' ? 'Portaria' : 'Bloco ${d['bloco']} · Apto ${d['apto']}',
            admin: tipo == 'admin',
            foto: d['foto'] as String?,
          );
        }(),
    };
    final porteiros = {for (final p in r[1]) p['id'] as String: '${dados(p)['nome']} (${p['id']})'};

    _dadosPerfil = dados(meu);
    final encomendas = [
      for (final l in r[2]) Encomenda.deServidor(l['id'] as String, dados(l), nomePorteiro: (m) => porteiros[m] ?? m),
    ]..sort((a, b) => b.recebidaEm.compareTo(a.recebidaEm));
    conta = ContaMorador(
      id: id,
      perfil: Morador.deServidor('${meu['email'] ?? _servidor.emailUsuario ?? ''}', _dadosPerfil),
      encomendas: encomendas,
      notificacoes: [for (final l in r[3]) if (l['para'] == id) Notificacao.deServidor(l['id'] as String, dados(l))]
        ..sort((a, b) => b.data.compareTo(a.data)),
      compras: [for (final l in r[4]) PreCadastro.deServidor(l['id'] as String, dados(l))]..sort((a, b) => b.criadoEm.compareTo(a.criadoEm)),
      avaliacoes: [for (final l in r[5]) Avaliacao.deServidor(dados(l))],
    );
    forum = [for (final l in r[6]) Post.deServidor(l['id'] as String, dados(l), (a) => pessoas[a] ?? Pessoa.desconhecida)]
      ..sort((a, b) => b.data.compareTo(a.data));
  }

  /// Algo mudou no banco (ex.: a portaria registrou uma encomenda): busca de novo
  void _mudouNoServidor() {
    _recarga?.cancel();
    _recarga = Timer(const Duration(milliseconds: 400), recarregar);
  }

  Future<void> recarregar() async {
    final id = conta?.id;
    if (id == null) return;
    try {
      final meu = (await _servidor.ler('perfis')).where((p) => p['id'] == id).firstOrNull;
      if (meu == null) return _encerrar(); // conta removida pela administração
      if (conta?.id != id) return;
      await _ler(id, meu);
      notifyListeners();
    } on ErroServidor {
      // sem internet: mantém o que já está na tela
    }
  }

  /// Voltou para o app depois de um tempo: busca o que mudou
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) recarregar();
  }

  void _encerrar() {
    _servidor.pararDeEscutar();
    conta = null;
    forum = [];
    _dadosPerfil = {};
    _celebradas.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------- Acesso
  /// [REQ-03] Login por e-mail e senha. Devolve uma mensagem de erro ou null.
  Future<String?> entrar(String email, String senha) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty || senha.isEmpty) return 'Preencha e-mail e senha para continuar.';
    entrando = true;
    avisoLogin = null;
    notifyListeners();
    var erro = await _servidor.entrar(e, senha);
    erro ??= await _abrirSessao();
    entrando = false;
    notifyListeners();
    return erro;
  }

  /// Login oficial do Google: abre a tela do Google e volta para o app
  Future<String?> entrarComGoogle() {
    avisoLogin = null;
    return _servidor.entrarComGoogle();
  }

  Future<void> sair() async {
    await _servidor.sair();
    _encerrar();
  }

  /// [H5] Regras de senha explicadas antes de salvar
  static String? problemaSenha(String nova, String confirma, String atual) {
    if (nova.length < 8) return 'Use pelo menos 8 caracteres.';
    if (!RegExp(r'[a-zA-Z]').hasMatch(nova) || !RegExp(r'\d').hasMatch(nova)) return 'Misture letras e números.';
    if (nova == atual) return 'A nova senha precisa ser diferente da atual.';
    if (nova != confirma) return 'As senhas não são iguais. Digite de novo.';
    return null;
  }

  /// Primeiro acesso: troca a senha provisória gerada pela administração
  Future<String?> criarSenha(String nova, String confirma) async {
    final erro = problemaSenha(nova, confirma, '') ?? await _servidor.trocarSenha(nova);
    if (erro != null) return erro;
    perfil.deveTrocarSenha = false;
    notifyListeners();
    return _salvarPerfil();
  }

  Future<String?> alterarSenha(String atual, String nova, String confirma) async {
    final problema = problemaSenha(nova, confirma, atual);
    if (problema != null) return problema;
    // Confere a senha atual entrando de novo com ela
    final confere = await _servidor.entrar(perfil.email, atual);
    if (confere != null) return confere.contains('incorretos') ? 'A senha atual está incorreta.' : confere;
    return _servidor.trocarSenha(nova);
  }

  Future<String?> vincularGoogle() => _servidor.vincularGoogle();

  Future<String?> desvincularGoogle() async {
    final erro = await _servidor.desvincularGoogle();
    if (erro != null) return erro;
    perfil.google = null;
    notifyListeners();
    return _salvarPerfil();
  }

  /// Ao voltar do Google: registra o vínculo no perfil
  void _conferirGoogle() {
    final google = _servidor.googleVinculado;
    if (conta == null || google == null || perfil.google == google) return;
    perfil
      ..google = google
      ..deveTrocarSenha = false; // com o Google vinculado, a senha provisória deixa de ser usada
    notifyListeners();
    _salvarPerfil();
  }

  // ---------------------------------------------------------------- Gravação
  /// Grava no servidor; se falhar, avisa a tela e volta ao que está salvo lá
  Future<String?> _gravar(Future<void> Function() acao) async {
    try {
      await acao();
      return null;
    } on ErroServidor catch (e) {
      _erros.add(e.mensagem);
      await recarregar();
      return e.mensagem;
    }
  }

  Future<String?> _salvarPerfil() => _gravar(() async {
        final dados = perfil.paraServidor(_dadosPerfil);
        await _servidor.atualizar('perfis', _id, {'dados': dados});
        _dadosPerfil = dados;
      });

  // ---------------------------------------------------------------- Perfil
  void definirTema(ThemeMode modo) {
    modoTema = modo;
    _prefs.setString(_chaveTema, modo.name);
    notifyListeners();
  }

  /// Envia a nova foto do perfil (null = remover)
  Future<String?> definirFoto(Uint8List? bytes) async {
    if (bytes == null) return voltarFoto(null);
    try {
      final ref = await _servidor.enviarFoto('perfis/$_id', bytes);
      _links[ref] = '';
      return await voltarFoto(ref);
    } on ErroServidor catch (e) {
      return e.mensagem;
    }
  }

  /// Volta para uma foto já enviada (ex.: "Desfazer" depois de remover)
  Future<String?> voltarFoto(String? ref) {
    perfil.foto = ref;
    notifyListeners();
    return _salvarPerfil();
  }

  void definirDiretriz(Diretriz d) {
    perfil.diretriz = d;
    notifyListeners();
    _salvarPerfil();
  }

  void adicionarAutorizado(String nome, String parentesco) {
    perfil.autorizados.add(Autorizado(id: idAleatorio(), nome: nome.trim(), parentesco: parentesco));
    notifyListeners();
    _salvarPerfil();
  }

  /// Devolve uma função que desfaz a remoção ([H3] Desfazer)
  VoidCallback removerAutorizado(Autorizado a) {
    final i = perfil.autorizados.indexOf(a);
    perfil.autorizados.removeAt(i);
    notifyListeners();
    _salvarPerfil();
    return () {
      perfil.autorizados.insert(i, a);
      notifyListeners();
      _salvarPerfil();
    };
  }

  // ---------------------------------------------------------------- Fotos
  /// Link temporário para mostrar uma foto do Storage (guardado por 50 minutos)
  Future<String?> linkFoto(String ref) async {
    if (!ref.startsWith('sb:')) return null;
    final pronto = _links[ref];
    if (pronto != null && pronto.isNotEmpty) return pronto;
    final link = await _servidor.linkFoto(ref.substring(3));
    if (link != null) {
      _links[ref] = link;
      Timer(const Duration(minutes: 50), () => _links.remove(ref));
    }
    return link;
  }

  String? linkFotoPronto(String ref) {
    final l = _links[ref];
    return l == null || l.isEmpty ? null : l;
  }

  // ---------------------------------------------------------------- Encomendas
  void marcarNotificacoesLidas() {
    final novas = conta!.notificacoes.where((n) => !n.lida).toList();
    if (novas.isEmpty) return;
    for (final n in novas) {
      n.lida = true;
    }
    notifyListeners();
    _gravar(() async {
      for (final n in novas) {
        await _servidor.atualizar('notificacoes', n.id, {'dados': n.paraServidor(_id)});
      }
    });
  }

  bool jaAvaliou(Encomenda e) => conta!.avaliacoes.any((a) => a.encomendaId == e.id);

  Encomenda? encomendaPorId(String id) {
    for (final e in conta!.encomendas) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Chegadas ainda não lidas que não tiveram animação nesta sessão
  List<Encomenda> chegadasParaCelebrar() {
    final novas = <Encomenda>[];
    for (final n in conta!.notificacoes) {
      if (n.lida || _celebradas.contains(n.id) || (n.tipo != 'chegou' && n.tipo != 'urgente')) continue;
      _celebradas.add(n.id);
      final e = n.encomendaId == null ? null : encomendaPorId(n.encomendaId!);
      if (e != null && e.naPortaria) novas.add(e);
    }
    return novas;
  }

  void avaliar({String? encomendaId, required int portaria, required int logistica, String comentario = ''}) {
    final a = Avaliacao(encomendaId: encomendaId, portaria: portaria, logistica: logistica, comentario: comentario.trim(), data: DateTime.now());
    conta!.avaliacoes.insert(0, a);
    notifyListeners();
    _gravar(() => _servidor.inserir('avaliacoes', {'id': idAleatorio(), 'morador_id': _id, 'dados': a.paraServidor(_id)}));
  }

  // ---------------------------------------------------------------- Compras avisadas
  /// [REQ-11] Avisa a portaria sobre uma compra a caminho
  void avisarCompra(String loja, String descricao) {
    final p = PreCadastro(id: idAleatorio(), loja: loja.trim(), descricao: descricao.trim(), criadoEm: DateTime.now());
    conta!.compras.insert(0, p);
    notifyListeners();
    final aviso = Notificacao(
      id: idAleatorio(),
      texto: '${perfil.nome} (${perfil.unidade}) avisou uma compra: ${p.loja} · ${p.descricao}',
      tipo: 'compra',
      data: DateTime.now(),
    );
    _gravar(() async {
      await _servidor.inserir('pre_cadastros', {'id': p.id, 'morador_id': _id, 'dados': p.paraServidor(_id)});
      await _servidor.inserir('notificacoes', {'id': aviso.id, 'para': 'portaria', 'dados': aviso.paraServidor('portaria')});
    });
  }

  VoidCallback removerCompra(PreCadastro p) {
    final i = conta!.compras.indexOf(p);
    conta!.compras.removeAt(i);
    notifyListeners();
    _gravar(() => _servidor.apagar('pre_cadastros', p.id));
    return () {
      conta!.compras.insert(i, p);
      notifyListeners();
      _gravar(() => _servidor.inserir('pre_cadastros', {'id': p.id, 'morador_id': _id, 'dados': p.paraServidor(_id)}));
    };
  }

  // ---------------------------------------------------------------- Comunidade
  void publicar(String texto) {
    final post = Post(
      id: idAleatorio(),
      autorId: _id,
      autor: perfil.nome,
      rotulo: perfil.unidade,
      foto: perfil.foto,
      texto: texto.trim(),
      data: DateTime.now(),
    );
    forum.insert(0, post);
    notifyListeners();
    _gravar(() => _servidor.inserir('forum', {'id': post.id, 'autor_id': _id, 'dados': post.paraServidor()}));
  }

  void responder(Post post, String texto) {
    post.respostas.add(Resposta(autorId: _id, autor: perfil.nome, foto: perfil.foto, texto: texto.trim(), data: DateTime.now()));
    notifyListeners();
    _gravar(() => _servidor.atualizar('forum', post.id, {'dados': post.paraServidor()}));
  }
}

/// Dá acesso ao [AppStore] em qualquer tela: `StoreScope.of(context)`.
/// As telas que usam `of` são redesenhadas quando o estado muda.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore super.notifier, required super.child});

  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Para usar dentro de callbacks (botões), sem redesenhar a tela.
  static AppStore ler(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

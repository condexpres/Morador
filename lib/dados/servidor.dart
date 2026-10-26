import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Endereço e chave pública do Supabase (os mesmos do site da portaria e do síndico).
/// A chave "publishable" pode ficar no app: quem protege os dados são as
/// regras de segurança do banco (supabase/condexpress.sql, no projeto do site).
const supabaseUrl = 'https://cjfbhsdzngqfnotuglqg.supabase.co';
const supabaseChave = 'sb_publishable_-2ICfcwf7mYfnmbbp4TsMQ_nJnwboVo';

/// Endereço para onde o Google devolve o morador no celular (Android e iPhone).
/// Precisa estar em Supabase → Authentication → URL Configuration → Redirect URLs.
const retornoGoogleCelular = 'br.com.condexpress.morador://login-callback';

/// Tudo o que o app pede ao servidor. O [ServidorSupabase] fala com o banco de
/// verdade; os testes usam um servidor em memória com o mesmo comportamento.
/// As linhas seguem o formato das tabelas: {id, ..., dados: {...}}.
abstract class Servidor {
  /// Id da conta logada (null = ninguém logado)
  String? get usuarioId;
  String? get emailUsuario;

  /// E-mail do Google vinculado à conta logada, se houver
  String? get googleVinculado;

  /// Avisa quando alguém entra ou sai (ex.: voltou da tela do Google)
  Stream<void> get mudouSessao;

  Future<String?> entrar(String email, String senha);
  Future<void> sair();
  Future<String?> trocarSenha(String nova);
  Future<String?> entrarComGoogle();
  Future<String?> vincularGoogle();
  Future<String?> desvincularGoogle();

  /// Lê as linhas que a conta pode ver (as regras do banco filtram)
  Future<List<Map<String, dynamic>>> ler(String tabela, {String? ordem, int? limite});
  Future<void> inserir(String tabela, Map<String, dynamic> linha);
  Future<void> atualizar(String tabela, String id, Map<String, dynamic> campos);
  Future<void> apagar(String tabela, String id);
  Future<void> chamar(String funcao);

  /// Confere no servidor o registro de prova de uma encomenda (corrente de hashes)
  Future<Map<String, dynamic>?> verificarRegistro(String codigo);

  /// Grava o aceite do termo de uso (o servidor põe data, hora e hash)
  Future<Map<String, dynamic>> aceitarTermo(String versao, String textoHash);

  /// Liga o tempo real: [aoMudar] é chamado quando algo muda no banco
  void escutar(VoidCallback aoMudar);
  void pararDeEscutar();

  /// Envia uma foto e devolve o endereço para guardar ("sb:pasta/arquivo.jpg")
  Future<String> enviarFoto(String pasta, Uint8List bytes);

  /// Link temporário para mostrar uma foto guardada no Storage
  Future<String?> linkFoto(String caminho);
}

/// Erro com mensagem pronta para mostrar ao morador
class ErroServidor implements Exception {
  ErroServidor(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

String idAleatorio() {
  final r = Random.secure();
  return List.generate(16, (_) => '0123456789abcdef'[r.nextInt(16)]).join();
}

class ServidorSupabase implements Servidor {
  ServidorSupabase._(this._sb);

  final SupabaseClient _sb;
  RealtimeChannel? _canal;

  static Future<ServidorSupabase> iniciar() async {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseChave);
    return ServidorSupabase._(Supabase.instance.client);
  }

  User? get _usuario => _sb.auth.currentUser;

  @override
  String? get usuarioId => _usuario?.id;
  @override
  String? get emailUsuario => _usuario?.email;
  @override
  String? get googleVinculado {
    for (final i in _usuario?.identities ?? const <UserIdentity>[]) {
      if (i.provider == 'google') return (i.identityData?['email'] as String?) ?? 'Google';
    }
    return null;
  }

  @override
  Stream<void> get mudouSessao => _sb.auth.onAuthStateChange
      .where((e) => const [AuthChangeEvent.signedIn, AuthChangeEvent.signedOut, AuthChangeEvent.userUpdated].contains(e.event))
      .map((_) {});

  /// Traduz os erros do servidor para mensagens que o morador entende
  static String mensagem(Object e) {
    final texto = e is AuthException ? e.message : e is PostgrestException ? e.message : e is StorageException ? e.message : '$e';
    if (e is AuthException && (e.code == 'invalid_credentials' || texto.contains('Invalid login'))) {
      return 'E-mail ou senha incorretos. Confira e tente de novo.';
    }
    if (e is AuthException && (e.code == 'same_password' || texto.contains('different from the old'))) {
      return 'A nova senha precisa ser diferente da atual.';
    }
    if (e is AuthException && (e.code == 'weak_password' || texto.contains('at least'))) {
      return 'Senha fraca: use pelo menos 8 caracteres, com letras e números.';
    }
    if (e is AuthException && texto.contains('Manual linking')) {
      return 'O vínculo com o Google não está ativado no servidor. Fale com a administração.';
    }
    if (texto.contains('row-level security') || texto.contains('permission denied')) return 'Você não tem permissão para esta ação.';
    if (e is AuthRetryableFetchException || texto.contains('SocketException') || texto.contains('Failed host lookup') ||
        texto.contains('ClientException') || texto.contains('Failed to fetch')) {
      return 'Sem conexão com o servidor. Confira a internet e tente de novo.';
    }
    return texto.isEmpty ? 'Algo deu errado. Tente de novo.' : texto;
  }

  Future<T> _tentar<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } catch (e) {
      throw ErroServidor(mensagem(e));
    }
  }

  @override
  Future<String?> entrar(String email, String senha) async {
    try {
      await _sb.auth.signInWithPassword(email: email, password: senha);
      return null;
    } catch (e) {
      return mensagem(e);
    }
  }

  @override
  Future<void> sair() async {
    pararDeEscutar();
    try {
      await _sb.auth.signOut();
    } catch (_) {
      // sem internet: a sessão local é apagada mesmo assim
    }
  }

  @override
  Future<String?> trocarSenha(String nova) async {
    try {
      await _sb.auth.updateUser(UserAttributes(password: nova));
      return null;
    } catch (e) {
      return mensagem(e);
    }
  }

  // No navegador, o Google volta para a própria página do app;
  // no celular, volta pelo endereço do app (abre o app de novo).
  String? get _retorno => kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : retornoGoogleCelular;

  @override
  Future<String?> entrarComGoogle() async {
    try {
      await _sb.auth.signInWithOAuth(OAuthProvider.google, redirectTo: _retorno);
      return null;
    } catch (e) {
      return mensagem(e);
    }
  }

  @override
  Future<String?> vincularGoogle() async {
    try {
      await _sb.auth.linkIdentity(OAuthProvider.google, redirectTo: _retorno);
      return null;
    } catch (e) {
      return mensagem(e);
    }
  }

  @override
  Future<String?> desvincularGoogle() async {
    try {
      final google = (await _sb.auth.getUserIdentities()).where((i) => i.provider == 'google');
      if (google.isNotEmpty) await _sb.auth.unlinkIdentity(google.first);
      await _sb.auth.refreshSession();
      return null;
    } catch (e) {
      return mensagem(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> ler(String tabela, {String? ordem, int? limite}) => _tentar(() async {
        PostgrestTransformBuilder<List<Map<String, dynamic>>> q = _sb.from(tabela).select();
        if (ordem != null) q = q.order(ordem, ascending: false);
        if (limite != null) q = q.limit(limite);
        return await q;
      });

  @override
  Future<void> inserir(String tabela, Map<String, dynamic> linha) => _tentar(() => _sb.from(tabela).insert(linha));

  @override
  Future<void> atualizar(String tabela, String id, Map<String, dynamic> campos) => _tentar(() async {
        final linhas = await _sb.from(tabela).update(campos).eq('id', id).select('id');
        if (linhas.isEmpty) throw ErroServidor('Você não tem permissão para esta ação.');
      });

  @override
  Future<void> apagar(String tabela, String id) => _tentar(() => _sb.from(tabela).delete().eq('id', id));

  @override
  Future<void> chamar(String funcao) => _tentar(() => _sb.rpc(funcao));

  @override
  Future<Map<String, dynamic>?> verificarRegistro(String codigo) async {
    try {
      final r = await _sb.rpc('verificar_registro', params: {'p_codigo': codigo});
      return r is Map ? Map<String, dynamic>.from(r) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> aceitarTermo(String versao, String textoHash) => _tentar(() async =>
      await _sb.from('aceites_termo').insert({'versao': versao, 'texto_hash': textoHash}).select('hash, criado_em').single());

  @override
  void escutar(VoidCallback aoMudar) {
    pararDeEscutar();
    var canal = _sb.channel('morador-${usuarioId ?? ''}');
    for (final tabela in const ['encomendas', 'notificacoes', 'pre_cadastros', 'forum', 'perfis']) {
      canal = canal.onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: tabela, callback: (_) => aoMudar());
    }
    _canal = canal..subscribe();
  }

  @override
  void pararDeEscutar() {
    final canal = _canal;
    _canal = null;
    if (canal != null) _sb.removeChannel(canal);
  }

  @override
  Future<String> enviarFoto(String pasta, Uint8List bytes) => _tentar(() async {
        final caminho = '$pasta/${idAleatorio()}.jpg';
        await _sb.storage.from('fotos').uploadBinary(caminho, bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '31536000'));
        return 'sb:$caminho';
      });

  @override
  Future<String?> linkFoto(String caminho) async {
    try {
      return await _sb.storage.from('fotos').createSignedUrl(caminho, 3600);
    } catch (_) {
      return null;
    }
  }
}

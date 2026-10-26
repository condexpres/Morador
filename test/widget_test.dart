import 'package:condexpress_morador/dados/modelos.dart';
import 'package:condexpress_morador/dados/servidor_memoria.dart';
import 'package:condexpress_morador/dados/store.dart';
import 'package:condexpress_morador/main.dart';
import 'package:condexpress_morador/telas/perfil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(AppStore, ServidorMemoria)> novoStore() async {
  SharedPreferences.setMockInitialValues({});
  final servidor = ServidorMemoria();
  return (await AppStore.carregar(servidor), servidor);
}

Future<void> abrirApp(WidgetTester tester, AppStore store) async {
  // Tela de celular (393 x 852)
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(CondexpressApp(store: store));
  await tester.pumpAndSettle();
}

/// Rola até o elemento ficar visível e toca nele
Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
}

/// Preenche e-mail e senha na tela de login e toca em "Entrar"
Future<void> fazerLogin(WidgetTester tester, String email, String senha) async {
  await tester.enterText(find.widgetWithText(TextField, 'E-mail'), email);
  await tester.enterText(find.widgetWithText(TextField, 'Senha'), senha);
  await tocar(tester, find.widgetWithText(FilledButton, 'Entrar'));
  await tester.pump();
  await tester.pump();
}

/// Rola a lista do Perfil até o item aparecer e toca nele
Future<void> tocarNoPerfil(WidgetTester tester, String texto) async {
  final lista = find.descendant(of: find.byType(TelaPerfil), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(find.text(texto), 200, scrollable: lista);
  await tester.pumpAndSettle();
  await tester.tap(find.text(texto));
}

/// Fecha o aviso animado de chegada, se estiver aberto
Future<void> fecharAvisoChegada(WidgetTester tester) async {
  final fechar = find.byTooltip('Fechar aviso');
  if (fechar.evaluate().isNotEmpty) {
    await tester.tap(fechar);
    await tester.pumpAndSettle();
  }
}

Map<String, dynamic> dadosDe(ServidorMemoria s, String tabela, String id) =>
    s.tabelas[tabela]!.firstWhere((l) => l['id'] == id)['dados'] as Map<String, dynamic>;

void main() {
  group('Regras e servidor', () {
    test('login com senha errada mostra erro e com a certa carrega a conta', () async {
      final (store, _) = await novoStore();
      expect(await store.entrar('ana@email.com', 'errada'), contains('incorretos'));
      expect(await store.entrar('ana@email.com', 'ana12345'), isNull);
      expect(store.conta!.perfil.nome, 'Ana Souza');
      expect(store.conta!.encomendas.first.recebidaPor, 'José Pereira (P001)');
      expect(store.forum.first.autor, 'Carlos Lima');
      expect(store.forum.first.respostas.first.autor, 'Síndico Roberto');
    });

    test('porteiro não entra no app do morador', () async {
      final (store, _) = await novoStore();
      expect(await store.entrar('jose.pereira@condexpress.com.br', 'P0011985'), contains('app é dos moradores'));
      expect(store.conta, isNull);
    });

    test('regras da nova senha', () {
      expect(AppStore.problemaSenha('abc', 'abc', 'x'), contains('8 caracteres'));
      expect(AppStore.problemaSenha('abcdefgh', 'abcdefgh', 'x'), contains('letras e números'));
      expect(AppStore.problemaSenha('casa2025', 'casa2026', 'x'), contains('não são iguais'));
      expect(AppStore.problemaSenha('casa2025', 'casa2025', 'x'), isNull);
    });

    test('primeiro acesso: troca a senha provisória e grava no servidor', () async {
      final (store, servidor) = await novoStore();
      await store.entrar('pedro@email.com', 'Qbe5RjDs');
      expect(store.perfil.deveTrocarSenha, isTrue);
      expect(await store.criarSenha('casa2025azul', 'casa2025azul'), isNull);
      expect(store.perfil.deveTrocarSenha, isFalse);
      expect(dadosDe(servidor, 'perfis', idPedro).containsKey('deveTrocarSenha'), isFalse);
      expect(servidor.contas['pedro@email.com']!.senha, 'casa2025azul');
    });

    test('termo de uso: quem não aceitou precisa aceitar, e o aceite vai para o servidor', () async {
      final (store, servidor) = await novoStore();
      await store.entrar('ana@email.com', 'ana12345');
      expect(store.precisaTermo, isFalse); // Ana já aceitou
      await store.sair();
      await store.entrar('pedro@email.com', 'Qbe5RjDs');
      expect(store.precisaTermo, isTrue);
      expect(await store.aceitarTermo(), isNull);
      expect(store.precisaTermo, isFalse);
      expect(servidor.aceites.single['texto_hash'], termoHash);
      expect((dadosDe(servidor, 'perfis', idPedro)['termoAceito'] as Map)['versao'], termoVersao);
    });

    test('alterar senha confere a senha atual', () async {
      final (store, servidor) = await novoStore();
      await store.entrar('ana@email.com', 'ana12345');
      expect(await store.alterarSenha('errada', 'nova2025ok', 'nova2025ok'), contains('atual está incorreta'));
      expect(await store.alterarSenha('ana12345', 'nova2025ok', 'nova2025ok'), isNull);
      expect(servidor.contas['ana@email.com']!.senha, 'nova2025ok');
    });

    test('a encomenda que chegou anima uma única vez e "lida" vai para o servidor', () async {
      final (store, servidor) = await novoStore();
      await store.entrar('ana@email.com', 'ana12345');
      expect(store.chegadasParaCelebrar().map((e) => e.codigo), ['CX-0012']);
      expect(store.chegadasParaCelebrar(), isEmpty);
      store.marcarNotificacoesLidas();
      await Future<void>.delayed(Duration.zero);
      expect(dadosDe(servidor, 'notificacoes', 'n3')['lida'], isTrue);
      await store.sair();
      await store.entrar('ana@email.com', 'ana12345');
      expect(store.chegadasParaCelebrar(), isEmpty); // aviso já foi lido
    });

    test('tempo real: a portaria registra e a encomenda aparece com animação', () async {
      final (store, servidor) = await novoStore();
      await store.entrar('ana@email.com', 'ana12345');
      store.chegadasParaCelebrar(); // a que já estava lá
      servidor.portariaRegistra(moradorId: idAna, id: 'e99', codigo: 'CX-0099', token: '7777');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(store.encomendaPorId('e99')?.token, '7777');
      expect(store.chegadasParaCelebrar().map((e) => e.codigo), ['CX-0099']);
    });

    test('avisar compra grava a compra e avisa a portaria', () async {
      final (store, servidor) = await novoStore();
      await store.entrar('ana@email.com', 'ana12345');
      store.avisarCompra('Kabum', 'Mouse');
      await Future<void>.delayed(Duration.zero);
      final compra = servidor.tabelas['pre_cadastros']!.last;
      expect(compra['morador_id'], idAna);
      expect((compra['dados'] as Map)['loja'], 'Kabum');
      final aviso = servidor.tabelas['notificacoes']!.last;
      expect(aviso['para'], 'portaria');
      expect((aviso['dados'] as Map)['texto'], contains('Ana Souza (Bloco A · Apto 12) avisou uma compra: Kabum · Mouse'));
    });

    test('sem internet: avisa o erro e volta ao que está salvo', () async {
      final (store, servidor) = await novoStore();
      await store.entrar('ana@email.com', 'ana12345');
      final erros = <String>[];
      store.erros.listen(erros.add);
      servidor.online = false;
      store.definirDiretriz(Diretriz.porta);
      await Future<void>.delayed(Duration.zero);
      expect(erros.single, contains('Sem conexão'));
      expect(dadosDe(servidor, 'perfis', idAna)['diretriz'], 'maos');
    });

    test('preferências e pessoas autorizadas vão para o perfil no servidor', () async {
      final (store, servidor) = await novoStore();
      await store.entrar('ana@email.com', 'ana12345');
      store.definirDiretriz(Diretriz.unidade);
      store.adicionarAutorizado('Maria Souza', 'Cônjuge');
      await Future<void>.delayed(Duration.zero);
      final d = dadosDe(servidor, 'perfis', idAna);
      expect(d['diretriz'], 'unidade');
      expect((d['autorizados'] as List).single['nome'], 'Maria Souza');
      expect(d['nome'], 'Ana Souza'); // não perde os outros campos
    });

    test('vincular o Google registra no perfil', () async {
      final (store, servidor) = await novoStore();
      await store.entrar('ana@email.com', 'ana12345');
      await store.vincularGoogle();
      await Future<void>.delayed(Duration.zero);
      expect(store.perfil.google, 'teste@gmail.com');
      expect(dadosDe(servidor, 'perfis', idAna)['google'], 'teste@gmail.com');
    });
  });

  group('Telas', () {
    testWidgets('login mostra a logo e não tem atalhos de teste', (tester) async {
      final (store, _) = await novoStore();
      await abrirApp(tester, store);
      expect(find.bySemanticsLabel(RegExp('Condexpress')), findsWidgets);
      expect(find.text('Continuar com Google'), findsOneWidget);
    });

    testWidgets('login → animação de chegada → início com o código', (tester) async {
      final (store, _) = await novoStore();
      await abrirApp(tester, store);
      await fazerLogin(tester, 'ana@email.com', 'ana12345');
      await tester.pump(const Duration(milliseconds: 800)); // o aviso some sozinho em 7 s
      expect(find.text('Sua encomenda chegou!'), findsOneWidget);
      await fecharAvisoChegada(tester);

      expect(find.text('Olá, Ana!'), findsOneWidget);
      expect(find.text('Chegou! Está na portaria'), findsOneWidget);
      for (final d in '4827'.split('')) {
        expect(find.text(d), findsWidgets);
      }
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('senha errada mostra mensagem clara', (tester) async {
      final (store, _) = await novoStore();
      await abrirApp(tester, store);
      await fazerLogin(tester, 'ana@email.com', '0000');
      await tester.pumpAndSettle();
      expect(find.textContaining('E-mail ou senha incorretos'), findsOneWidget);
    });

    testWidgets('"Esqueci minha senha" explica o que fazer', (tester) async {
      final (store, _) = await novoStore();
      await abrirApp(tester, store);
      await tocar(tester, find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();
      expect(find.textContaining('nova senha provisória'), findsOneWidget);
    });

    testWidgets('termo de uso e depois primeiro acesso, sem abas, com senha forte', (tester) async {
      final (store, _) = await novoStore();
      await abrirApp(tester, store);
      await fazerLogin(tester, 'pedro@email.com', 'Qbe5RjDs');
      await tester.pumpAndSettle();
      // Termo de uso vem antes de tudo
      expect(find.text('Termo de uso'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tocar(tester, find.text('Aceitar e continuar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Marque "Li e aceito"'), findsOneWidget);
      await tocar(tester, find.text('Li e aceito o termo de uso'));
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Aceitar e continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Primeiro acesso'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tocar(tester, find.text('Criar senha e continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Use pelo menos 8 caracteres.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Nova senha'), 'casa2025azul');
      await tester.enterText(find.widgetWithText(TextField, 'Repita a nova senha'), 'casa2025azul');
      await tocar(tester, find.text('Criar senha e continuar'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('avisar compra e desfazer a remoção', (tester) async {
      final (store, servidor) = await novoStore();
      await store.entrar('ana@email.com', 'ana12345');
      store.chegadasParaCelebrar();
      await abrirApp(tester, store);

      await tester.tap(find.text('Avisar compra').last);
      await tester.pumpAndSettle();
      await tocar(tester, find.text('Avisar portaria'));
      await tester.pumpAndSettle();
      expect(find.text('Informe a loja'), findsOneWidget); // não aceita vazio

      await tester.enterText(find.widgetWithText(TextField, 'Loja ou remetente'), 'Kabum');
      await tester.enterText(find.widgetWithText(TextField, 'O que é?'), 'Teclado');
      await tocar(tester, find.text('Avisar portaria'));
      await tester.pumpAndSettle();
      expect(find.text('Kabum'), findsOneWidget);
      expect(servidor.tabelas['pre_cadastros']!.length, 2);

      await tocar(tester, find.byTooltip('Remover').first);
      await tester.pumpAndSettle();
      expect(servidor.tabelas['pre_cadastros']!.length, 1);
      await tester.tap(find.text('DESFAZER'));
      await tester.pumpAndSettle();
      expect(servidor.tabelas['pre_cadastros']!.length, 2);
    });

    testWidgets('sair pelo Perfil volta para o login', (tester) async {
      final (store, _) = await novoStore();
      await store.entrar('ana@email.com', 'ana12345');
      store.chegadasParaCelebrar();
      await abrirApp(tester, store);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tocarNoPerfil(tester, 'Sair');
      await tester.pumpAndSettle();
      expect(store.conta, isNull);
      expect(find.text('Entrar'), findsWidgets);
    });

    testWidgets('modo escuro pelo Perfil', (tester) async {
      final (store, _) = await novoStore();
      await store.entrar('ana@email.com', 'ana12345');
      store.chegadasParaCelebrar();
      await abrirApp(tester, store);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tocarNoPerfil(tester, 'Escuro');
      await tester.pumpAndSettle();
      expect(store.modoTema, ThemeMode.dark);
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    });
  });
}

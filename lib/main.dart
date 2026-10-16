import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dados/servidor.dart';
import 'dados/store.dart';
import 'tema.dart';
import 'telas/login.dart';
import 'telas/primeiro_acesso.dart';
import 'telas/principal.dart';

/// Condexpress – app do morador.
/// Os comentários [REQ-xx], [RNF xx] e [RD xx] indicam os requisitos do
/// documento do Projeto Integrado; [H1]…[H10], as heurísticas de Nielsen.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Tela cheia: esconde as barras do sistema (deslize da borda para mostrá-las)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final store = await AppStore.carregar(await ServidorSupabase.iniciar());
  runApp(CondexpressApp(store: store));
}

class CondexpressApp extends StatelessWidget {
  const CondexpressApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      notifier: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final conta = store.conta;
          return MaterialApp(
            title: 'Condexpress',
            debugShowCheckedModeBanner: false,
            theme: TemaCondexpress.claro(),
            darkTheme: TemaCondexpress.escuro(),
            themeMode: store.modoTema,
            home: conta == null
                ? const TelaLogin()
                : conta.perfil.deveTrocarSenha
                    ? const TelaPrimeiroAcesso()
                    : const TelaPrincipal(),
          );
        },
      ),
    );
  }
}

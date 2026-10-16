# Condexpress – App do Morador (Flutter/Dart)

App do morador do projeto **Condexpress**, feito em **Dart + Flutter**, como pede o RNF 05
do documento do Projeto Integrado. Roda em **Android**, **iPhone** e **navegador**.

Usa o **mesmo banco de dados (Supabase)** do site da portaria e do síndico
(https://condexpress.netlify.app): quando o porteiro registra uma encomenda no site,
ela aparece na hora no app do morador, com a animação de chegada e a foto do pacote.
O app abre em **tela cheia** (as barras do celular aparecem ao deslizar a borda).

## O que o morador consegue fazer

| Tela | Funcionalidades | Requisitos |
|---|---|---|
| Login | Logo, e-mail e senha, "Esqueci minha senha", "Continuar com Google" | REQ-03 |
| Primeiro acesso | Troca da senha provisória gerada pela administração, com medidor de força, ou vínculo com o Google | REQ-03 |
| Início | Encomendas na portaria em destaque, rastreamento em etapas, código de retirada, busca e filtros, pedido de avaliação | REQ-05, RD 03 |
| Aviso de chegada | Cartão animado (confetes, caixa pulando, vibração) quando chega um pacote | REQ-07 |
| Detalhes | Código, foto do pacote, linha do tempo, quem recebeu e quem retirou | REQ-04, REQ-05 |
| Notificações | Sino com contador e lista de avisos | REQ-07 |
| Avisar compra | Pré-cadastro de compras a caminho, com "Desfazer" | REQ-11 |
| Comunidade | Publicar e responder mensagens | REQ-09 |
| Perfil | Foto (galeria ou câmera), preferência de entrega, pessoas autorizadas, modo escuro, alterar senha, conta Google, avaliação | REQ-12, REQ-13 |

**Contas:**
- Moradores são cadastrados pelo síndico no site e recebem uma senha provisória:
  no primeiro acesso, o app pede para criar a própria senha.
- Porteiros e síndico não entram no app: eles usam o site.

## Identidade visual

A logo está em `assets/marca/` (versões clara e escura) e em `marca/` (SVG e PNG). Ela usa
a mão e as letras da logo original do grupo, com "EXPRESS", "ENVIO" e "CONDOMÍNIO" corrigidos;
`marca/fonte/LEIA-ME.txt` explica como foi montada. Cores: verde-água `#008484`, laranja `#CC4818`, amarelo `#E8A632` e
verde-água claro `#66C6C2`. Os ícones do app (Android, iPhone e web) usam o símbolo da logo.

## Como rodar no Android Studio

1. **Instale o Flutter:** siga https://docs.flutter.dev/get-started/install (Windows, macOS ou Linux).
2. **Instale o Android Studio:** https://developer.android.com/studio. Durante a instalação, aceite o **Android SDK**.
3. No Android Studio, abra **Settings → Plugins** e instale os plugins **Flutter** e **Dart**.
4. **File → Open** e escolha esta pasta (`condexpress_morador`).
5. Num terminal, dentro da pasta, rode: `flutter pub get`
6. Escolha onde rodar:
   - **Emulador:** em **Device Manager**, crie um celular virtual (ex.: Pixel 8).
   - **Celular de verdade:** ative **Opções do desenvolvedor → Depuração USB** e ligue o cabo.
7. Clique em **Run ▶** (ou rode `flutter run` no terminal).

Para conferir se está tudo instalado, rode `flutter doctor`.

### Gerar o APK para instalar em qualquer Android

```bash
flutter build apk --release
```

O arquivo fica em `build/app/outputs/flutter-apk/app-release.apk`. Envie para o celular e
toque nele para instalar (o Android pede para permitir "fontes desconhecidas").

### Rodar no navegador (sem Android Studio)

```bash
flutter run -d chrome
```

## Login com Google no celular

No navegador funciona direto. No Android e no iPhone, o Google devolve a pessoa ao app pelo
endereço `br.com.condexpress.morador://login-callback`. Ele precisa estar liberado no Supabase:
**Authentication → URL Configuration → Redirect URLs → Add URL**.

## Verificação

```bash
flutter analyze   # análise estática do código
```

## Organização do código

```
lib/
├── main.dart                 → inicia o app e escolhe a tela (login, primeiro acesso ou principal)
├── tema.dart                 → cores e tema claro/escuro (mesma identidade do protótipo em HTML)
├── dados/
│   ├── modelos.dart          → Encomenda, Notificação, Morador… (no formato do banco)
│   ├── store.dart            → estado do app e regras (login, senha, compras, avaliação…)
│   └── servidor.dart         → conversa com o Supabase (login, tabelas, fotos, tempo real)
├── telas/                    → uma tela por arquivo
├── widgets/
│   ├── componentes.dart      → peças reutilizáveis (avatar, etiquetas, rastreamento, código…)
│   └── aviso_chegada.dart    → animação de encomenda chegando
└── util/formatos.dart        → datas e textos ("há 2 h", iniciais…)
```

Os comentários `[REQ-xx]`, `[RD xx]` e `[H1]…[H10]` no código ligam cada parte aos requisitos
do documento e às heurísticas de Nielsen.

## Segurança e limites

- O login, as senhas e as regras de quem vê o quê ficam no Supabase. O morador só recebe as
  próprias encomendas, avisos e compras; a foto do pacote abre por um link temporário.
- A chave que está em `lib/dados/servidor.dart` é a pública ("publishable"). Nunca coloque
  no app a chave secreta (service_role).
- **Notificação com o app fechado** (push) ainda não existe: o aviso aparece quando o app
  está aberto ou ao abrir. Próximo passo: OneSignal ou Firebase Cloud Messaging.

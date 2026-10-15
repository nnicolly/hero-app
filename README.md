# Trabalho 1 — Agentes

Aplicativo Android desenvolvido em Flutter/Dart para a disciplina de Programação para Dispositivos Móveis. Inclui catálogo dos 563 super-heróis, detalhes, contrato diário, recrutamento, esquadrão, missões e recompensas permanentes. Os dados ficam disponíveis offline depois da primeira sincronização; imagens ainda não carregadas podem usar uma imagem de substituição.

## Estrutura

```text
app_herois/
  android/             Configuração Android e Gradle Wrapper
  lib/                 Modelos, dados, repositories, providers, telas e widgets
  test/                Testes locais
  integration_test/    Testes no dispositivo, com bancos isolados
  pubspec.yaml
  pubspec.lock
backend/
  db.json              Catálogo completo exposto em /heroes
  package.json
  package-lock.json
```

`materiais/`, `.tools/`, dependências instaladas, caches, builds, bancos locais, configurações de IDE e credenciais ficam fora do Git. Os materiais de estudo permanecem no computador de desenvolvimento, mas não são necessários para executar o projeto.

`backend/all.json` é uma cópia local opcional do download original, ignorada pelo Git. Seus 563 objetos foram comparados integralmente com `db.json.heroes`; apenas `db.json` precisa ser distribuído. Não altere os personagens para preparar o esquadrão dos testes.

## Tecnologias e requisitos

- Flutter com Dart compatível com `^3.13.5`; ambiente validado com Flutter 3.47.7 e Dart 3.13.5.
- Android SDK configurado para Flutter; use `flutter doctor` para conferir o ambiente e as licenças. O Gradle Wrapper e suas configurações estão incluídos.
- Node.js e npm; ambiente validado com Node 24.21.0 e npm 11.19.0.
- Dispositivo Android físico com depuração USB autorizada, ou outro destino Android configurado.

O app utiliza Provider/ChangeNotifier, Repository, HTTP, SQLite (`sqflite` e `path`), `shared_preferences`, `cached_network_image`, `primer_progress_bar`, `awesome_dialog` e `infinite_scroll_pagination` 4.1.0. O backend utiliza `json-server` 0.17.4, restaurado pelo lockfile. Não há um servidor de autenticação ou chaves de API a configurar.

## 1. Iniciar a API

Na raiz deste repositório, abra um terminal:

```powershell
cd backend
npm ci
npm start
```

O servidor usa a porta padrão 3000 e publica `http://127.0.0.1:3000/heroes`. Mantenha esse terminal aberto. Não inicie outra instância na mesma porta. No PowerShell com execução de scripts restrita, use `npm.cmd` no lugar de `npm`.

`npm ci` restaura as versões de `package-lock.json`; `node_modules/` não deve ser versionada. O script de inicialização usa diretamente o `db.json` incluído, sem depender de `all.json` ou de um `index.js`.

## 2. Executar no celular por USB

Em outro terminal, a partir da raiz do repositório:

```powershell
adb devices
adb reverse tcp:3000 tcp:3000
cd app_herois
flutter pub get
flutter devices
flutter run -d ID_DO_DISPOSITIVO
```

Substitua `ID_DO_DISPOSITIVO` pelo identificador exibido nos comandos. O `adb` fica em `platform-tools/` no Android SDK e precisa estar no PATH, ou ser chamado pelo caminho completo da instalação local. No Linux/macOS, caso seja necessário executar o wrapper diretamente, dê permissão com `chmod +x app_herois/android/gradlew` a partir da raiz.

O app acessa `http://127.0.0.1:3000/heroes`. No celular, esse endereço chega ao computador pelo `adb reverse`; não é utilizado `10.0.2.2`. Se reconectar o cabo ou reiniciar o aparelho, confira o reverse novamente. A permissão INTERNET está no manifesto principal, e HTTP local está liberado no manifesto Debug.

Abra **Agentes** e aguarde a primeira sincronização dos 563 personagens. Depois, interrompa a API com Ctrl+C no terminal do backend e reabra o app para conferir os dados locais. Para missões, são necessários pelo menos cinco recrutados; o esquadrão suporta até 15.

## 3. Executar os testes

Dentro de `app_herois/`:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Os testes locais leem `../backend/db.json`, portanto mantenha as duas pastas na estrutura apresentada.

Para integração, deixe a API disponível, conecte o Android e configure o reverse:

```powershell
flutter test integration_test -d ID_DO_DISPOSITIVO --no-uninstall
```

Use sempre `--no-uninstall`. O runner utilizado no desenvolvimento desinstala o aplicativo por padrão e também guarda a identidade do APK anterior antes da compilação. O Gradle separa a integração em `com.example.app_herois.validation`; o aplicativo normal continua em `com.example.app_herois`. Essa separação e o parâmetro devem ser usados juntos para proteger os dados normais. Outros runners precisam ter sua configuração conferida antes de usar um aparelho com dados importantes.

Os testes preparam esquadrões e recompensas somente em bancos isolados. Não desinstale nem limpe os dados do pacote normal para testar. Capturas opcionais podem ser ativadas com `--dart-define=REVIEW_SCREENSHOTS=true`; são artefatos de validação, sem necessidade de versionamento.

## Documentação e entrega

- [Preparação e inventário do primeiro commit](PREPARACAO_GIT.md).
- [Documentação detalhada das seis etapas](app_herois/README.md).
- [Revisão da Etapa 6 e evidências de validação](app_herois/REVISAO_ETAPA_6.md).
- [Registro da revisão geral anterior](app_herois/REVISAO_FINAL.md), incluindo o incidente histórico de preservação de dados. Não representa recuperação desses dados.

Os relatórios registram verificações realizadas no ambiente de desenvolvimento. Caminhos em `build/` citados como evidência são locais e não fazem parte do repositório. Para reproduzir os resultados em outro computador, execute os comandos de validação acima.

Devem ser versionados os fontes, testes, configuração Android, ícones/recursos utilizados, Gradle Wrapper, documentação e os manifests/lockfiles do Flutter e do Node.js. Não há assets externos obrigatórios: as imagens dos personagens são carregadas pelas URLs do catálogo.

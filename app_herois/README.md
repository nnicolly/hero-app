# Agentes — Trabalho 1 (etapas 1 a 6)

Aplicativo Flutter/Dart para listar o catálogo completo do json-server. Foram lidos o enunciado e os PDFs de `materiais/`. O aplicativo abre o menu inicial com Agentes, Contrato Diário, Meu Esquadrão e Missões. Catálogo, detalhes, recrutamento, dispensa e combates estão disponíveis. As missões apresentam feedback final com AwesomeDialog e recompensam um vencedor com +1 permanente em um atributo.

## Revisão final e segurança dos testes

A revisão específica de Resultados e Melhorias está em [REVISAO_ETAPA_6.md](REVISAO_ETAPA_6.md), de 14/10/2026. A revisão geral anterior está em [REVISAO_FINAL.md](REVISAO_FINAL.md). As validações por etapa abaixo são registros históricos.

Na revisão da Etapa 6, passaram 47 testes locais e dez de integração no A55, além da formatação e análise estática. O bônus acumulado 100 → 101 → 102 foi conferido após reinício real do processo Android com a API desligada, usando exclusivamente o pacote de validação. O código de produção foi preservado.

Na revisão, foi identificado que o runner de integração do Flutter 3.47.7 desinstala o APK por padrão. Bancos com nomes diferentes não protegiam os dados normais porque o APK de testes usava o mesmo applicationId. A primeira execução desta revisão removeu o aplicativo normal; não há backup local encontrado nem confirmação dos recrutamentos/evoluções anteriores. As afirmações históricas de preservação de dados não podem ser garantidas.

O Gradle agora detecta a flag de integração enviada por `flutter test` e usa `com.example.app_herois.validation`. O aplicativo normal mantém `com.example.app_herois`. Use sempre `--no-uninstall`: este SDK guarda também a identidade do APK anterior antes de compilar, portanto a separação de pacote sozinha não basta na primeira execução. Não troque esses identificadores e não use `adb uninstall` no pacote normal. Os testes continuam usando bancos isolados.

Para repetir toda a validação, com a API disponível na porta 3000 e o A55 conectado:

```powershell
adb devices
adb reverse tcp:3000 tcp:3000
cd app_herois
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test -d ID_DO_DISPOSITIVO --no-uninstall
flutter build apk --release
```

Capturas opcionais: acrescente `--dart-define=REVIEW_SCREENSHOTS=true` ao comando de integração. Elas ficam no cache do aplicativo de validação. Não são necessárias para executar os testes. A separação de pacote é configurada para o runner `flutter test integration_test` usado neste projeto; outros runners devem ser verificados antes de usar um aparelho com dados importantes.

Para iniciar o backend existente em outro terminal, a partir da raiz do workspace:

```powershell
cd backend
npm.cmd ci
npx.cmd json-server --watch db.json --host 127.0.0.1 --port 3000
```

Não inicie uma segunda instância se o servidor já estiver rodando. O build Release depende da permissão do Windows para executar as ferramentas AOT do Flutter; consulte o relatório para o resultado neste ambiente.

## Organização

- `lib/models/hero.dart`: classe Hero, construtor, fromJson e toJson; mapas para campos aninhados e preservação de campos adicionais.
- `lib/data/hero_api.dart`: HTTP com timeout; endpoint único `http://127.0.0.1:3000/heroes`.
- `lib/data/hero_database.dart`: contrato da tabela, openDatabase/onCreate, insert, query e paginação com limit/offset.
- `lib/repositories/hero_repository.dart`: coordena API, gravação do catálogo inteiro e consultas locais.
- `lib/providers/hero_provider.dart`: ChangeNotifier, carregamento, mensagens, sincronização e PagingController da versão 4.1.0.
- `lib/screens/agents_screen.dart`: Consumer, PagedListView, carregamento e nova tentativa.
- `lib/widgets/hero_card.dart`: cards com nome, aparência, powerstats e CachedNetworkImage.
- `lib/main.dart`: MaterialApp e ChangeNotifierProvider na raiz.

## Fluxo dos dados

Sem cache, a primeira abertura busca `/heroes` sem `_limit` e salva o catálogo inteiro antes da listagem. A tabela `heroes` contém `id`, `name` e `complete_json` (TEXT), preservando todas as informações do JSON. A gravação ocorre em uma transação: uma falha não substitui o cache anterior por um catálogo parcial.

A interface consulta apenas o SQLite em páginas de 20, ordenadas por ID, até o fim do catálogo. Os IDs da API não precisam ser consecutivos. Com 563 heróis, são 28 páginas de 20 e uma última de 3.

Nas próximas aberturas, o catálogo local é utilizado imediatamente, sem aguardar a rede. O botão de atualização busca e grava novamente o catálogo completo. Se a atualização falhar, o app informa a falha e continua usando o cache. Provider gerencia estado e paginação; Repository centraliza os dados. A tela não faz HTTP nem SQL.

A Aula 06 usa FutureBuilder, e a Aula 08 demonstra o helper chamado pelo widget. Aqui as mesmas operações básicas passam pelo Repository e ChangeNotifier, conforme solicitado.

## Executar no Galaxy A55

Com o servidor existente na porta 3000 e o celular conectado por USB:

```powershell
adb reverse tcp:3000 tcp:3000
cd app_herois
flutter pub get
flutter run -d ID_DO_DISPOSITIVO
```

Se `adb` não estiver no PATH, localize `adb.exe` na pasta `platform-tools/` do Android SDK instalado neste computador. Substitua `ID_DO_DISPOSITIVO` pelo identificador mostrado por `adb devices`.

A permissão INTERNET está no manifesto principal. HTTP sem TLS está liberado somente no manifesto debug. Não foi utilizado o endereço do emulador. Para mudar o endpoint, use `--dart-define=HEROES_API_URL=http://ENDERECO:3000/heroes`.

## Testar online e offline

1. Abra o app com o backend disponível; confira o total de 563 agentes.
2. Role a lista: novos registros vêm do SQLite em páginas de 20. A mensagem de fim indica o término do catálogo.
3. Depois da sincronização, interrompa o servidor com Ctrl+C no terminal dele (ou remova temporariamente o reverse).
4. Feche e reabra o app sem limpar seus dados: os 563 agentes devem continuar acessíveis.
5. Toque em atualizar com o servidor indisponível: a mensagem deve indicar o uso do catálogo salvo.
6. Restaure o servidor/reverse e atualize novamente.

As imagens ficam no cache próprio do CachedNetworkImage. Imagens nunca carregadas podem mostrar o ícone de substituição offline; o catálogo textual completo permanece disponível.

```powershell
flutter analyze
flutter test
flutter test integration_test/catalog_test.dart -d ID_DO_DISPOSITIVO --no-uninstall
```

`test/catalog_test.dart` usa o JSON real de `../backend/db.json` para verificar serialização e estados do Provider. O teste de integração utiliza a API HTTP real e SQLite no Android, compara o JSON completo dos 563 registros, confere todas as páginas e reabre o banco com API simulada como indisponível. Utiliza o arquivo separado `catalog_validation.db`.

## Validação da etapa 1

- `flutter analyze`: sem problemas encontrados.
- Aplicação normal executada no Samsung Galaxy A55: primeira sincronização, cards e imagens conferidos visualmente, sem overflow observado.
- API desconectada removendo temporariamente o reverse: aplicativo fechado e reaberto com os 563 agentes acessíveis. Reverse restaurado após o teste.
- SQLite real do aparelho comparado ao backend: 563 JSONs completos idênticos, 29 páginas e 563 IDs únicos.
- `flutter test integration_test/catalog_test.dart -d ID_DO_DISPOSITIVO --no-uninstall`: passou, incluindo persistência, paginação completa, falha de atualização, reabertura offline e chegada ao fim da interface.
- `flutter test` no computador: bloqueado pela política de Controle de Aplicativo do Windows ao iniciar `flutter_tester.exe`; os quatro testes locais não puderam executar nesse ambiente.

A listagem da etapa 1 foi preservada. Nenhum commit foi realizado.


## Etapa 2 — Detalhes do Agente

Toque em qualquer card para abrir `AgentDetailsScreen` com `Navigator.push` e `MaterialPageRoute`, conforme a Aula 04. Voltar remove somente a rota de detalhes: o PagingController e a posição do catálogo continuam preservados.

- Novo arquivo: `lib/screens/agent_details_screen.dart`, com Consumer, carregamento, nova tentativa, ListView, Cards e imagem grande com CachedNetworkImage.
- `HeroProvider` reutilizado com selectedHero, loadingDetails, detailsError e loadDetails. Os estados de detalhes são independentes do carregamento e da paginação do catálogo.
- `HeroRepository.getById` prefere `/heroes/{id}` e recupera o mesmo ID no SQLite se a API falhar. As informações locais correspondem à última sincronização do catálogo; a consulta de detalhes não substitui o catálogo.
- `HeroApi.fetchById` reutiliza o método HTTP interno que também atende fetchAll. Timeout de 15 segundos, status HTTP e ID são verificados.
- `HeroDatabase.getById` utiliza query, where e whereArgs, conforme a Aula 08.
- `Hero` aceita seções ausentes e fornece largeImage, preferindo a imagem lg.
- `HeroCard` recebeu o toque para navegação. Não foram adicionadas dependências.

Os detalhes exibem identificação, os seis powerstats, biografia, aparência, trabalho, conexões, URLs de imagens e eventuais campos adicionais. Cada atributo tem sua própria PrimerProgressBar na escala 0–100, com o valor original em texto. Dados ausentes aparecem como “Não informado”; imagens indisponíveis apresentam mensagem e ícone.

Para testar no celular:

1. Com a API disponível e o reverse configurado, execute `flutter run -d ID_DO_DISPOSITIVO`.
2. Role o catálogo, abra diferentes agentes e confira nome, imagem grande, seis barras e todas as seções.
3. Volte pelo botão da AppBar ou do Android; confira que a listagem permanece na mesma posição.
4. Depois de sincronizar o catálogo, desligue o servidor. Abra novamente os detalhes de vários agentes: os dados devem vir do SQLite.
5. Uma imagem grande ainda não carregada pode estar indisponível offline, mesmo se a miniatura já estiver em cache.

O teste de integração disponível cobre também navegação para personagens diferentes, seis barras, preferência pela API, fallback SQLite, erro sem dados e preservação da posição do catálogo. As demais funcionalidades são descritas nas etapas seguintes deste documento.


### Validação da etapa 2

- `flutter analyze`: sem problemas encontrados.
- `flutter test`: quatro testes locais aprovados nesta execução.
- `flutter test integration_test/catalog_test.dart -d ID_DO_DISPOSITIVO --no-uninstall`: dois testes de integração aprovados, cobrindo as etapas 1 e 2.
- No aplicativo normal, A-Bomb foi aberto online e Abe Sapien foi aberto com o reverse da API temporariamente removido, confirmando os detalhes recuperados do SQLite. Imagem grande e layout foram inspecionados no Galaxy A55. A porta 3000 foi restaurada.
- A preservação da posição do catálogo e a presença das seis barras foram verificadas pelo teste de integração.


## Etapa 3 — Contrato Diário e Recrutamento

Acesse pelo ícone de calendário na AppBar de Agentes (tooltip “Contrato Diário”). A navegação usa Navigator.push e MaterialPageRoute. A tela mostra apenas nome, imagem, seis powerstats e recrutamento, além das mensagens sobre a operação.

Arquivos criados:

- `lib/repositories/squad_repository.dart`: consulta os membros e centraliza o recrutamento local.
- `lib/providers/squad_provider.dart`: ChangeNotifier com agente do dia, membros, carregamento, recrutamento e mensagens; Consumer acompanha as mudanças.
- `lib/screens/daily_contract_screen.dart`: nova tela com CachedNetworkImage, barras e botão Recrutar para o Esquadrão.
- `lib/widgets/hero_powerstats.dart`: as mesmas seis barras de primer_progress_bar, compartilhadas com Detalhes do Agente.
- `test/daily_contract_test.dart`: testes de sorteio, persistência no mesmo dia, mudança da data e catálogo vazio.

Arquivos modificados: `main.dart`, `data/hero_database.dart`, `repositories/hero_repository.dart`, `screens/agents_screen.dart`, `screens/agent_details_screen.dart`, `integration_test/catalog_test.dart` e este README. Nenhuma biblioteca adicional foi instalada no app.

### Sorteio e shared_preferences

HeroRepository.getDailyHero usa a data local do dispositivo (DateTime.now), formatada como ano-mês-dia. As preferências guardam `daily_contract_date` e `daily_contract_hero_id`. No mesmo dia, o ID é recuperado do SQLite; quando a data muda, Random escolhe uma posição entre todos os registros locais e persiste a nova seleção. O ID é salvo antes de confirmar a data. Recrutar não altera essas preferências nem sorteia outro herói.

O sorteio utiliza somente SQLite, sem HTTP e sem presumir que os IDs são consecutivos. Com o catálogo sincronizado, todos os 563 agentes participam do sorteio. Sem catálogo local, a tela orienta a abrir Agentes e sincronizar.

### SQLite e recrutamento

O banco passou da versão 1 para a versão 2. onUpgrade cria apenas `squad_members`; a tabela heroes e seus 563 registros são preservados, sem DROP TABLE. Uma instalação nova cria ambas as tabelas em onCreate.

A tabela squad_members possui hero_id como chave primária e complete_json como TEXT. Cada membro recebe uma cópia completa dos seus dados, separada do catálogo, preparando a persistência de progressão futura sem implementar melhorias agora.

A mesma instância de HeroDatabase é compartilhada pelos repositories na raiz do app. SquadRepository solicita a persistência; SquadProvider controla os estados e notifica a interface. A tela não executa SQL nem HTTP.

Dentro de uma transação SQLite, o recrutamento verifica se o ID já existe, consulta a quantidade de membros e insere somente se houver menos de 15. A chave primária reforça a unicidade. A transação impede ultrapassar a capacidade mesmo com solicitações concorrentes. O botão fica desabilitado durante a operação, para um agente já recrutado ou quando o esquadrão está cheio.

### Testar no Galaxy A55

1. Com USB e API na porta 3000, configure `adb reverse tcp:3000 tcp:3000` e execute `flutter run -d ID_DO_DISPOSITIVO` em app_herois.
2. Confira os 563 agentes e abra Contrato Diário pelo calendário.
3. Veja o nome, imagem e seis barras. Role até o botão de recrutamento.
4. Volte e reabra o contrato: o personagem deve continuar o mesmo.
5. Recrute e confira a mensagem e o botão desabilitado. O personagem permanece o mesmo depois do recrutamento.
6. Feche e reabra o app, sem limpar os dados: contrato e recrutamento continuam salvos.
7. Depois de sincronizar o catálogo, desligue o backend e repita: sorteio e recrutamento devem continuar funcionando pelo SQLite. Imagens nunca carregadas podem mostrar o ícone de substituição offline.

A mudança de data e o limite de 15 são simulados pelos testes; não é necessário alterar a data do celular ou esperar vários dias. Os testes de integração usam bancos e chaves de preferências separados dos dados normais do aplicativo.

```powershell
flutter analyze
flutter test
flutter test integration_test/catalog_test.dart -d ID_DO_DISPOSITIVO --no-uninstall
```

### Validação da etapa 3

- flutter analyze: sem problemas encontrados.
- flutter test: sete testes locais aprovados.
- Testes de integração no Galaxy A55: quatro testes aprovados, cobrindo as três etapas.
- Migração real de um SQLite versão 1 com 563 JSONs completos para a versão 2: catálogo preservado integralmente.
- Sorteio persistido no mesmo dia, fechamento/reabertura do banco com recarga das preferências e mudança de data simulada.
- Recrutamento pelo botão, duplicidade impedida, permanência do agente do dia após recrutar e persistência dos membros após reabertura.
- Requisições concorrentes de recrutamento limitadas a 15 membros, sem IDs duplicados; sincronizar o catálogo preserva o esquadrão.
- Sorteio e recrutamento com API simulada como indisponível, mensagem de catálogo vazio e regressões de catálogo/detalhes verificadas.

A etapa 3 acrescentou contrato diário e recrutamento. Nenhum commit foi feito.

Conferência adicional no aplicativo normal do Galaxy A55: layout e seis barras inspecionados, sorteio do ID 253 mantido após fechar e reabrir com a API desconectada. SQLite normal conferido na versão 2 com os 563 heróis preservados. A porta 3000 foi restaurada. Os recrutamentos dos testes foram feitos nos bancos isolados; o esquadrão normal permaneceu vazio.


## Etapa 4 — Meu Esquadrão e Detalhes do Meu Agente

O menu inicial agora apresenta as quatro opções exigidas: Agentes, Contrato Diário, Meu Esquadrão e Missões. Na etapa 4, Missões tinha uma mensagem provisória, substituída pela tela de missões na etapa 5. O calendário da AppBar de Agentes continua abrindo Contrato Diário.

Meu Esquadrão consulta exclusivamente squad_members pelo SquadRepository e SquadProvider. A listagem usa ListView.builder, pois possui no máximo 15 agentes. Cada card exibe nome, miniatura com CachedNetworkImage e o maior dos seis powerstats. Empates usam o primeiro atributo na ordem intelligence, strength, speed, durability, power, combat; valores ausentes são tratados sem inventar um atributo.

Tocar no card abre Detalhes do Meu Agente com Navigator.push e MaterialPageRoute. Essa tela utiliza o JSON completo do membro salvo no SQLite, funcionando sem consultar a API e preservando o espaço separado para progressão futura. O conteúdo dos detalhes, incluindo imagem grande, identificação, seis barras, biografia, aparência, trabalho e conexões, foi extraído para HeroDetailsContent e é compartilhado com Detalhes do Agente. As barras continuam usando HeroPowerstats e primer_progress_bar.

### Dispensa

O botão Dispensar do Esquadrão aparece após os atributos. AwesomeDialog apresenta a pergunta e os botões Confirmar/Cancelar. Cancelar, voltar ou fechar a confirmação não executa a exclusão.

Confirmar chama SquadProvider.dismissMember, que solicita a operação ao SquadRepository. HeroDatabase usa delete com where/whereArgs exclusivamente em squad_members. A tabela heroes permanece intacta. Após o sucesso, o Provider remove o integrante de seu estado e chama notifyListeners; Navigator.pop retorna à listagem já atualizada. A vaga é liberada, e o agente pode voltar a ser recrutado. Falhas de gravação mantêm os dados da interface e apresentam uma mensagem amigável.

### Arquivos

Criados:

- `lib/screens/home_screen.dart`: menu inicial.
- `lib/screens/squad_screen.dart`: listagem local e estado vazio.
- `lib/screens/squad_agent_details_screen.dart`: detalhes do recrutado e confirmação de dispensa.
- `lib/widgets/squad_card.dart`: card com maior atributo.
- `lib/widgets/hero_details_content.dart`: conteúdo compartilhado dos detalhes.
- `test/squad_test.dart`: testes do maior atributo e estados de dispensa.

Modificados: `main.dart`, `models/hero.dart`, `data/hero_database.dart`, `repositories/squad_repository.dart`, `providers/squad_provider.dart`, `screens/agent_details_screen.dart`, `integration_test/catalog_test.dart` e este README. A versão do SQLite continua 2, e nenhuma dependência adicional foi necessária.

### Testar no Galaxy A55

```powershell
adb reverse tcp:3000 tcp:3000
cd app_herois
flutter run -d ID_DO_DISPOSITIVO
```

1. No menu, abra Meu Esquadrão. Se estiver vazio, use Abrir Contrato Diário para recrutar um agente.
2. Volte ao esquadrão e confira nome, miniatura e maior atributo do recrutado.
3. Toque no card, confira as seis barras e todas as seções, e role até Dispensar do Esquadrão.
4. Cancele a confirmação: o membro deve continuar presente.
5. Abra a confirmação novamente e confirme: o aplicativo deve voltar à lista com uma vaga liberada.
6. Abra Agentes e confira que o catálogo ainda possui 563 personagens.
7. Desligue o backend após sincronizar e repita a consulta do esquadrão e dos detalhes. Imagens já carregadas podem usar o cache; imagens nunca carregadas podem ficar indisponíveis offline.

Os testes de integração utilizam bancos e chaves de preferências isolados. Eles verificam também novo recrutamento depois da dispensa e atualização da lista sem reiniciar o app.

Somente a etapa 4 foi implementada nesta execução. Nenhuma lógica de missões, combates ou melhorias de atributos foi acrescentada. Nenhum commit foi feito.

### Validação da etapa 4

- flutter analyze: sem problemas encontrados.
- flutter test: onze testes locais aprovados.
- Testes de integração no Galaxy A55: cinco testes aprovados, cobrindo as quatro etapas.
- Menu com quatro entradas e mensagem temporária de Missões verificados.
- Listagem exclusiva dos 15 recrutados, miniatura, nome e maior atributo verificados.
- Detalhes do membro com conteúdo completo e seis barras; consulta do esquadrão/detalhes sem chamadas à API verificada.
- Confirmação com os botões de AwesomeDialog, cancelamento sem exclusão e confirmação com retorno à lista atualizada verificados.
- Dispensa libera uma vaga; novo recrutamento atualiza a listagem sem reiniciar.
- Catálogo preservado com 563 JSONs completos e agente dispensado ainda consultável no cache.
- Mensagem de esquadrão vazio, falha de dispensa, empate/ausência de atributos e regressões das etapas anteriores cobertos pelos testes.

No aplicativo normal, o menu com quatro entradas e a tela Meu Esquadrão foram inspecionados visualmente no Galaxy A55 com a API temporariamente desconectada. O redirecionamento da porta 3000 foi restaurado. A confirmação e exclusão de membros foram executadas apenas no banco isolado dos testes.

## Etapa 5 — Missões e Combates

Foram consultadas novamente as páginas 10–12 do enunciado e as aulas de Dart, layouts, navegação, listas e SQLite. O menu Missões abre MissionsScreen com Navigator.push e MaterialPageRoute. A tela consulta os membros locais e desabilita Iniciar Missão quando houver menos de cinco agentes.

MissionProvider recebe os mesmos HeroRepository e SquadRepository usados pelas etapas anteriores, compartilhando a instância de HeroDatabase definida em main.dart. Iniciar a missão recarrega os membros e lê o catálogo por countCachedHeroes/getPage, exclusivamente do SQLite. Não há HTTP, outro banco, migração ou persistência do andamento.

### Sorteio e combate

Random.nextInt(3) + 3 escolhe entre três, quatro e cinco rounds. Antes do sorteio de inimigos, os IDs do esquadrão são excluídos dos candidatos obtidos do catálogo. Isso mantém a seleção aleatória entre todos os inimigos válidos e evita repetir sorteios inválidos. Em cada rodada, Random escolhe um candidato e um dos seis atributos. O mesmo inimigo pode aparecer em outras rodadas.

A tela mostra rodada/total, placar, nome e imagem do inimigo com CachedNetworkImage e atributo dominante, sem revelar seus valores antes do confronto. GridView.builder apresenta os agentes em três colunas, com até cinco linhas; cada item tem nome e imagem circular. A seleção recebe borda e cor de destaque. Os utilizados ficam apagados, com nome riscado e toque desabilitado.

Confirmar escalação compara somente o valor real do atributo sorteado: maior gera Vitória, menor gera Derrota e igual gera Empate. Se um atributo estiver ausente ou inválido, uma mensagem explica o problema; não é inventado um valor nem consumido o agente.

O Provider guarda IDs utilizados em um Set, bloqueia confirmações repetidas assim que registra o resultado e atualiza contadores com notifyListeners. O resultado da rodada aparece em um AlertDialog básico. Ao fechar com Entendi, o app avança automaticamente e volta ao topo para mostrar o novo inimigo. A última rodada leva ao resumo provisório, que permite iniciar outra missão ou voltar para Missões. Uma nova missão limpa contadores, resultados, seleção e IDs utilizados.

MissionRoundResult guarda em memória o round, agente, inimigo, atributo, valores e resultado. MissionProvider.results e victoriousAgents permitem consultar os participantes vitoriosos na próxima etapa. Nenhum atributo permanente é alterado; nenhum membro é dispensado durante o combate. Recompensas, histórico e diálogo final de sucesso/fracasso não foram implementados.

### Arquivos desta etapa

Criados:

- lib/models/mission_round_result.dart
- lib/providers/mission_provider.dart
- lib/screens/missions_screen.dart
- lib/screens/mission_battle_screen.dart
- test/mission_test.dart
- integration_test/mission_test.dart

Modificados: lib/main.dart, lib/screens/home_screen.dart, integration_test/catalog_test.dart e README.md. Os repositories, banco e funcionalidades anteriores não precisaram de alterações. Nenhuma dependência foi acrescentada.

### Testar no Samsung Galaxy A55

1. Execute o backend e configure adb reverse tcp:3000 tcp:3000.
2. Em app_herois, execute flutter run -d ID_DO_DISPOSITIVO.
3. Sincronize Agentes uma vez e mantenha os dados do aplicativo.
4. Com menos de cinco recrutados, abra Missões: a mensagem deve explicar o mínimo e o botão deve estar desabilitado.
5. Com cinco ou mais, inicie e confira a quantidade sorteada de rounds.
6. Selecione um agente no grid e confirme; leia o resultado e toque em Entendi. Confira o placar e o bloqueio do agente utilizado.
7. Termine as rodadas e use Nova Missão para conferir que todos os agentes podem ser utilizados novamente.
8. Desligue o backend e repita a missão: os dados vêm do SQLite. Imagens nunca carregadas podem mostrar o ícone de substituição offline.

Os testes preparam cinco ou quinze membros somente em bancos isolados; não é necessário esperar cinco contratos diários para executar a validação automatizada, e o esquadrão normal não é alterado.

Comandos de verificação:

```powershell
flutter analyze
flutter test
flutter test integration_test/mission_test.dart -d ID_DO_DISPOSITIVO --no-uninstall
flutter test integration_test/catalog_test.dart -d ID_DO_DISPOSITIVO --no-uninstall
```

### Validação da etapa 5

- flutter analyze: nenhum problema encontrado após os ajustes finais.
- flutter test: 18 testes locais aprovados, incluindo sete novos testes de missões.
- flutter test integration_test/mission_test.dart -d ID_DO_DISPOSITIVO --no-uninstall: um teste aprovado no Galaxy A55 com SQLite real e API simulada como indisponível.
- flutter test integration_test/catalog_test.dart -d ID_DO_DISPOSITIVO --no-uninstall: cinco testes aprovados de regressão das etapas 1–4, com a navegação de Missões atualizada.
- Testes locais verificaram as três durações, sorteio dos seis atributos, vitória/derrota/empate com valores do JSON real, exclusão de inimigos do esquadrão, uso único, confirmações duplicadas, contadores, encerramento, reinicialização, falhas locais e atributo ausente.
- No A55 foram verificados o bloqueio com quatro membros, início com quinze, grid de três colunas, imagens, ausência de atributos numéricos do inimigo antes do confronto, seleção, confirmação, apresentação de resultados, avanço entre rounds, placar, resumo e reutilização em nova missão.
- A missão não fez nenhuma chamada à API; todos os 563 JSONs e os quinze membros permaneceram idênticos após os confrontos.
- O primeiro teste de interface foi ajustado para rolar até o botão antes de verificá-lo. A execução final passou sem exceções de widgets.

Os testes executaram os recrutamentos e confrontos em bancos separados. A etapa 6 não foi implementada e nenhum commit foi feito.
O aplicativo normal atualizado foi instalado e aberto no Galaxy A55. A tela inicial de Missões foi conferida visualmente, com o bloqueio correto para o esquadrão normal vazio. A abertura foi feita com a API temporariamente desconectada; a porta 3000 foi restaurada. Os membros normais não foram alterados. A ferramenta de leitura dos PDFs e as capturas temporárias foram removidas, preservando materiais/.

## Etapa 6 — Recompensas e feedback final

Foi relida a página 13 do enunciado e consultado o padrão de update com where/whereArgs da Aula 08. As regras de sorteio, escalação, combate e recrutamento das etapas anteriores foram preservadas.

### Resultado e recompensa

Depois de todos os rounds, MissionProvider avalia a maioria absoluta sobre o total de rounds: vitórias * 2 > total indica sucesso; derrotas * 2 > total indica fracasso; os demais casos recebem feedback neutro, incluindo empates e exatamente metade das vitórias ou derrotas.

AwesomeDialog mostra Missão Cumprida! com DialogType.success, Operação Fracassada! com DialogType.error ou Missão sem maioria com DialogType.info. Todos exibem o placar. O sucesso apresenta a imagem do agente premiado e o atributo, com valor anterior, valor novo e +1 permanente. No fracasso, a imagem de um inimigo de uma rodada perdida representa a derrota. As imagens usam CachedNetworkImage e possuem substituição quando indisponíveis.

Somente os agentes dos resultados vitoriosos entram no sorteio de recompensa. Random escolhe um único agente e um dos seis atributos. O bônus é exatamente +1, sem limitar o valor a 100. As PrimerProgressBar permitem representar o valor evoluído acima de 100 e mantêm o valor numérico visível.

### SQLite e atualização dos Providers

SquadRepository.improveAttribute chama HeroDatabase.improveMemberAttribute. Uma transação lê o JSON atual do recrutado, copia os powerstats, soma 1 somente no atributo escolhido e faz update exclusivamente em squad_members, selecionando pelo hero_id. Nenhum membro é inserido, excluído ou substituído por um herói do catálogo nessa operação.

O schema permanece na versão 2: complete_json já suporta os atributos evoluídos, portanto não foi necessária uma migração. Os demais campos do membro, outros membros e os 563 heróis de heroes permanecem intactos. Fechar e reabrir o SQLite mantém a evolução. As próximas missões consultam novamente os membros locais e usam esses valores.

MissionProvider registra a recompensa salva antes de notificar a interface. O callback configurado em main.dart chama SquadProvider.updateMember, atualizando sua cópia em memória e notificando as telas. Meu Esquadrão e Detalhes do Meu Agente continuam usando o JSON do membro, sem substituir seus atributos pelos originais da API.

### Proteção contra duplicidade e falhas

finalizing bloqueia chamadas concorrentes, reinicialização e saída da tela enquanto o bônus é salvo. finalized faz chamadas posteriores retornarem sem outro update. feedbackShown impede repetir automaticamente o diálogo após reconstruções. Ver resultado permite reabrir somente a apresentação, sem sortear ou aplicar outro bônus.

Se a gravação falhar, a tela não anuncia uma recompensa salva: mostra uma mensagem e Salvar recompensa novamente. A tentativa seguinte mantém o mesmo agente e atributo sorteados. Nova Missão limpa os estados e pode conceder uma nova recompensa se for vencida. O progresso da missão continua em memória; não foi acrescentado histórico nem recuperação de missões interrompidas.

### Arquivos desta etapa

Criados:

- test/mission_reward_test.dart
- integration_test/mission_reward_test.dart

Modificados:

- lib/data/hero_database.dart
- lib/repositories/squad_repository.dart
- lib/models/mission_round_result.dart
- lib/providers/mission_provider.dart
- lib/providers/squad_provider.dart
- lib/main.dart
- lib/screens/mission_battle_screen.dart
- lib/widgets/hero_powerstats.dart
- integration_test/mission_test.dart
- README.md

Nenhuma dependência adicional foi instalada no aplicativo e materiais/ não foi alterada.

### Como testar

1. Sincronize o catálogo em Agentes e reúna pelo menos cinco recrutados.
2. Abra Missões e conclua uma missão. Mais da metade das rodadas vencidas concede um bônus; maioria de derrotas ou ausência de maioria não concede.
3. Confira imagem, agente e atributo no diálogo final. Use Ver resultado e confirme que o valor não aumenta novamente.
4. Abra Meu Esquadrão e os detalhes do premiado. Feche e reabra o aplicativo para conferir a permanência do valor.
5. Inicie outra missão para usar os atributos evoluídos. Repita com o backend desligado após a sincronização.

Os testes automatizados usam bancos isolados e não exigem aguardar contratos diários para preparar os membros. A separação de applicationId adicionada na revisão final também é necessária para proteger o aplicativo normal.

```powershell
flutter analyze
flutter test
flutter test integration_test/mission_reward_test.dart -d ID_DO_DISPOSITIVO --no-uninstall
flutter test integration_test/mission_test.dart integration_test/catalog_test.dart -d ID_DO_DISPOSITIVO --no-uninstall
flutter run -d ID_DO_DISPOSITIVO
```

### Validação da etapa 6

- flutter analyze: nenhum problema encontrado após as correções de lint.
- flutter test: 25 testes locais aprovados, incluindo sete novos testes de recompensas.
- flutter test integration_test/mission_reward_test.dart -d ID_DO_DISPOSITIVO --no-uninstall: um teste aprovado no Galaxy A55, cobrindo sucesso, fracasso e resultado neutro com os tipos correspondentes de AwesomeDialog.
- flutter test integration_test/mission_test.dart integration_test/catalog_test.dart -d ID_DO_DISPOSITIVO --no-uninstall: seis testes de regressão aprovados.
- Sorteio exclusivo entre vencedores e dos seis atributos; bônus exato em apenas um atributo; chamadas concorrentes, reconstrução da tela e reabertura do diálogo sem duplicação; falha de gravação e repetição do mesmo sorteio verificados.
- Duas missões vencidas evoluíram a força de 100 para 101 e depois 102 no banco isolado. Ao descartar os Providers, fechar e reabrir o SQLite, o valor 102 permaneceu em Meu Esquadrão e nos detalhes/PrimerProgressBar.
- Um confronto posterior utilizou o valor evoluído 102 contra 100 do inimigo e resultou em vitória.
- Os 563 JSONs originais e todos os demais atributos/membros foram comparados e preservados. A versão do banco continuou 2; operações com agente inexistente ou atributo inválido não alteraram dados.
- As missões e recompensas não fizeram chamadas à API, utilizando o SQLite com API simulada como indisponível. O HTTP real foi usado somente para preparar o catálogo dos bancos de validação.
- Nenhuma exceção de widgets foi encontrada nos fluxos de feedback, escalação, detalhes e reinicialização.

Imagens nunca carregadas podem estar indisponíveis offline; o componente mostra a substituição correspondente. O andamento da missão continua em memória, enquanto os atributos evoluídos são persistidos no SQLite.

Somente a etapa 6 foi implementada. Os bancos e preferências normais não receberam os recrutamentos ou recompensas dos testes. Nenhum commit foi realizado; materiais/ foi preservada e a ferramenta temporária de leitura dos PDFs foi removida.
Após a validação da etapa 6, flutter run --no-resident -d ID_DO_DISPOSITIVO compilou, instalou e abriu o aplicativo normal atualizado no Galaxy A55, com o redirecionamento da API na porta 3000 configurado. A preservação dos dados anteriores não pode ser garantida, conforme o incidente do runner descrito na revisão final.

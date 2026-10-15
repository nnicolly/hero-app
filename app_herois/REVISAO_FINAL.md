# Revisão geral e validação final

Nota para compartilhamento: o identificador USB do celular foi substituído por `ID_DO_DISPOSITIVO`; os resultados históricos foram preservados.

Revisão do PDF original `materiais/Aula_12_-_Trabalho_1_-_2026.pdf`, páginas 1–14, do código das seis etapas, configuração Android, backend, dependências e testes. Sem commits, migração ou alteração de regras de negócio.

Revisão realizada em 13/10/2026 no Samsung Galaxy A55 (`ID_DO_DISPOSITIVO`), com Flutter 3.47.7. A tabela trata do comportamento funcional; o incidente de preservação de dados durante a primeira execução está registrado separadamente e impede afirmar que a revisão preservou todos os dados anteriores.

## A. Conformidade com o enunciado

| Página | Requisito do professor | Estado | Evidência/observação |
|---|---|---|---|
| 3 | Dados do superhero-api servidos com json-server local | Atendido | Backend configurado com json-server 0.17.4; endpoint real retornou 563 heróis nesta revisão. |
| 3, 14 | Design harmonioso, responsivo e funcionamento no dispositivo | Atendido | Galaxy A55 conectado; testes não encontraram exceções/overflow, incluindo fonte ampliada em 30%. Inspeção visual em conclusão. |
| 4 | Menu Agentes, Contrato Diário, Meu Esquadrão e Missões | Atendido | HomeScreen e testes de navegação das quatro opções. |
| 5 | Catálogo completo em PagedListView | Atendido | infinite_scroll_pagination 4.1.0; páginas locais de 20, última com 3, 563 IDs únicos. |
| 5, 14 | Cache completo no SQLite, preservando todos os campos | Atendido | Comparação de todos os JSONs, reabertura e tentativa de sincronização malsucedida. |
| 5 | Cards com nome, atributos/aparência e miniatura | Atendido | HeroCard usa CachedNetworkImage e informações reais do catálogo. |
| 5–6 | Toque abre detalhes; retorno preserva a listagem | Atendido | Navigator.push/MaterialPageRoute/pop e teste da posição anterior. |
| 6 | Imagem grande e todas as seções de detalhes | Atendido | Identificação, powerstats, biography, appearance, work, connections, images e campos adicionais. |
| 6 | Preferência pela API com fallback SQLite | Atendido | Teste de detalhes online/offline, consultas a personagens diferentes e erro sem dados. |
| 6 | Seis atributos com primer_progress_bar | Atendido | Seis PrimerProgressBar reais; ausências e valores evoluídos acima de 100 tratados. |
| 7, 14 | Um sorteio diário, persistindo data e ID | Atendido | shared_preferences, mesmo dia, mudança de data e reabertura dos dados. |
| 7 | Card diário com nome, imagem e powerstats | Atendido | Conteúdo do recrutado diário e indicadores da operação; sem outras seções do catálogo. |
| 7 | Recrutar no SQLite, sem duplicidade e com máximo de 15 | Atendido | Chave primária e transação; casos de duplicidade, limite e recrutamento concorrente. |
| 8 | Meu Esquadrão lista exclusivamente recrutados | Atendido | Leitura de squad_members, até 15, estado vazio e atualização após operações. |
| 8 | Nome, maior atributo e miniatura no card | Atendido | Testes do destaque, empates e dados ausentes; CachedNetworkImage. |
| 8–9 | Detalhes do Meu Agente com dados completos e imagem | Atendido | Usa o JSON persistido do membro, preservando sua evolução. |
| 9 | Dispensa com confirmação AwesomeDialog | Atendido | Confirmar/Cancelar, retorno à lista e ausência de exclusão ao cancelar. |
| 9 | Dispensa libera vaga, preservando o catálogo | Atendido | Exclusão somente em squad_members; catálogo e novo recrutamento verificados. |
| 10 | Pelo menos cinco agentes para iniciar | Atendido | Bloqueio com quatro, início com cinco/quinze e mensagem explicativa. |
| 10 | Sorteio de 3–5 rounds e atributo dominante | Atendido | Random; testes das três durações e dos seis atributos. |
| 10 | Inimigo do catálogo, fora do esquadrão | Atendido | Filtrar IDs antes de sortear preserva a seleção aleatória entre candidatos válidos; inimigos podem repetir. |
| 11 | Nome, imagem e atributo da disputa, sem valores do inimigo | Atendido | Valores são apresentados somente no resultado do confronto. |
| 11 | Escalação com nome e imagem circular em grid 3×5 | Atendido | GridView com três colunas, até 15 agentes, seleção destacada e utilizados indisponíveis. |
| 11 | Vitória/derrota/empate por comparação do atributo real | Atendido | Casos com valores reais nos seis atributos; sem multiplicadores nem resultado aleatório. |
| 12, 14 | Um round por agente na missão | Atendido | Set de IDs usados e testes de seleção repetida/confirmação duplicada. |
| 12 | Mostrar resultado, atualizar placar e avançar até o fim | Atendido | Após Entendi, avança automaticamente e mostra o novo inimigo; término e reset conferidos. |
| 13 | Sumário e AwesomeDialog de sucesso/fracasso | Atendido | Tipos success/error; neutro/info para ausência de maioria, conforme complemento da Etapa 6. |
| 13 | Vitória com mais da metade dos rounds | Atendido | Maioria absoluta; exatamente metade ou empates não geram sucesso. |
| 13 | Bônus +1 em atributo aleatório de um único vencedor | Atendido | Somente vencedores elegíveis, seis atributos, incremento exato e bloqueio de duplicação. |
| 13 | Imagem do premiado ou representação da derrota | Atendido | Sucesso mostra o premiado; fracasso mostra o inimigo de uma rodada perdida. |
| 14 | Funcionalidades locais offline após primeira carga | Atendido | Catálogo, contrato, membros, dispensa, missões e recompensas usam o mesmo SQLite; imagens inéditas têm substituição. |
| 14 | Integração das bibliotecas obrigatórias | Atendido | json-server, infinite_scroll_pagination, cached_network_image, primer_progress_bar, awesome_dialog, shared_preferences e sqflite usados nas funcionalidades correspondentes. |

Requisitos complementares das etapas: Provider/Repository simples, detalhes evoluídos, proteção de operações assíncronas, tratamento de falhas, banner DEBUG e preservação do banco real também foram incluídos na revisão. Não existem serviços extras: HTTP e SQLite estão em `lib/data`, coordenados pelos repositories; telas não executam SQL nem HTTP.

| Verificação complementar desta revisão | Estado | Observação |
|---|---|---|
| Preservar os dados reais anteriores aos testes | Não atendido na primeira execução | O runner desinstalou o pacote normal. Não há backup anterior encontrado; recrutamentos/evoluções antigos são desconhecidos. A prevenção foi corrigida e verificada para as execuções seguintes. |
| Gerar Release para o Galaxy A55 | Atendido | Build ARM64 concluído, sem instalação. O build universal encontrou um bloqueio de segurança do Windows para x64. |
| Recontratar o convocado após dispensá-lo no mesmo dia | Ambiguidade registrada | A p. 7/14 exige um sorteio por dia. Não estabelece um contador separado de recrutamentos. A regra existente foi preservada. |

## B. Problemas encontrados

| Gravidade | Problema | Comprovação |
|---|---|---|
| Crítico | O runner de integração desinstalou o aplicativo normal e removeu seu diretório de dados. | O SDK 3.47.7 usa `uninstall: true` por padrão e executa `adb uninstall` sem preservar dados. O pacote normal deixou de existir após a primeira suíte. Bancos isolados não protegiam contra a desinstalação do pacote compartilhado. Não é possível afirmar se havia esquadrão/evoluções antes da revisão. |
| Moderado | Uma consulta antiga do SquadProvider sobrescrevia dados mais recentes na interface. | Três novos testes falharam antes da correção: evolução 101 voltava a 100; recrutamento de dois membros voltava a um; carregamento do contrato sobrescrevia evolução. O SQLite não era apagado, mas a interface ficava inconsistente. |
| Moderado, ambiente | Build Release universal bloqueado pela política de Controle de Aplicativo do Windows. | O executável `android-x64-release/gen_snapshot.exe` foi bloqueado. Build apenas para ARM64 foi aprovado; não houve alteração da política de segurança. |
| Pequeno | Banner DEBUG estava desativado na inicialização. | `debugShowCheckedModeBanner: false` contrariava a instrução desta revisão. |
| Pequeno | Ferramenta temporária na raiz não tinha regra de exclusão. | O .gitignore do app não cobre uma pasta .tools irmã; foi adicionada uma regra na raiz e será removida a ferramenta usada nesta revisão. |

A descrição genérica do pubspec e os padrões Android de assinatura/nome não impedem a apresentação acadêmica; não foram alterados por preferência estética. Gradle também emite um aviso sobre a dependência transitiva `rive_native` usar o plugin Kotlin antigo. Os builds atuais passaram; atualização para um Flutter futuro não foi validada nem exigiu troca das bibliotecas obrigatórias.

## C. Correções realizadas

- SquadProvider mantém uma revisão dos membros. Leituras iniciadas antes de recrutamento, dispensa ou recompensa não substituem o estado atualizado. A solução não adiciona consultas, não muda o schema e preserva as operações existentes.
- Gradle identifica a flag do runner de integração e usa `com.example.app_herois.validation`, mantendo `com.example.app_herois` para o aplicativo normal. README exige `--no-uninstall`, pois o SDK também guarda a identidade do APK anterior antes de compilar; a separação sozinha não basta na primeira execução. Pacote separado e desinstalação desativada foram usados juntos e validados no aparelho.
- Aplicativo normal reinstalado; catálogo reconstruído com os 563 JSONs idênticos ao backend. Na instalação atual, SQLite versão 2 e esquadrão vazio; preferências de contrato anteriores não foram encontradas. Foi guardada uma cópia preventiva **posterior à reinstalação**, em `build/review-normal-backup/normal-after-reinstall.tar`. Ela não recupera dados anteriores ao incidente.
- README explica inicialização do backend, comandos de testes protegidos e retifica a garantia histórica de preservação de dados.
- Removida a configuração que ocultava o banner DEBUG; o comportamento padrão do Flutter foi restaurado.
- .gitignore da raiz exclui .tools e backend/node_modules, mantendo código, JSONs e configurações necessários à reprodução.
- Novos testes cobrem respostas antigas, descarte do Provider, rollback de catálogo inválido, escrita concorrente, atributos ausentes e substituição de imagem inacessível com fonte ampliada.
- Capturas de integração são opcionais, ativadas somente por `--dart-define=REVIEW_SCREENSHOTS=true`, e gravadas no cache comum do app de validação. O cache de código é limpo entre instalações de APKs e não servia para reunir todas as capturas. Nenhuma imagem foi inserida no aplicativo como recurso novo.

A configuração HTTP Debug foi preservada. A política nativa Android não deve ser confundida com a implementação de sockets Dart usada por package:http. Essa distinção foi conferida na [documentação oficial do Flutter](https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android). Não foi feita alteração de rede baseada em uma falha Release presumida.

## D. Arquivos desta revisão

Modificados:

- lib/main.dart
- lib/providers/squad_provider.dart
- android/app/build.gradle.kts
- integration_test/catalog_test.dart
- integration_test/mission_test.dart
- integration_test/mission_reward_test.dart
- README.md

Criados:

- ../.gitignore
- test/review_test.dart
- integration_test/review_test.dart
- integration_test/helpers/review_capture.dart
- REVISAO_FINAL.md

Não foram alterados pubspec.yaml, pubspec.lock, o schema SQLite, o backend ou materiais/. Não houve commits. Os dados normais anteriores não foram preservados pelo runner na primeira execução, conforme descrito acima.

## E. Resultados dos testes

- `flutter analyze`: nenhum problema encontrado após as correções.
- `flutter test`: 30 testes locais aprovados, incluindo os cinco cenários novos. Os três casos que reproduziram a falha de estado passaram após a correção.
- Integração completa no A55: **9 testes aprovados** (5 catálogo/contrato/esquadrão/detalhes; 1 missões; 1 recompensas; 2 integridade/imagem). A suíte foi repetida com pacote separado e `--no-uninstall`, também com 9 aprovações. São 9 casos distintos, sem somar as repetições à quantidade de testes.
- Os 563 JSONs foram comparados integralmente; 29 páginas e 563 IDs únicos; migração v1→v2; reabertura; duplicidade/limite 15; confirmação/cancelamento de dispensa; mínimo 5; grid; seis atributos; sorteios/placar; sucesso/fracasso/neutro; evolução 100→101→102; persistência e uso posterior; proteção de recompensa duplicada e repetição após falha; rollback e incrementos concorrentes verificados.
- Os fluxos locais automatizados usam uma API que lança erro quando chamada, conferindo que contrato, esquadrão, missões e recompensas não dependem de HTTP após a sincronização. Não equivale a desligar toda a internet do aparelho: imagens podem usar a rede, e a indisponibilidade delas foi testada separadamente.
- Depois da reinstalação, o banco normal tinha hash SHA-256 `238365967cf5bb51b5afee4e15b077d3497b407911e8fb671177f52994d5f92a`. Após a suíte com pacote separado e `--no-uninstall`, o hash permaneceu idêntico. Isso comprova a proteção dos dados **atuais**, não dos anteriores à primeira execução.
- Inspeção visual e botão Voltar do Android: em execução.
- `flutter build apk --release`: falhou pelo bloqueio do compilador x64 na política de Controle de Aplicativo do Windows.
- `flutter build apk --release --target-platform android-arm64`: **aprovado**, gerou `build/app/outputs/flutter-apk/app-release.apk` (~38,8 MB). Identificador normal confirmado; `libapp.so` presente para ARM64. Não foi instalado nem executado em Release.

## F. Pendências e limites

- A página 7 define um sorteio diário, não um contador separado de contratações por dia. Após dispensa, recontratar o mesmo convocado permanece possível, conforme a autorização da Etapa 4; não foi inventada uma nova restrição.
- A página 13 não define o desfecho sem maioria. O feedback neutro sem bônus foi autorizado na Etapa 6 e permanece implementado.
- Imagens nunca carregadas podem faltar offline; isso não impede as operações e os dados locais. O andamento da missão permanece em memória, como definido na Etapa 5; os atributos evoluídos são persistentes.
- A remoção de materiais/ e o commit final pertencem à etapa posterior solicitada pelo usuário. A pasta deve permanecer durante esta revisão.
- Recuperação de recrutamentos/evoluções anteriores: **pendente, sem backup anterior localizado e sem confirmação do estado anterior pelo usuário**. Não foi inventado nem reposto um esquadrão. Não é possível garantir recuperação.
- Build universal Release para x64 depende de liberação legítima da ferramenta pelo responsável pela política Windows; o APK ARM64 do A55 já foi gerado. Execução em Release, outros aparelhos/orientações e escala de fonte além do caso testado não foram validados.
- Para apresentação com missões, é necessário ter cinco recrutados no aplicativo normal. Os testes prepararam seus membros somente no pacote de validação; a instalação normal atual tem esquadrão vazio. O limite de recrutamento/sorteio não foi contornado.

## G. Avaliação final

Os requisitos funcionais examinados passaram na análise, nos testes locais, na integração Android e na geração Release ARM64. A inspeção visual final e a verificação manual do botão Voltar ainda serão registradas antes de encerrar este relatório. A revisão não cumpriu a preservação dos dados anteriores: a prevenção está corrigida, mas eventual recuperação continua sem confirmação. A apresentação de missões no aplicativo normal depende de reunir novamente pelo menos cinco agentes, se não houver outra cópia de dados disponível.

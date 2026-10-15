# Revisão da Etapa 6 — Resultados e Melhorias

Nota para compartilhamento: o identificador USB do celular foi substituído por `ID_DO_DISPOSITIVO`; os resultados históricos foram preservados.

Data: 14/10/2026. Referência: Trabalho 1, páginas 1–14, especialmente 10–14. Consultados os slides das Aulas 02–06, 08 e 09: modelos/mapas, widgets, Future/async/await, ciclo de vida, Navigator, HTTP, SQLite e ListView. A persistência continua usando query/update com whereArgs e transação, sem nova arquitetura ou dependência.

## 1. Resultado geral

**A Etapa 6 atende aos requisitos funcionais examinados do enunciado.** O código de produção foi examinado antes dos testes e não precisou ser alterado. Foram identificadas lacunas de cobertura, ampliadas nos testes existentes. Os 47 testes locais, os dez testes de integração e a verificação de reinício real do processo Android passaram. Não foi identificada funcionalidade obrigatória incompleta nesta etapa.

As recompensas pertencem a `squad_members.complete_json`, separadas dos 563 JSONs de `heroes`. O progresso da missão é mantido em memória, conforme a implementação existente. Não foi criado histórico nem recuperação de missões interrompidas.

## 2. Problemas identificados e ajustes

| Tipo | Arquivo/método | Constatação e ação |
|---|---|---|
| Cobertura incompleta | `test/mission_reward_test.dart`, testes de maioria | Havia sete combinações agrupadas em um único teste. Foram preservadas e acrescentadas oito, totalizando 15 casos individuais, incluindo todos os 11 solicitados. |
| Cobertura incompleta | `MissionProvider.finalizeMission`, testes locais | Acrescentadas verificações de finalização antes de terminar todos os rounds, candidatos em ordem misturada, todos os vencedores elegíveis, exclusão de derrotados/empatados/ausentes e término de escrita após descarte do Provider. |
| Cobertura incompleta | `integration_test/mission_reward_test.dart` | Acrescentadas sincronização após evolução, consulta ao original, recrutamento de outro agente, tentativa de duplicidade e navegação de saída/retorno sem bônus adicional. |
| Cobertura incompleta | `HeroDatabase.improveMemberAttribute` e tela de missão | Novo teste provoca falha SQLite real com gatilho temporário exclusivamente no banco de validação. Confere rollback, ausência de anúncio de recompensa salva, manutenção do sorteio e repetição com clique duplo após remover a falha. |
| Pequeno, formatação | `integration_test/catalog_test.dart` | O comando obrigatório identificou diferença de formatação. Ajuste pontual nesse teste de regressão; sem mudança de comportamento. Nenhuma formatação de arquivos em `lib/`. |

Nenhuma falha funcional de produção foi reproduzida nos testes executados. A exceção SQLite provocada pelo teste é intencional; não representa uma falha nova encontrada no aplicativo.

## 3. Regras verificadas

| Rounds | Vitórias | Derrotas | Empates | Resultado esperado e observado nos testes locais |
|---|---|---|---|---|
| 3 | 2 | 1 | 0 | Sucesso |
| 3 | 3 | 0 | 0 | Sucesso |
| 3 | 1 | 2 | 0 | Fracasso |
| 3 | 1 | 1 | 1 | Sem maioria |
| 4 | 3 | 1 | 0 | Sucesso |
| 4 | 2 | 2 | 0 | Sem maioria |
| 4 | 1 | 3 | 0 | Fracasso |
| 5 | 3 | 2 | 0 | Sucesso |
| 5 | 2 | 3 | 0 | Fracasso |
| 5 | 2 | 2 | 1 | Sem maioria |
| 5 | 2 | 1 | 2 | Sem maioria |

Também verificados localmente: 3 empates; quatro rounds com 2 vitórias/1 derrota/1 empate e com 1 vitória/2 derrotas/1 empate; cinco rounds com 3 vitórias/1 derrota/1 empate.

- **Encerramento e maioria:** `advanceRound` marca a missão como concluída apenas após o último confronto. `outcome` usa `vitórias * 2 > totalRounds` ou `derrotas * 2 > totalRounds`, sem divisão inteira. Placar e resultados individuais são comparados com as sequências controladas.
- **Agente e atributo:** o sorteio considera apenas resultados vitoriosos. Os testes verificam todos os candidatos válidos em sequências misturadas e os seis atributos. Não participam derrotados, empatados ou agentes não utilizados.
- **Bônus:** exatamente um membro recebe +1 em exatamente um atributo. O JSON completo é comparado para conferir os outros cinco atributos, os demais campos e os demais membros. Valores superiores a 100 continuam válidos.
- **Persistência:** SQLite lê o JSON atual e atualiza somente o `hero_id` escolhido em uma transação. A atualização do catálogo escreve exclusivamente em `heroes`; recrutar um ID existente não substitui seu JSON evoluído.
- **Duplicidade:** `finalizing` bloqueia chamadas simultâneas; `finalized` evita nova escrita; `feedbackShown` evita reapresentação automática. Reabrir o resultado somente apresenta os dados. Uma nova missão limpa os estados e pode conceder sua própria recompensa.
- **Erro:** falha de escrita mantém a recompensa sem confirmação e conserva agente/atributo para repetir. A interface só apresenta o sucesso da gravação após o Repository retornar.
- **Feedback:** sucesso usa `DialogType.success` e “Missão Cumprida!”, fracasso usa `DialogType.error` e “Operação Fracassada!”. O neutro usa `DialogType.info`, sem bônus, preservando a solução simples existente para a situação não definida no PDF.

## 4. Testes e proteção dos dados

- Linha de base: `flutter analyze` aprovado e 30 testes locais aprovados antes de modificar os testes.
- `flutter test` após ampliar a cobertura: **47 testes aprovados**, sendo **24 em mission_reward_test.dart** e 23 de regressão das outras funcionalidades.
- `flutter analyze` após os novos testes: nenhum problema encontrado.
- `dart format --output=none --set-exit-if-changed lib test integration_test`: **aprovado**, 33 arquivos e zero alterações necessárias. A primeira execução retornou 1 por uma diferença de formatação no teste do catálogo; foi corrigida pontualmente. Não houve falha funcional nos testes.
- Integração no Galaxy A55 `ID_DO_DISPOSITIVO`, Android 16: **10 de 10 aprovados** (2 de recompensas e 8 de regressão), em aproximadamente 5min50s, além da compilação inicial. Comando: `flutter test integration_test -d ID_DO_DISPOSITIVO --no-uninstall --dart-define=REVIEW_SCREENSHOTS=true`.
- Inspeção das capturas atuais de sucesso, fracasso, neutro e erro de gravação: textos legíveis, imagens ajustadas e botões acessíveis, sem overflow observado. Diálogos fechados, reabertos e nova missão executada pelos testes, sem duplicar o bônus. Capturas em `build/review-etapa6/capturas/`, fora dos arquivos versionáveis.
- **Reinício real do processo Android, com o json-server desligado:** aprovado. Foi executada a interface de `lib/main.dart` exclusivamente no pacote `com.example.app_herois.validation`, com cópia do banco que recebeu 100→101→102 nas missões dos testes. Após `am force-stop` e nova abertura, o PID mudou de 7575 para 8156. Meu Esquadrão mostrou “Destaque: Força (102)” e os detalhes mostraram “Força (strength): 102” com a barra correspondente. A cópia do SQLite posterior ao reinício confirmou cinco membros e os 563 JSONs originais idênticos ao backend. Evidências: `build/review-etapa6/capturas/before_restart.png`, `after_restart.png`, `details_after_restart.png` e `build/review-etapa6/restarted-validation.db`. São dados de teste, nunca inseridos no aplicativo normal.
- **Total final:** 57 casos automatizados distintos executados e aprovados (47 locais + 10 de integração), além das verificações manuais. A repetição da linha de base não foi somada a esse total. Nenhum teste funcional falhou ou deixou de executar por limitação do ambiente.

Regressão incluída: 563 JSONs completos, paginação de 20 e última página de 3, fallback de detalhes, cache offline, contrato diário e reabertura, recrutamento/duplicidade/limite 15, dispensa que preserva o catálogo, mínimo de cinco, inimigos fora do esquadrão, uso único dos agentes, seis atributos e confronto por valores reais.

As missões automatizadas usam uma API que lança erro se for chamada, com contador de requisições igual a zero. A preparação do catálogo e a verificação adicional de sincronização usam HTTP real deliberadamente. A falta de imagem é tratada separadamente; desligar a API não significa desligar toda a internet do celular.

O banco normal foi conferido antes dos testes, depois da integração e depois do teste de reinício real, sempre com o mesmo SHA-256 `238365967cf5bb51b5afee4e15b077d3497b407911e8fb671177f52994d5f92a`. Os testes usaram outro applicationId, bancos separados e `--no-uninstall`. A remoção do aplicativo pelo runner na revisão anterior está registrada em [REVISAO_FINAL.md](REVISAO_FINAL.md); esta revisão não garante recuperação de dados anteriores àquele incidente. O esquadrão normal não recebeu os cinco membros nem os bônus dos testes.

## 5. Arquivos alterados nesta revisão específica

- `test/mission_reward_test.dart`: casos individuais de maioria, seleção completa dos vencedores, encerramento e descarte durante gravação.
- `integration_test/mission_reward_test.dart`: preservação após sincronização/recrutamento/navegação, falha SQLite real e cópia isolada para verificar reinício de processo.
- `integration_test/catalog_test.dart`: somente ajuste pontual de formatação exigido pela validação.
- `README.md`: referência ao relatório e aos resultados atuais.
- `REVISAO_ETAPA_6.md`: este relatório.

Não foram alterados `lib/`, dependências, schema SQLite, arquivos do backend ou `materiais/`. Os hashes dos 22 arquivos de produção foram comparados e permaneceram idênticos. Nenhum commit foi realizado. Ferramentas de leitura/captura são temporárias; evidências e cópias dos bancos estão em `build/`, fora dos arquivos versionáveis.

Ao encerrar, o pacote temporário `com.example.app_herois.validation` foi removido explicitamente e o aplicativo normal foi trazido ao primeiro plano, sem reinstalação. Seu banco manteve o mesmo hash. O json-server e o reverse da porta 3000 foram restaurados, com 563 heróis acessíveis. O APK Debug foi regenerado para o identificador normal `com.example.app_herois`, sem instalação adicional no aparelho. A pasta temporária `.tools/` foi removida após preservar as evidências em `build/review-etapa6/`.

## 6. Conclusão

A Etapa 6 está correta e completa para os requisitos verificados: maioria absoluta, feedback, sorteio exclusivo entre vencedores, um atributo +1, persistência acumulada, atualização do esquadrão, uso posterior, proteção contra duplicidade e tratamento da falha de gravação. Os 47 testes locais, dez testes de integração, formatação, análise estática e reinício real offline passaram. Não foi necessária correção de produção nem mudança de arquitetura, regra ou limite de atributos.

Não há pendência funcional da Etapa 6 identificada antes da entrega. Permanecem os limites conhecidos: o enunciado não define o resultado sem maioria, tratado com feedback neutro sem bônus; missões e finalizações ainda pendentes ficam em memória, enquanto bônus já confirmados ficam no SQLite; imagens nunca carregadas podem mostrar substituição offline. Não foram validados outros modelos de celular, orientações ou mudanças extremas de fonte nesta revisão específica.

A recuperação de dados anteriores ao incidente da revisão geral é uma pendência histórica separada. Para demonstrar missões no aplicativo normal, são necessários pelo menos cinco recrutados; os membros preparados para os testes não foram transferidos para ele. A pasta `materiais/` permanece no workspace e não houve commits.

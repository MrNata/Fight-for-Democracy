# Developer Studio 0.3 — 10/10/2026

## Reformulação implementada

- Onze seções permanentes, barra superior com versão/pendências/ações, tema grafite e azul, ícones vetoriais, componentes consistentes e layout adaptável.
- Biblioteca central com seletor nativo, arrastar arquivos, prévia de imagem, reprodução de áudio, metadados reais, oito categorias, vínculos, busca/filtro/ordenação, renomeação, licenças e exclusão protegida por dependências. Desvinculação confirmada; bytes preservados para desfazer e backups.
- Controles compartilhados entre Studio e Player: teclado/gamepad, dois jogadores, captura de entrada, conflitos, perfis, padrões restauráveis, dispositivos conectados e monitor de entradas. Preferências pessoais ficam fora da autoria, com backup.
- Ficha pesquisável com oito abas e treinamento real do personagem. Os editores anteriores continuam disponíveis.
- Publicação com versão/notas, validação, fases, progresso, logs, histórico, pasta do executável e exportação Windows verificada. Cada versão usa outra pasta; a atualização não substitui exe/PCK em execução.
- Preparação de pacote Steam com binários, notas e modelos SteamPipe. Fluxo manual; nenhum upload ou publicação foi feito.
- Ctrl+S, desfazer/refazer, última seção lembrada, dados preservados entre telas, confirmação de exclusão e aviso ao fechar com edições pendentes.
- Documentação em [UX_DEVELOPER_STUDIO.md](UX_DEVELOPER_STUDIO.md), README e AGENTS atualizada.

A preparação adicionou somente versão e notas ao conteúdo de autoria. Comparação com `content/backups/pre-v03/project.json` confirmou que os **156 registros completos, campanhas e vínculos de recursos preexistentes permanecem iguais**. Saves oficiais não foram modificados. Não houve commits ou push.

## Verificações realizadas

**874 verificações aprovadas, zero falhas**: 11 de migração, 692 de runtime, 18 do fluxo da Player, 56 do Studio anterior, 73 de UX/recursos/controles/layout e 11 de controles na Player, mais 13 de integração com exportações reais.

A suite importa ambos os projetos e abre IA, versus local, treinamento e simulação. A integração exporta Windows duas vezes com dados independentes, altera um atributo e a versão, mantém o primeiro executável aberto durante a segunda compilação, confere hashes, trava, histórico, apontamento atual e pacote local Steam. Evidências em `build/export-ux-1791668102247827600/test-results.json` e `test.log`.

O PCK da segunda Player de teste foi auditado: **39 arquivos**, todos os hashes MD5 válidos, dados correspondentes à fixture e nenhum módulo administrativo/teste. Menu e luta também foram abertos a partir de uma cópia em pasta isolada. Isso usa o mesmo PC de desenvolvimento, não outro Windows limpo.

O **Studio 0.3 foi exportado e inicializado sem erros**. Seu caminho atual está em `dist/studio/current.json`; `Developer Studio.cmd` abre essa versão. Os executáveis anteriores foram preservados. Capturas reais do executável estão em [painel inicial](images/studio.png), [personagens](images/studio-personagens.png), [biblioteca](images/studio-biblioteca.png), [controles](images/studio-controles.png) e [publicação](images/studio-publicacao.png). A imagem selecionada na captura da biblioteca é uma captura existente, apresentada como prévia; não foi importada para o projeto.

O layout dos onze módulos foi conferido com viewport de 1366 pixels e expansão em 1920 pixels. As capturas usam os viewports 1366 × 768 e 1920 × 1080 renderizados pela Godot. A janela física deste ambiente é limitada pelo monitor; a captura de 1920 utiliza o modo de escala de viewport, sem ampliar uma imagem pronta.

## Player de autoria exportada e verificada

A pedido explícito do usuário — “Gerar versão sem essa música, preservando o projeto” — foi exportada a **Player 0.3.0** do conteúdo de autoria em `dist/player/versions/v0.3.0-1791670198172-13152/FightForDemocracy.exe`. `dist/player/current.json` e `current.cmd` selecionam essa versão; **`Jogar.cmd` abre o novo executável**. Os binários anteriores continuam preservados.

A única omissão no manifesto é a música `assets/471318549_MOST BADASS VOCAL BATTLE ACTION EVER _ by Epikus [zP_lAuTRRCI].mp3` da arena `trono_urna_x`, que não tem origem/licença/autorização registradas. O campo de música fica vazio somente no conteúdo público e o MP3 não está no PCK. O projeto mantém o vínculo original e os bytes do arquivo: SHA256 `9d953be26b9ae85d17cb39522381734fa50e82e34b91f6c29208993d4fbdfeeb`, igual ao backup pré-0.3. A comparação de todos os dados também confirmou a preservação dos 156 registros completos e dos campos preexistentes.

O **PCK real da autoria contém 39 arquivos auditados**, com todos os hashes MD5 válidos e nenhum módulo do Studio/teste. Seu conteúdo corresponde ao projeto com essa única omissão. Os hashes SHA256 do executável e PCK correspondem ao apontamento atual; o atalho aponta ao executável existente. Menu e luta abriram sem erros a partir de `build/clean-player-1791670221091104800/`, e o Studio exportado também iniciou com código zero. Evidências: `manifest.json`, `audit.json`, `clean-smoke.json` e logs na pasta da versão. A captura de publicação foi atualizada com essa compilação selecionada.

A exportação padrão continua bloqueando essa música sem os registros necessários. A omissão pode ser repetida pela opção explícita do Studio ou por `tools/Export.ps1 -OmitUnlicensed`. Edição, prévia e testes locais conservam o recurso de autoria. As duas versões da integração anterior continuam sendo fixtures independentes; a compilação acima usa o projeto real.

## Limitações

Nenhum gamepad físico estava conectado. Captura e comandos foram testados com eventos sintéticos; USB/Bluetooth, hotplug físico e layouts de teclado precisam de validação em hardware. Não há publicação automática na Steam. O Studio não transforma documentação de licença em autorização jurídica: os direitos reais continuam sendo informação do autor.

Uma tentativa adicional de automatizar a captura pelo scancode nativo do Windows não concluiu a inicialização/foco da janela auxiliar. Ela não foi contabilizada como teste aprovado; a checagem de entrada do desktop permanece pendente. O auxiliar experimental foi retirado, mantendo as suites reproduzíveis aprovadas.

Arte, golpes de base, histórias individuais e chefes cinematográficos continuam nas condições anteriores. Esta reformulação não recriou o combate nem tornou o catálogo temporário um jogo comercial finalizado.

---

# Histórico: incremento 0.2 — 10/10/2026

## Resultado deste incremento

A fundação 0.1 foi preservada e ampliada. Player e Developer Studio continuam como projetos e executáveis independentes. Não foram realizados commits ou push.

- Quatro carreiras funcionais: Direita, Esquerda, Centrão e Independentes. Todas têm sete cargos, 113 adversários comuns únicos e chefe no confronto 114. São 154 escolhas elegíveis no catálogo atual, incluindo 34 Independentes; dois chefes ficam reservados.
- Correção da validação que rejeitava um chefe da mesma facção no final e impedia a quarta carreira. Ordem dos cargos, indicador de chefe, duplicações e incompatibilidades são conferidos.
- Saves antigos conservam sua sequência e usam compatibilidade explícita. Novas carreiras reservam também o chefe de outras rotas. Nenhum perfil oficial foi usado nos testes ou regenerado.
- Os 156 IDs, atributos e campos anteriores de golpes foram preservados. Uma comparação com o backup original confirmou isso. Os dois slots de chefe mantêm seus IDs e guardam a identificação anterior em `legacy_identity`.
- Lula encerra Direita/Centrão/Independentes; Enéas encerra Esquerda. O **PARADOXO DA URNA-X** é anunciado antes da luta e limita a invencibilidade ao confronto final da história da Esquerda. O Versus permite derrotar Enéas; Lula permanece vencível.
- Arena **Trono da URNA-X**, Salvador fantástica, com cenário procedural temporário distinto: trono, palanque, telões, bandeiras fictícias, fachadas, holofotes e plateia genérica animada. Background e música podem ser importados. Caricaturas finais de plateia e trilha própria estão pendentes.
- Importador transacional de catálogo completo e quatro rotas no Studio: prévia, validação, combinação de campos por ID, mapeamento explícito de IDs externos, aplicação e reversão. Modelo de importação exportável pela interface. Nenhum pacote externo foi inventado ou declarado importado.
- Desfazer/refazer por botões e atalhos, com até 30 estados por sessão. Abrir/criar projeto inicia outro histórico. Importação e restauração de backup podem ser desfeitas.
- Edição visual de hurtbox, colisão corporal, offsets/altura de hitbox, largura de projétil, permissão aérea, destinos e janela de cancelamento. Prévia e Player usam os mesmos parâmetros.
- Poses procedurais acompanham preparação, atividade e recuperação. Spritesheets permitem trecho por golpe, sincronizado com o frame do ataque. Animações próprias completas por estado continuam pendentes.
- Separação corporal corrigida junto à parede. Projéteis guardam sua ação e execução de origem, evitando condições ou confirmação de combo herdadas de um golpe posterior. Limites de 64 projéteis e 32 impactos simultâneos.
- Página **Chefes** com edição básica de atributos, IA, arena final, golpes e encerramento explícito. O editor completo de fases e cinematográficas ainda está pendente.
- **SALVAR E GERAR JOGO** executa a exportação real. Imagens e músicas externas precisam de origem/licença/autorização registradas antes de exportar. Projetos continuam editáveis com esses registros incompletos; vozes mantêm a validação já existente.

## Conteúdo ausente e migração

Os cinco arquivos do novo pedido não foram encontrados: `personagens_156_v2.json`, `campanhas_4_rotas_114_lutas.json`, `catalogo_156_golpes.md`, `guia_importacao_developer_studio.md` e `PROMPT_CODEX_IMPORTACAO.md`. O contrato necessário foi implementado e documentado em [IMPORTACAO.md](IMPORTACAO.md). Seu formato é explícito; arquivos externos não fornecidos não têm parser presumido.

O conteúdo anterior permanece em `content/backups/pre-v02.json`, com os recursos existentes. A atualização é aditiva, idempotente e mantém `schema_version: 1`, com revisão de conteúdo 2. O catálogo continua com arte e golpes de base temporários nas quantidades 40/40/40/36. Não são 156 personagens comerciais finalizados.

## Evidências de teste

Última suite: **777 verificações aprovadas**, zero falhas — 11 de migração/preservação, 692 de runtime/combate/campanhas, 18 do fluxo da Player e 56 do Studio. Ambos os projetos foram importados na Godot; IA, local, treinamento e simulação foram abertos sem erros.

| Regra | Evidência |
|---|---|
| Quatro rotas, sete cargos, 114 lutas | Todas as 154 carreiras elegíveis da fixture geradas e verificadas |
| Sem repetição, auto-confronto ou chefe antecipado | Sequências verificadas; adversários/cargos adulterados rejeitados |
| Preservação de IDs e conteúdo | Comparação com backup original; migração testada sem alterar sua entrada |
| Salvamento e retry | Derrota, retomada, sete vitórias, promoção, quarta carreira e sequência legada no fluxo real |
| Importação segura | JSON real, prévia sem mutação, 156 registros, quatro rotas, mapeamento e rejeição de dados inválidos |
| Desfazer/refazer | Importação inteira, atributos, edição visual de colisão e ramificação do histórico |
| Colisões e frames | Startup sem dano, atividade com um contato, espelhamento, agachamento e hitbox editada alterando contato real |
| Cancelamentos | Confirmação de acerto, destinos, janela, buffer e rejeição de ações terrestres durante salto |
| Projéteis | Frame ativo, geometria configurada e identidade preservada após outro ataque |
| Chefes | Paradoxo visível, encerramento sem vitória falsa, KO de Enéas no Versus e Lula vencível na Independente |
| Licenças | Imagem sem registro bloqueia distribuição; registro visual libera arte própria de teste; voz sem licença rejeitada |

Os executáveis foram exportados e sua inicialização verificada; a auditoria do PCK compara autoria/conteúdo, confere hashes e rejeita arquivos administrativos. Logs e relatórios ficam em `dist/player/`. A checagem em pasta isolada utiliza o mesmo PC, sem substituir testes em outro Windows sem ambiente de desenvolvimento. Controle físico, Windows 10 e outros dispositivos ainda precisam ser testados. Registro de licença verifica documentação; a compatibilidade dos direitos fornecidos precisa ser confirmada pelo autor.

Capturas reais dos executáveis exportados: [Dashboard do Studio](images/studio.png), [editor de golpes](images/studio-combate.png), [editor básico de chefes](images/studio-chefes.png), [menu do jogo](images/player.png) e [Trono da URNA-X](images/trono-urna-x.png). O pacote da Player contém 35 arquivos auditados, com hashes válidos e sem módulos do Studio ou testes.

## Próximos incrementos

1. Receber/adaptar o catálogo externo e golpes por mapeamento explícito, preservando IDs usados nos saves. Adicionar arte, roupas e animações distintas, referências e áudio autorizado.
2. Expandir comportamentos compartilhados: investida, vertical, armadilha, invocação, área, sequência, transformação e cinematografia. Os dez slots atuais executam golpes diretos e projéteis; campos desconhecidos importados não ativam comportamentos novos.
3. Separar perfil normal e de chefe. Implementar Lula com arte própria aproximadamente 2,25 vezes maior, hitboxes específicas e três fases completas, ataques telegrafados, contrajogo, música/câmera e derrota cinematográfica.
4. Implementar especiais e ritmo discreto de Enéas, silêncio ambiental e finalização dimensional. Acrescentar Nikolas, Escola do Discurso, técnicas próprias e encontro após identificar seu registro no catálogo real.
5. Completar editor de chefes com fases/eventos/música/animações, timeline de áudio/partículas/câmera e hitboxes desenhadas; arenas em camadas, caricaturas reativas da plateia e menus visuais completos.
6. Cerimônias animadas de promoção, histórias individuais, finais próprios, mapa gráfico, regeneração limitada, conquistas, ranking ordenado e opções persistentes.
7. Balanceamento competitivo, métricas em luta, testes de hardware/controles, Windows 10/11 em outros PCs, instalador/assinatura e preparação Steam.

Esta execução entrega a próxima etapa funcional, conforme autorizado no pedido. O jogo completo e a edição cinematográfica integral permanecem em desenvolvimento; multiplayer online é futuro.

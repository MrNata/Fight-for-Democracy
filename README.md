# FIGHT FOR DEMOCRACY

Incremento jogável **0.3**, em Godot **4.7.2 estável**, GDScript e renderização Compatibility. Dois projetos e dois executáveis separados: jogo offline e Developer Studio privado. Esta entrega reformula o Studio com onze módulos, biblioteca com prévias e vínculos, controles compartilhados entre editor e jogador, abas de personagem e uma central de publicação com versões independentes. As quatro campanhas e o combate da versão anterior foram preservados. A versão comercial completa continua em desenvolvimento.

## Executar agora

No Windows, abra na raiz:

- **`Jogar.cmd`**: abre a Player **0.3.0** exportada e verificada, selecionada pelo histórico atual.
- **`Developer Studio.cmd`**: abre o editor privado, conectado a esta pasta de trabalho.

O Studio atualizado é selecionado por `dist/studio/current.json` e seu atalho. Novas compilações da Player ficam em `dist/player/versions/`, com apontamento em `dist/player/current.json`. Preserve o `.pck` ao lado do executável. Para distribuir, entregue somente a pasta da versão escolhida, com licenças e instruções; o jogador não precisa instalar Godot, Python ou Studio. Executáveis anteriores em `dist/player/` e `dist/studio/` foram preservados.

**Player atual:** `dist/player/versions/v0.3.0-1791670198172-13152/`. A pedido do usuário, a música Epikus do Trono da URNA-X foi omitida somente deste pacote; o arquivo original e seu vínculo no projeto foram preservados e conferidos contra o backup. Essa é a compilação do conteúdo de autoria, com 39 arquivos auditados e inicialização de menu/luta verificada em pasta isolada. A omissão consta em `manifest.json`; os relatórios estão em `audit.json` e `clean-smoke.json` na pasta da versão. A exportação padrão continua exigindo origem/licença/autorização dessa música; para repetir a escolha, selecione a opção de omissão no Studio ou use `-OmitUnlicensed` no comando abaixo.

Para abrir os projetos na Godot, importe `player/project.godot` ou `studio/project.godot`. A engine portátil já está em `tools/godot/`; nada foi instalado globalmente. Resolução-base do jogo: 1920 × 1080, janela inicial 1280 × 720, física 60 Hz. Studio: janela inicial 1366 × 768, layout responsivo com rolagem, também verificado em 1920 × 1080.

## Primeira luta

Selecione **Luta rápida**, **Versus local** ou **Treinamento** e escolha os lutadores. Os primeiros personagens são Aurora e Torquato, ambos fictícios. A barra de fama começa em zero; acerte golpes para liberar especiais. Treinamento exibe hurtboxes em azul e hitboxes em vermelho, com dados de frame no HUD.

| Ação | Jogador 1 | Jogador 2 | Controle |
|---|---|---|---|
| Mover / salto / agachar | A, D / W / S | Setas | Analógico / direcional |
| Soco leve / forte | J / K | Numpad 1 / 2 | A / X |
| Chute leve / forte | U / I | Numpad 4 / 5 | B / Y |
| Defesa / esquiva | G / H | Numpad 0 / ponto | LB / L3 |
| Agarrão | L | Numpad 3 | RB |
| Contra após bloquear | T | Numpad 6 | LB + X |
| Especiais | Q / E | Numpad 7 / 8 | LT / RT |
| Superespecial | R | Numpad 9 | R3 |
| Finalização básica | F | Numpad + | Select |
| Pausar / reiniciar | Esc | Esc | Start |
| Mostrar colisões | F1 | F1 | Teclado |

A finalização inicial é um golpe condicionado à vida baixa do adversário, sem cinematografia final. A esquiva tem janela limitada de invulnerabilidade. Contra-ataque exige uma defesa recente. O buffer dura oito frames. Cancelamentos exigem destino autorizado e janela configurada durante a recuperação; os modelos padrão exigem acerto sem defesa. Golpes terrestres não podem ser iniciados no ar. Ataques simultâneos usam prioridade; projéteis preservam o golpe que os criou mesmo quando o atacante inicia outra ação.

## Editar sem código

1. Em **Personagens**, pesquise os 156 registros e edite Aparência, Atributos, Animações, Golpes, Vozes, Finalizações, IA e Pré-visualização. **Testar personagem** abre treinamento real com os dados salvos.
2. Em **Biblioteca de recursos**, selecione ou arraste arquivos, confira a prévia e escolha categoria, destino e uso. Há reprodução de áudio, pesquisa, filtros, ordenação, renomeação, licenças e dependências. Recursos em uso exigem desvinculação confirmada antes de excluir. PNG/JPG/WebP, WAV/OGG/MP3, spritesheets e camadas de plateia são suportados.
3. Em **Golpes e combate**, mantenha o fluxo de edição de frames, colisões, projéteis, animações e cancelamentos, com timeline e prévia do mesmo motor.
4. **Áudio e músicas**, **Arenas** e **Campanhas** conservam seus editores. **Configurações** reúne Chefes, Economia, História e Menus.
5. Em **Configuração de controles**, selecione perfil, jogador e teclado/gamepad. Clique em Alterar e pressione a nova entrada. Conflitos impedem salvar. No Studio, os comandos são padrões globais; na Player, são preferências privadas em `user://controls.json`, com backup. Os comandos da tabela acima são os padrões restauráveis.
6. Em **Publicação e atualizações**, informe versão/notas e siga Salvar → Validar → Testar → Gerar nova versão. A tela apresenta histórico, data, pendências, fases, log e executável. Uma compilação só é aprovada após gerar exe/PCK e abrir menu e luta sem erros. Pastas novas preservam instalações em execução e os saves continuam fora dos pacotes.
7. **Preparar pacote Steam** cria arquivos locais, notas e modelos SteamPipe, com um fluxo manual. Não há upload, credenciais ou publicação automática.

O [guia de UX do Studio](docs/UX_DEVELOPER_STUDIO.md) detalha todos os fluxos, capturas, separação de preferências, importação e exportação. Nenhum gamepad físico estava conectado nos testes; eventos sintéticos não certificam USB/Bluetooth ou hotplug físico.

No **Painel inicial**, use **Importar catálogo de 156 personagens / quatro rotas** para preparar uma prévia e depois aplicar o pacote. **Exportar modelo de importação com os IDs atuais** gera um pacote válido para edição. O [guia de importação](docs/IMPORTACAO.md) descreve formato, mapeamento de IDs externos e arquivos ausentes. Desfazer/refazer funcionam por botões, Ctrl+Z, Ctrl+Y ou Ctrl+Shift+Z, com até 30 estados por sessão. Ctrl+S salva. Importação pode ser desfeita; salvar preserva a versão anterior em `.bak`.

`Abrir projeto`, `Criar projeto`, `Salvar como`, `Backup` e `Restaurar backup` são operações reais sobre os dados. Criar projeto utiliza o modelo incluído. Backup completo também copia imagens e áudio referenciados e arquivos da biblioteca. Importação copia recursos para `assets/` do projeto, com nomes únicos. Não renomeie IDs ou arquivos fora do Studio enquanto uma carreira depender deles.

## Carreira e salvamento

As quatro rotas padrão têm sete cargos e **113 oponentes normais distintos + chefe final**, sem enfrentar o personagem escolhido. O gerador usa IDs ordenados e RNG local com semente configurável. Adversários comuns vêm das outras facções, com chefes reservados. O chefe final pode pertencer à facção do jogador, permitindo a carreira Independente. Rotas autoradas também passam por validação.

Há três perfis locais, retomada, mapa em lista, promoção, loja com limites, pontuação e recordes. Derrotas preservam o índice da luta. Vitórias e derrotas salvam automaticamente. Arquivos em `%APPDATA%/Godot/app_userdata/FIGHT FOR DEMOCRACY/profiles/`, com versão de esquema e `.bak`; um arquivo principal corrompido pode ser recuperado do backup.

Esta versão preserva **156 registros**, divididos em 40/40/40/36, com arte e golpes de base temporários. Os cinco arquivos de catálogo e importação citados no novo pedido estão ausentes. Os IDs `teste_regente` e `teste_guardiao` foram mantidos e seus chefes temporários passaram a representar caricaturas fictícias de Lula e Enéas. Lula encerra Direita/Centrão/Independentes no **Trono da URNA-X**, arena procedural temporária em uma Salvador fantástica. Na Esquerda, o **PARADOXO DA URNA-X** avisa antes do combate que Enéas é invencível; o desfecho ocorre na derrota ou em até 30 segundos. No Versus ele pode sofrer KO. Lula gigante, três fases, especiais exclusivos e cinematográficas ainda estão pendentes.

A atualização conserva o conteúdo anterior em `content/backups/pre-v02.json`, junto dos recursos existentes. Os nomes anteriores dos chefes permanecem em `legacy_identity`. Saves anteriores continuam com a sequência gravada, inclusive quando continham o chefe de outra rota em uma luta comum. Novas carreiras usam a regra de reserva de todos os chefes. Alterações futuras que invalidem IDs ou cargos de um save produzem erro explícito; o jogo não sorteia outra sequência para esconder o conflito.

Toda a narrativa se passa na **República da Arena**, uma paródia fictícia. Facções são classificações editáveis do roteiro. P$ Propina é apenas uma moeda fictícia de jogo. Não há biografias inventadas nem imitação de gravações reais.

## Reproduzir a preparação e os testes

Dependências de desenvolvimento: Windows 10/11 x64, Python 3 (somente ferramentas de preparação), Godot 4.7.2 padrão e seus modelos oficiais Windows x64. Git é opcional para executar e recomendado para desenvolver. Nenhuma função essencial do jogo depende de rede.

```powershell
# Somente para repor engine/modelos ausentes; baixa arquivos oficiais, incluindo o pacote de modelos de ~1 GB.
python tools/bootstrap.py

# Cria dados apenas se ausentes; migra v0.1 com backup e sincroniza runtime e fixtures.
python tools/prepare.py

# Importa ambos os projetos, verifica logs, executa suites e abre quatro modos.
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Test.ps1

# Testa e exporta os dois executáveis; exige licenças completas por padrão.
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Export.ps1 -Studio

# Reproduz a Player atual, omitindo recursos sem licença somente no pacote.
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Export.ps1 -OmitUnlicensed

# Duas exportações reais com fixture isolada e primeira versão em execução.
python tools/test_exports.py
```

A suite principal soma **861 verificações**, e a integração de exportação soma **13**, com zero falhas. Os testes usam fixtures independentes e perfis isolados. Falhas de script são detectadas no log, inclusive quando a Godot retorna código zero. O verificador do pacote lê o diretório real do PCK, confere todos os hashes MD5, compara conteúdo de autoria e conteúdo exportado e rejeita arquivos de administração e testes.

Para repor a engine manualmente, consulte o [download oficial](https://godotengine.org/download/archive/4.7.2-stable/). Os presets usam os modelos em `tools/godot/templates/`; ver [exportação oficial para Windows](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html). A licença e os avisos de terceiros da engine estão em `docs/GODOT-COPYRIGHT.txt` e são incluídos na distribuição.

## Organização

| Pasta | Responsabilidade |
|---|---|
| `player/runtime/` | Combate, estados, entrada, IA, personagens, fama, campanha, economia, áudio, arenas, dados e saves |
| `player/ui/`, `player/scenes/` | Interface e entrada da Player Edition |
| `studio/editor/`, `studio/scenes/` | Ferramentas visuais e exportador privado |
| `studio/runtime/` | Cópia gerada do runtime; editar a origem em `player/runtime/` |
| `content/` | Conteúdo de autoria e recursos importados |
| `tools/` | Preparação, aquisição oficial da Godot, testes e auditoria |
| `dist/player/`, `dist/studio/` | Executáveis separados, não versionados |
| `docs/` | Arquitetura, estado da entrega e capturas reais |

As dependências seguem UI → sistemas → dados. O runtime não importa o Studio. A exportação usa uma lista de scripts de runtime, cenas e recursos de conteúdo, sem incluir testes ou backups. Os menus administrativos só existem no projeto Studio. A biblioteca e suas referências de autoria são retiradas do snapshot público; omissões escolhidas explicitamente ficam no manifesto.

## Limites desta entrega

Veja [o estado detalhado](docs/STATUS.md). Estão pendentes o catálogo externo completo, arte e áudio finais, animações próprias por estado, histórias individuais, Nikolas e a Escola do Discurso, chefes com fases cinematográficas, hitboxes desenhadas livremente, trilhas de efeitos, arrastar e soltar confrontos, arenas em camadas, regeneração limitada, conquistas completas, balanceamento competitivo, instalador e validação em outros PCs/Windows 10. Multiplayer online não faz parte desta versão.

Preserve `content/` e os perfis. Não distribua o Studio ou a pasta de desenvolvimento junto da Player. Nenhum commit, remoto ou push foi criado automaticamente.

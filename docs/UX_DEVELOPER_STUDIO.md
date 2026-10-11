# Developer Studio 0.3 — interface e fluxos

O Studio continua sendo o editor privado do projeto Godot. O catálogo, os 156 IDs, golpes, atributos, campanhas e salvamentos existentes foram preservados. Os executáveis das duas edições permanecem separados.

## Layout

A barra superior mostra nome, versão do projeto, estado de salvamento, pesquisa rápida, desfazer/refazer, Salvar, Testar Player e acesso à geração de versão. Ctrl+S salva; Ctrl+Z desfaz; Ctrl+Y ou Ctrl+Shift+Z refaz. Há até 30 estados de desfazer por sessão.

A navegação permanente contém onze entradas: Painel inicial, Personagens, Golpes e combate, Biblioteca de recursos, Áudio e músicas, Arenas, Campanhas, Configuração de controles, Testes, Publicação e atualizações e Configurações. Chefes, Economia, História e Menus continuam disponíveis em Configurações. Trocar de seção preserva os dados em memória; a última seção fica em uma preferência local do Studio. Fechar com alterações pendentes oferece salvar, descartar ou cancelar.

Grafite, azul profundo, um acento azul, fonte Segoe UI/Arial, ícones vetoriais originais, botões de pelo menos 38 pixels, foco, seleção e hover compõem o tema compartilhado. As áreas de trabalho usam rolagem vertical, listas e abas. Campos longos têm quebra de linha; as ferramentas de campanha e publicação podem distribuir botões em mais de uma linha. O tamanho inicial é 1366 × 768; 1920 × 1080 utiliza o espaço adicional. Não é preciso abrir o editor Godot para trabalhar.

## Importar e organizar recursos

1. Abra Biblioteca de recursos ou clique em Importar na ficha de personagem/arena. O segundo caminho preseleciona o destino.
2. Arraste um arquivo para a janela ou use Selecionar arquivo, com o seletor nativo do Windows. PNG/JPG/JPEG/WebP e WAV/OGG/MP3 são suportados. Arquivos vazios, incompatíveis, acima de 64 MB ou imagens acima de 8192 × 8192 são rejeitados.
3. Confira a imagem ou use Ouvir/Parar. O painel informa formato, bytes, dimensões ou duração reais.
4. Escolha categoria, destino e uso. Registre nome, origem, licença e autorização. Clique em Importar e vincular e depois Salvar.

As oito categorias são Personagens e sprites, Animações, Músicas, Efeitos sonoros, Vozes e bordões, Cenários, Elementos de plateia e Interface. É possível importar somente para a biblioteca e escolher o vínculo depois. Imagens podem ser sprites/roupa completa, spritesheets, cenário, camada de plateia ou fundo do menu. Áudio pode ser música de arena/menu, voz por evento ou efeito de impacto. Posição e tamanho das camadas de plateia são editáveis em Arenas. Roupa importada substitui o sprite atual; esta versão não cria um inventário de trajes alternativos.

Uma importação individual apresenta prévia antes da confirmação. Arrastar vários arquivos importa cada arquivo para a biblioteca sem escolher vínculos automaticamente. O nome interno usa SHA-256, evita substituir bytes diferentes e reaproveita importações idênticas. Nome exibido, pesquisa, filtro e ordenação são independentes do arquivo físico. Recursos de personagens e arenas importados pelo Studio anterior aparecem na biblioteca sem mudar seu caminho.

Selecione um recurso para renomear, editar os registros de licença, consultar usos e aplicar um novo vínculo. A licença atualizada também alcança os usos existentes. Desvincular mostra todos os locais afetados e pede confirmação. Excluir fica bloqueado enquanto houver dependências. A remoção da biblioteca preserva os bytes para desfazer e restaurar backups; limpeza física automática não está implementada. Backups e Salvar como incluem a biblioteca, mesmo seus recursos ainda sem vínculo. O pacote público inclui somente recursos usados pelo jogo; metadados administrativos da biblioteca ficam fora do conteúdo distribuído.

O importador de catálogo/rotas continua sendo uma transação separada, com prévia, validação e IDs preservados. Consulte [IMPORTACAO.md](IMPORTACAO.md).

## Controles no Studio e na Player

Configuração de controles está diretamente na navegação. Selecione perfil, Jogador 1/2 e Teclado ou Controle USB/Bluetooth. Clique em Alterar e pressione uma tecla, botão ou eixo; Esc cancela. Os comandos incluem movimento, salto, agachamento, quatro ataques, defesa, esquiva, agarrão, contra-ataque, dois especiais, super, finalização, pausa e navegação dos menus.

Conflitos entre teclados dos dois jogadores, comandos duplicados no mesmo gamepad e a escolha do mesmo dispositivo explícito para ambos são indicados e impedem salvar. Sobreposições entre comandos de luta e de menu são permitidas, pois pertencem a contextos diferentes. Perfis podem ser clonados, selecionados e restaurados. O monitor mostra dispositivos realmente conectados e as entradas recebidas; o dispositivo automático atribui controles por ordem de conexão. Escolha um dispositivo explícito quando precisar manter uma associação independente dessa ordem. Os padrões incluem direcional e analógico esquerdo; gatilhos acionam especiais e LB+X aciona o contra-ataque.

No Studio, Salvar configurações grava padrões em `content/project.json`. Na Player, a mesma interface escreve `user://controls.json` com escrita atômica e backup. Ela não modifica os padrões globais, os personagens nem o progresso. Preferências inválidas são recuperadas do último backup válido, ou dos padrões do projeto. Testar Player pelo Studio usa um arquivo separado em `build/studio-test-controls.json`, para não herdar a personalização do jogador.

Os testes verificam eventos sintéticos de teclado/gamepad, captura, conflitos, dois jogadores, persistência e monitor de dispositivos. Nenhum controle físico estava conectado nesta execução. USB/Bluetooth, hotplug físico e diferentes layouts de teclado ainda precisam de ensaio com hardware; os testes sintéticos não certificam esses casos.

## Personagens e módulos existentes

A lista pesquisável oferece os 156 registros e oito abas: Aparência, Atributos, Animações, Golpes, Vozes, Finalizações, IA e Pré-visualização. Alterações chegam aos mesmos dados consumidos pelo runtime. Testar personagem salva os dados válidos e abre uma luta de treinamento real com o personagem selecionado; não grava carreira oficial. Golpes e combate mantém timeline, colisões, cancelamentos, animação e prévia com o motor existente. Arenas, campanhas, áudio, chefes, economia e história continuam funcionais.

## Gerar e atualizar versões

Em Publicação e atualizações, edite a versão (por exemplo `0.3.0`) e as notas. A tela mostra última compilação, data UTC, diferenças desde a compilação, validação, histórico, log e caminho do executável. Salvar alterações, Testar Player, Validar projeto, Gerar nova versão, Abrir pasta e Visualizar erros executam suas operações reais.

Gerar nova versão valida projeto e licenças, salva, prepara um snapshot, copia os recursos usados, importa a Godot, exporta Windows e verifica o executável e seu PCK. O executável abre em modo headless no menu e em uma luta. Só um resultado sem erros é registrado como verificado. Fases e progresso indicam preparação, importação, compilação e verificação. Erros de preparação ficam também em `build/last-export-error.log`; cada compilação guarda `export.log` e logs de inicialização.

Cada exportação usa `dist/player/versions/v<versão>-<identificador>/`. Nunca substitui os arquivos de uma instalação em execução. A trava `build/export.lock` impede preparações concorrentes e reconhece o processo proprietário. O histórico fica em `dist/build-history.json`; `dist/player/current.json` e `current.cmd` selecionam a última versão aprovada. `Jogar.cmd` utiliza esse apontamento. Saves e preferências continuam no mesmo diretório `user://`, fora das pastas de distribuição.

O comportamento padrão rejeita recursos sem documentação de licença. A opção **Omitir recursos com licença pendente somente nesta compilação** permite gerar um pacote sem esses recursos: arquivos e vínculos da autoria permanecem intactos, e `manifest.json`/histórico listam cada omissão. Essa opção requer seleção explícita; não concede licença nem inventa autorização. Depois de registrar os direitos, gere uma versão incluindo os recursos.

Para distribuir, copie somente a pasta da versão escolhida, com `.exe`, `.pck`, manifesto, instruções e avisos da Godot. Não entregue todo o desenvolvimento, o histórico de versões antigas ou o Studio. O Studio também é exportado em uma pasta nova, com seu próprio apontamento e inicialização verificada.

## Preparar a Steam

Preparar pacote Steam exige uma compilação verificada que corresponda aos dados atuais. Confere os hashes do executável/PCK, copia o pacote para uma nova pasta em `dist/steam/`, inclui notas, manifesto e modelos `app_build.vdf`/`depot_build.vdf`. O arquivo PUBLICACAO-MANUAL.txt explica como preencher App ID e Depot ID, usar o SteamPipe SDK da própria conta, selecionar uma branch e conferir a instalação.

Não existe integração de upload, credencial Steamworks ou publicação automática. Nenhum conteúdo foi enviado à Steam. Preparar o pacote local não publica o jogo.

## Verificação desta entrega

`tools/Test.ps1` importa os projetos, executa testes antigos e novos e abre IA, versus local, treinamento e simulação. `python tools/test_exports.py` exporta duas versões reais com uma fixture independente, altera um atributo entre elas, mantém a primeira em execução, confere integridade, trava, histórico, atalho e preparação local da Steam. Seus arquivos ficam em `build/export-ux-…`, sem modificar o conteúdo oficial ou seus saves.

Capturas de telas reais ficam em [images](images/). O estado exato da compilação do projeto de autoria, contagens e limitações estão em [STATUS.md](STATUS.md).

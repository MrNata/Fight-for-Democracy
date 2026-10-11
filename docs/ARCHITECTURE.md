# Arquitetura da fundação

## Runtime e autoria

`player/` e `studio/` são raízes Godot independentes. O Studio compartilha módulos de dados, áudio e preview por uma cópia gerada; não há referência do Player ao editor. `tools/prepare.py` sincroniza essa cópia e enumera scripts distribuíveis nos presets. Editar somente `player/runtime/` como origem.

O runtime é orientado a dicionários validados, com esquema 1. Conteúdo carregado por `ContentStore` é imutável por convenção durante a luta; o Fighter recebe cópia de configuração. O catálogo é carregado como dados; somente os dois sprites necessários são decodificados. O Studio modifica os dados em memória, valida antes de salvar e importa recursos com caminhos relativos.

## Módulos

| Componente | Implementação | Contrato |
|---|---|---|
| Combat Engine | `combat_match.gd`, `fighter.gd` | Passo fixo, pushboxes, hit/hurtboxes, projéteis, prioridades e resolução de rodada |
| Character System | `character_system.gd`, `fighter.gd` | Configuração por personagem, sprite lazy e recorte de spritesheet |
| Campaign System | `campaign_system.gd` | Semente local, elegibilidade, chefe reservado, rotas editadas e invariantes |
| AI System | `ai_system.gd` | Decisões por intervalo de reação, observação do estado presente, sete níveis + chefe |
| Audio System | `audio_system.gd` | Seis buses, streams importados, vozes ponderadas com intervalo, som temporário original |
| Economy System | `economy_system.gd` | Compra com limite/saldo e aplicação limitada de upgrades |
| Fame System | `fame_system.gd` | Ganho, custo e limites de 0 a 100 |
| Arena System | `arena_system.gd` | Arena procedural temporária ou imagem importada; cores configuráveis |
| Save System | `save_system.gd` | Perfis, esquema, verificação, escrita com backup e recuperação |
| Developer Studio | `studio_app.gd`, preview e timeline | Formulários, catálogo, importação, previews e ações de projeto |
| Content Validation | `content_store.gd` | Tipos, limites, IDs, arquivos e todas as carreiras antes de aceitar conteúdo |
| Export Manager | `studio/editor/export_manager.gd` | Requisitos, empacotamento explícito, processo em thread, logs e smoke de executável |

## Combate

Cada tick é 1/60 s. O Match coleta comandos, avança os estados de ambos os lutadores, resolve pushboxes, coleta ataques ativos, resolve prioridade e aplica contatos. Projetéis avançam pelo mesmo passo fixo. A renderização lê o estado; não aplica dano nem avança a partida.

Estados: neutro, movimento, agachamento, ar, ataque, defesa, esquiva, stun e KO. Um golpe contém startup, atividade e recuperação em frames, alcance, dano, fama, cooldown, stun e prioridade. Contatos são limitados a um por ataque. Comandos expiram após oito frames. `cancel.into` autoriza destinos; `start/end` delimitam frames relativos ao início da recuperação; `require_hit` exige confirmação sem defesa. Sem regras explícitas, não há cancelamento. `air_allowed` delimita ações aéreas.

`collision` define hurtbox em pé/agachada e largura corporal. `hitbox` define offset frontal, distância vertical acima do chão e altura; `reach` define largura de golpe direto. Projéteis usam os mesmos offsets, altura e uma largura própria. A posição espelhada depende de `facing`, sem escala automática de corpo. Pushboxes transferem a separação restante para o lado livre quando o outro lutador encontra a parede.

O desenho procedural de ataque usa o mesmo frame e alcance do contato. Spritesheets usam `move.animation.start/count` e percorrem o trecho ao longo da duração inteira do golpe, sem repetir o ciclo de idle durante o ataque. Um projétil captura a ação e o número de execução: atingir depois não confirma uma ação posterior nem herda sua regra de finalização. Existem limites de 64 projéteis e 32 impactos simultâneos.

Não há rede nesta fundação. O método `CombatMatch.advance(left_input, right_input)` mantém comandos separados da simulação e permite testes determinísticos; rollback e serialização completa de estado ainda não foram implementados.

## Persistência e erros

Conteúdo e progresso usam `.tmp` e `.bak`. Primeiro a escrita temporária é fechada; o arquivo anterior passa a backup, e o temporário assume o nome definitivo. Falha na última troca tenta restaurar o anterior. Perfis inválidos não são aceitos; a carga tenta o backup. Essa estratégia reduz perda em escrita interrompida, mas não promete recuperação de falhas de disco.

O teste integrado passa `--content=<projeto>` e `--test-fight --mode=training` à Player. Só uma carreira iniciada pelos menus habilita gravação de resultados. Os testes automatizados usam diretórios de perfis isolados.

As quatro rotas novas usam `schedule_rules: 2`; personagens de chefe ficam fora do pool comum. O confronto final permite chefe da mesma facção. Saves sem essa chave usam validação legada, preservando o chefe de outra rota caso ele já estivesse na sequência antiga. O runtime nunca substitui a ordem gravada pela geração atual. Invencibilidade narrativa exige carreira da Esquerda, confronto final e ID do chefe narrativo; testes livres não habilitam essa condição.

`tools/migrate_v02.py` acrescenta campos à revisão de conteúdo 2, preserva IDs e campos não conflitantes e mantém `content/backups/pre-v02.json` e recursos da primeira versão. A migração é idempotente. A versão estrutural permanece 1 para compatibilidade com extensões aditivas.

`catalog_importer.gd` pertence somente ao Studio. Prepara uma cópia, combina patches por ID/mapeamento explícito e valida o resultado inteiro. A aplicação verifica que o projeto não mudou desde a prévia. O histórico visual guarda até 30 snapshots; desfazer/refazer reconstrói a página, invalidando referências a objetos anteriores. Abrir/criar projeto inicia outro histórico; restaurar backup e importar são operações que podem ser desfeitas.

O validador de distribuição acrescenta a exigência de origem/licença/autorização de imagens e músicas externas. Projetos podem continuar em autoria enquanto esses campos estão incompletos; a exportação é rejeitada. Vozes mantêm a exigência já existente na validação comum. Nenhuma ferramenta determina sozinha a validade jurídica da documentação fornecida.

Na exportação, Godot pode retornar zero mesmo com erro de script; por isso o pipeline verifica logs e abre o `.exe` gerado. A auditoria Python verifica o PCK real usando o [formato implementado pela Godot](https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/file_access_pack.cpp). Python participa da preparação e da auditoria de desenvolvimento; o botão do Studio executa a exportação com a própria Godot.

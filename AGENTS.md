# Fight for Democracy

## Diretrizes permanentes
- Trabalhar somente nesta pasta; preservar conteúdo e salvamentos existentes.
- Godot 4 estável, GDScript, Compatibility renderer, física fixa a 60 Hz.
- `player/` é o runtime distribuível. Nunca importar scripts de `studio/` no jogo.
- `player/runtime/` contém módulos compartilháveis. `studio/runtime/` é uma cópia gerada por `tools/prepare.py`; editar somente a origem.
- Conteúdo de autoria em `content/project.json`, versionado e validado. Alterações comuns devem ter controles visuais no Studio, sem exigir JSON manual.
- Arte, áudio e personagens temporários devem ser identificados. Não inventar biografias reais; não clonar vozes.
- Narrativa e moeda são ficção satírica. Facções são classificações editáveis de roteiro.
- Campanha padrão: 7 cargos, 113 adversários únicos e chefe reservado no confronto 114; nunca enfrentar a si mesmo. Repetir derrota mantém o confronto.
- Quatro carreiras: Direita, Esquerda, Centrão e Independentes. Lula é chefe de Direita/Centrão/Independentes; Enéas é chefe da Esquerda. Novas carreiras reservam todos os personagens marcados como chefes para o final.
- Preservar os 156 IDs existentes. Pacotes externos com outros IDs exigem mapeamento explícito; importação é uma transação validada, nunca uma substituição silenciosa.
- Saves sem schedule_rules usam compatibilidade legada; nunca regenerar a ordem salva. Novas carreiras usam schedule_rules=2.
- Paradoxo da URNA-X só habilita invencibilidade no último confronto da história da Esquerda, com aviso explícito. Versus e testes livres permitem KO.
- Cancelamentos precisam de destinos e janela explícitos. O frame da simulação governa animação, hitbox e surgimento de projétil; projéteis preservam a identidade do ataque que os originou.
- Treinamento e testes do Studio não escrevem no progresso oficial.
- Fama entre 0 e 100, saldo não negativo, upgrades limitados.
- Validar antes de salvar/importar/exportar; arquivos locais com esquema, escrita atômica e backup.
- Executar `tools/Test.ps1` após mudanças relevantes. Não declarar exportação concluída sem executável e código de saída válidos.
- Atualizar README e `docs/STATUS.md`, explicitando limitações e testes realizados.
- Não fazer commits, push, publicar ou enviar mensagens externas sem autorização do usuário.

## Developer Studio 0.3
- Manter as onze seções principais e os módulos antigos acessíveis em Configurações. Preservar edições ao navegar e confirmar fechamento com dados pendentes.
- Tema em `studio/editor/studio_theme.gd`; biblioteca em `resource_library.gd`/`resource_panel.gd`; publicação em `release_history.gd`/`publication_panel.gd`/`export_manager.gd`.
- `controls_config.gd`, `controls_panel.gd` e `input_system.gd` são compartilhados. Padrões no projeto; preferências pessoais somente em `user://controls.json`. Testes devem usar caminhos isolados.
- Recursos da biblioteca só podem ser removidos após conferir dependências. Preservar bytes necessários para desfazer/backups; não limpar assets indiscriminadamente.
- Exportar em pastas novas por compilação; selecionar a versão atual somente após verificar exe/PCK e inicialização. Nunca sobrescrever instalação em execução.
- Licenças incompletas bloqueiam a exportação padrão. Omissão de recursos requer seleção explícita, deve constar no manifesto e não pode alterar a autoria.
- Pacote Steam é preparação local e manual; não afirmar upload/publicação sem integração real.
- Verificar layout em 1366 × 768 e 1920 × 1080. `tools/test_exports.py` usa fixture isolada para testar dois executáveis e atualização com versão anterior em execução.
- Documentar testes de hardware físico separadamente de entradas sintéticas; consultar `docs/UX_DEVELOPER_STUDIO.md`.

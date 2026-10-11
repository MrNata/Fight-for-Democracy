# Importação do catálogo e das quatro campanhas — v0.2

## Arquivos procurados

A inspeção do workspace `D:\Fight for Democracy` não encontrou estes arquivos mencionados no pedido:

| Arquivo | Estado |
|---|---|
| `personagens_156_v2.json` | Ausente |
| `campanhas_4_rotas_114_lutas.json` | Ausente |
| `catalogo_156_golpes.md` | Ausente |
| `guia_importacao_developer_studio.md` | Ausente |
| `PROMPT_CODEX_IMPORTACAO.md` | Ausente |

`README.md` e o conteúdo de autoria `content/project.json` já existiam. Foram preservados os 156 IDs, atributos, golpes e demais campos compatíveis. Os dois registros de chefe temporário conservaram seus IDs e passaram a usar os nomes satíricos pedidos. Isso não equivale à importação do elenco externo ou a 156 personagens finalizados. Não foram inventadas biografias para preencher a ausência.

## Operação visual

No Dashboard do Studio, **Exportar modelo de importação com os IDs atuais** produz um JSON com os 156 registros completos e quatro rotas válidas. Edite o pacote com uma ferramenta apropriada, ou adapte um catálogo externo para esse contrato. **Importar catálogo de 156 personagens / quatro rotas** abre o arquivo, valida a prévia e mostra o resultado. **Aplicar ao projeto** faz uma única alteração em memória. **Desfazer** reverte toda a importação; **Salvar** grava o projeto e preserva a versão anterior em `.bak`.

O pacote exige 156 entradas, cobrindo todos os IDs atuais uma vez. Cada entrada pode omitir campos: o importador combina objetos por chave e conserva o conteúdo omitido, incluindo golpes. Arrays fornecidos substituem apenas aquele array. `null` não significa “preservar”: ele substitui o valor e será rejeitado quando contrariar o esquema. IDs desconhecidos ou duplicados, catálogo incompleto, distribuição diferente de 40/40/40/36, valores inválidos, arquivos ausentes e carreiras inconsistentes são rejeitados antes de qualquer alteração. Uma prévia expira quando o projeto é editado depois de sua preparação.

## Contrato do pacote

Catálogo, versão 1:

```json
{
  "format": "ffd.catalog",
  "version": 1,
  "characters": [
    {
      "id": "teste_aurora",
      "name": "Nome satírico fornecido pelo autor",
      "stats": {"health": 120}
    }
  ]
}
```

O trecho ilustra uma entrada; o arquivo real precisa das 156. `routes` é opcional neste formato. O projeto completo continua com `schema_version: 1`, usando extensões aditivas de conteúdo da revisão 2. Um projeto completo se abre por **Abrir projeto**; um pacote se abre por **Importar catálogo**. O importador não tenta adivinhar formatos desconhecidos.

Pacote somente de campanhas:

```json
{
  "format": "ffd.campaigns",
  "version": 1,
  "routes": {
    "direita": [],
    "esquerda": [],
    "centrao": [],
    "independente": []
  }
}
```

Os arrays acima são abreviados. Cada um exige 114 objetos deste tipo:

```json
{
  "opponent": "esquerda_002",
  "rank": 0,
  "arena": "praca",
  "difficulty": 0,
  "reward": 100,
  "boss": false
}
```

Os cargos são índices 0–6, em ordem, com 7/10/17/18/19/20/22 lutas. O objeto 114 tem `rank: 6`, `boss: true` e o chefe configurado na facção. Nenhum ID se repete. Chefes não entram nas primeiras 113 lutas. Adversários comuns pertencem a outras facções; a exceção de mesma facção vale para o chefe final. Todas as escolhas de personagem elegíveis das quatro facções são verificadas. Importar rotas altera carreiras futuras; a sequência dos saves existentes continua gravada no perfil.

## Catálogo externo com outros IDs

Para preservar saves, traduza explicitamente os IDs externos:

```json
{
  "format": "ffd.catalog",
  "version": 1,
  "id_map": {"id_externo_aurora": "teste_aurora"},
  "characters": []
}
```

O exemplo de mapeamento é parcial. As 156 entradas reais devem resultar em 156 destinos existentes e únicos. O mesmo mapeamento traduz `opponent` nas rotas fornecidas. O mapeamento nunca renomeia IDs internos ou apaga registros. Metadados desconhecidos são conservados, mas não viram comportamentos executáveis automaticamente.

## Recursos, golpes e limitações

Imagens e áudio devem estar em `assets/` do projeto aberto antes da aplicação do pacote. O importador JSON não copia diretórios externos nem baixa arquivos. Use a importação visual de recursos, que verifica decodificação e copia os arquivos. Vozes exigem origem, licença e autorização. Imagens de personagem, backgrounds e músicas de arena têm campos visuais de licença e são bloqueados na exportação quando esse registro está ausente. Registrar uma licença não substitui verificar os direitos de distribuição.

Os dez slots de ação executáveis são `light_punch`, `heavy_punch`, `light_kick`, `heavy_kick`, `throw`, `counter`, `special_a`, `special_b`, `super` e `finisher`. O runtime atual executa golpes diretos e projéteis, com regras de fama, frames, prioridade, stun, knockback e defesa. Trechos de animação e colisões podem ser editados. Outros comportamentos do pedido — invocação, armadilhas, transformação, sequências cinematográficas e efeitos próprios — ainda precisam de implementação. O Markdown do catálogo de golpes e formatos externos não fornecidos não são interpretados automaticamente.

Lula e Enéas continuam com arte procedural e golpes de base identificados como temporários. A arena Trono da URNA-X tem desenho procedural distinto. O Studio possui um editor básico de chefes; tamanho gigante, múltiplas fases, músicas por fase, câmera e eventos cinematográficos estão registrados como próximos incrementos.

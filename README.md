# pqc-migration-lab

Base de estudo e experimentos de uma pesquisa sobre engenharia da migração pós-quântica (custo da troca de chaves híbrida no TLS 1.3).

```
docs/          # site Fumadocs: Aulas (uma pasta por aula), Artigo e Referência
experiments/   # scripts e resultados dos experimentos
```

## Rodar o site

```bash
cd docs
pnpm install
pnpm dev
```

Abra http://localhost:3000.

## Adicionar uma aula

1. Criar `docs/content/docs/aulas/aula-NN-tema/` com `meta.json`, `index.mdx` e as páginas do tópico.
2. Registrar a pasta em `docs/content/docs/aulas/meta.json` e acrescentar a linha na tabela de `aulas/index.mdx` e as ligações em `aulas/conceitos.mdx`.
3. Atualizar o catálogo de vídeos e figuras: `pnpm fontes` (dentro de `docs/`).

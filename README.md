# pqc-migration-lab

Base de estudo e experimentos de uma pesquisa sobre engenharia da migração pós-quântica (custo da troca de chaves híbrida no TLS 1.3).

## Ideia do repositório

A documentação foi montada com [Fumadocs](https://fumadocs.dev), para ter um site navegável com páginas curtas, figuras e vídeos. Por questão de aprendizado, a pasta de **aulas** reorganiza o conteúdo de cada aula e, ao fim de cada página, relaciona o que foi aprendido com o tema do artigo. A ideia é entender os fundamentos (modelo de ameaça, cifras, modos de operação, criptografia pós-quântica) e ver onde cada um entra na pesquisa. O artigo em si é escrito em LaTeX, no Overleaf.

## Estrutura de pastas

```
docs/                       # site Fumadocs
  content/docs/
    aulas/                  # uma pasta por aula (aula-NN-tema): páginas curtas,
                            # exercícios resolvidos, revisão e mapa de conceitos
    artigo/                 # escopo, hipóteses, modelo de ameaças, experimentos e cronograma
    referencia/             # glossário e catálogo de fontes (vídeos e figuras)
experiments/
  e1-bytes-handshake/       # script, README e resultados dos experimentos
```

## Rodar o site

```bash
cd docs
pnpm install
pnpm dev
```

Abra http://localhost:3000.

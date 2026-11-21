// Gera content/docs/referencia/fontes.mdx a partir dos componentes <Video> e <Figure>
// usados nas páginas de aulas e do artigo. Rodar com: pnpm fontes
import { readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

const ROOT = new URL('../content/docs/', import.meta.url).pathname;
const SAIDA = join(ROOT, 'referencia', 'fontes.mdx');

function listar(dir) {
  return readdirSync(dir).flatMap((nome) => {
    const caminho = join(dir, nome);
    return statSync(caminho).isDirectory() ? listar(caminho) : [caminho];
  });
}

const arquivos = listar(ROOT)
  .filter((f) => f.endsWith('.mdx') && !f.includes(`${sep}referencia${sep}`))
  .sort();

const esc = (s) => s.replaceAll('|', '\\|');
const videosPorGrupo = new Map();
const figurasPorGrupo = new Map();

function grupoDe(arquivo) {
  const partes = relative(ROOT, arquivo).split(sep);
  return partes[0] === 'aulas' && partes[1] ? partes[1] : partes[0];
}

function tituloDe(texto, padrao) {
  return (texto.match(/^title:\s*(.+)$/m)?.[1]?.trim() ?? padrao).replace(/^"(.*)"$/, '$1');
}

function rotuloGrupo(grupo, arquivos) {
  if (grupo === 'artigo') return 'Artigo';
  const indice = arquivos.find((f) => grupoDe(f) === grupo && f.endsWith(`${sep}index.mdx`));
  return indice ? tituloDe(readFileSync(indice, 'utf8'), grupo) : grupo;
}

for (const arquivo of arquivos) {
  const texto = readFileSync(arquivo, 'utf8');
  const grupo = grupoDe(arquivo);
  const url = `/docs/${relative(ROOT, arquivo).replace(/\.mdx$/, '').replace(/(^|[\\/])index$/, '').split(sep).join('/')}`.replace(/\/$/, '');
  const pagina = `[${esc(tituloDe(texto, url))}](${url})`;

  for (const m of texto.matchAll(/<Video\s+id="([^"]+)"\s+title="([^"]*)"\s+meta="([^"]*)"\s*\/>/g)) {
    const lista = videosPorGrupo.get(grupo) ?? [];
    lista.push(`| ${esc(m[2])} | ${esc(m[3])} | [YouTube](https://www.youtube.com/watch?v=${m[1]}) | ${pagina} |`);
    videosPorGrupo.set(grupo, lista);
  }
  for (const m of texto.matchAll(/<Figure[\s\S]*?credit="([^"]*)"[\s\S]*?href="([^"]*)"[\s\S]*?\/>/g)) {
    const alt = m[0].match(/alt="([^"]*)"/)?.[1] ?? 'figura';
    const lista = figurasPorGrupo.get(grupo) ?? [];
    lista.push(`| ${esc(alt)} | ${esc(m[1])} | [Origem](${m[2]}) | ${pagina} |`);
    figurasPorGrupo.set(grupo, lista);
  }
}

const grupos = [...new Set([...videosPorGrupo.keys(), ...figurasPorGrupo.keys()])].sort();
let corpo = '';
for (const grupo of grupos) {
  corpo += `\n## ${rotuloGrupo(grupo, arquivos)}\n`;
  if (videosPorGrupo.has(grupo)) {
    corpo += `\n### Vídeos\n\n| Título | Canal, duração e idioma | Link | Página |\n|--------|-------------------------|------|--------|\n${videosPorGrupo.get(grupo).join('\n')}\n`;
  }
  if (figurasPorGrupo.has(grupo)) {
    corpo += `\n### Figuras\n\n| Figura | Autoria e licença | Origem | Página |\n|--------|-------------------|--------|--------|\n${figurasPorGrupo.get(grupo).join('\n')}\n`;
  }
}

const total = (m) => [...m.values()].reduce((n, l) => n + l.length, 0);
const conteudo = `---
title: Fontes de mídia
description: Catálogo de vídeos e figuras usados, com canal, autoria e licença
---

Catálogo gerado automaticamente a partir das páginas (\`pnpm fontes\`). Todas as figuras vêm de fontes públicas, com a autoria e a licença originais, e todos os vídeos são de canais externos, usados como material complementar.

**Totais:** ${total(videosPorGrupo)} vídeos e ${total(figurasPorGrupo)} figuras.
${corpo}`;

writeFileSync(SAIDA, conteudo);
console.log(`fontes.mdx: ${total(videosPorGrupo)} vídeos, ${total(figurasPorGrupo)} figuras`);

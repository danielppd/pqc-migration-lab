type FigureProps = {
  /** URL direta da imagem na fonte original (não é cópia nem imagem gerada) */
  src: string;
  alt: string;
  caption: string;
  /** Autoria e licença, ex.: "Amirki, CC BY-SA 3.0" */
  credit: string;
  /** Página de origem, onde estão autoria e licença completas */
  href: string;
};

/** Imagem de fonte externa com legenda, crédito e link para a origem. */
export function Figure({ src, alt, caption, credit, href }: FigureProps) {
  return (
    <figure className="my-6 rounded-lg border bg-white p-3 text-center dark:bg-neutral-100">
      {/* biome-ignore lint/performance/noImgElement: imagem externa de fonte original */}
      <img
        src={src}
        alt={alt}
        loading="lazy"
        className="mx-auto max-h-[28rem] w-auto"
      />
      <figcaption className="mt-2 text-sm text-neutral-700">
        {caption}{" "}
        <a
          href={href}
          target="_blank"
          rel="noreferrer"
          className="font-medium text-neutral-900 underline"
        >
          Fonte: {credit}
        </a>
      </figcaption>
    </figure>
  );
}

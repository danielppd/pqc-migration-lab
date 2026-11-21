type VideoProps = {
  /** ID do vídeo no YouTube (o trecho depois de watch?v=) */
  id: string;
  title: string;
  /** Canal, duração e idioma, ex.: "Computerphile, 7 min, inglês" */
  meta: string;
};

/** Vídeo do YouTube embutido, com título, canal e duração visíveis para você decidir se vale assistir. */
export function Video({ id, title, meta }: VideoProps) {
  return (
    <figure className="my-6">
      <div
        className="relative w-full overflow-hidden rounded-lg border"
        style={{ paddingTop: "56.25%" }}
      >
        <iframe
          className="absolute inset-0 h-full w-full"
          src={`https://www.youtube-nocookie.com/embed/${id}`}
          title={title}
          loading="lazy"
          allow="accelerometer; encrypted-media; picture-in-picture"
          allowFullScreen
        />
      </div>
      <figcaption className="mt-2 text-sm text-fd-muted-foreground">
        <strong>{title}</strong> ({meta}).{" "}
        <a
          href={`https://www.youtube.com/watch?v=${id}`}
          target="_blank"
          rel="noreferrer"
          className="underline"
        >
          Abrir no YouTube
        </a>
      </figcaption>
    </figure>
  );
}

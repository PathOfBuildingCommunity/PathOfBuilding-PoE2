// PoE2 passive tree artwork, converted from the game's DDS atlases by scripts/build_tree_art.py.

interface AtlasInfo {
  w: number;
  h: number;
  kind: "sheet" | "files";
  cols?: number;
}

interface Manifest {
  version: string;
  atlases: Record<string, AtlasInfo>;
  names: Record<string, [string, number][]>;
}

export interface Sprite {
  img: HTMLImageElement;
  sx: number;
  sy: number;
  sw: number;
  sh: number;
  /** Original layer size in texture pixels (PoB draws assets at twice this, centred). */
  w: number;
  h: number;
}

export class TreeArt {
  private images = new Map<string, HTMLImageElement>();

  constructor(private base: string, private manifest: Manifest, private onLoad: () => void) {}

  static async load(version: string, onLoad: () => void): Promise<TreeArt | null> {
    const base = `/tree-art/${version}`;
    try {
      const res = await fetch(`${base}/manifest.json`);
      if (!res.ok) return null;
      return new TreeArt(base, (await res.json()) as Manifest, onLoad);
    } catch {
      return null;
    }
  }

  private image(url: string): HTMLImageElement | null {
    let img = this.images.get(url);
    if (!img) {
      img = new Image();
      img.decoding = "async";
      img.onload = this.onLoad;
      img.src = url;
      this.images.set(url, img);
    }
    return img.complete && img.naturalWidth > 0 ? img : null;
  }

  /** Resolve an asset name. Icons exist in both colour and greyed ("skills-disabled") atlases. */
  sprite(name: string | undefined, disabled = false): Sprite | null {
    if (!name) return null;
    const entries = this.manifest.names[name];
    if (!entries?.length) return null;
    const entry = entries.find(([id]) => id.startsWith("skills-disabled") === disabled) ?? entries[0];
    const [id, index] = entry;
    const atlas = this.manifest.atlases[id];
    if (!atlas) return null;
    if (atlas.kind === "files") {
      const img = this.image(`${this.base}/${id}/${index}.webp`);
      return img && { img, sx: 0, sy: 0, sw: img.naturalWidth, sh: img.naturalHeight, w: atlas.w, h: atlas.h };
    }
    const img = this.image(`${this.base}/${id}.webp`);
    const cols = atlas.cols ?? 1;
    return img && { img, sx: ((index - 1) % cols) * atlas.w, sy: Math.floor((index - 1) / cols) * atlas.h, sw: atlas.w, sh: atlas.h, w: atlas.w, h: atlas.h };
  }
}

import { Check, Copy } from "lucide-react";
import { useEffect, useState } from "react";
import { api } from "../api/client";
import { useBuildMutation, useClasses } from "../api/hooks";
import type { BuildInfo } from "../api/types";
import { ErrorText } from "./ErrorText";
import { Modal } from "./Modal";

export function ImportDialog({ onClose }: { onClose: () => void }) {
  const [source, setSource] = useState("");
  const m = useBuildMutation((s: string) => api.post<BuildInfo>("/build/import", { source: s }));
  return (
    <Modal title="Import build" onClose={onClose}>
      <label className="label">Share code, XML, or a link (pobb.in, pastebin, poe.ninja paste or poe.ninja character page). Links can be re-imported later with Update.</label>
      <textarea className="input mt-1.5 h-40 font-mono text-xs" value={source} onChange={(e) => setSource(e.target.value)} autoFocus />
      <ErrorText error={m.error} />
      <div className="mt-3 flex justify-end">
        <button className="btn btn-primary" disabled={!source.trim() || m.isPending} onClick={() => m.mutate(source, { onSuccess: onClose })}>
          {m.isPending ? "Importing…" : "Import"}
        </button>
      </div>
    </Modal>
  );
}

export function NewBuildDialog({ onClose }: { onClose: () => void }) {
  const { data: classes } = useClasses();
  const [className, setClassName] = useState("");
  const [ascendancy, setAscendancy] = useState("");
  const [level, setLevel] = useState(1);
  const m = useBuildMutation(() =>
    api.post<BuildInfo>("/build/new", { className: className || null, ascendancy: ascendancy || null, level }),
  );
  const ascList = classes?.find((c) => c.name === className)?.ascendancies ?? [];
  return (
    <Modal title="New build" onClose={onClose}>
      <div className="grid grid-cols-3 gap-3">
        <label className="col-span-1">
          <span className="label">Class</span>
          <select className="input mt-1" value={className} onChange={(e) => { setClassName(e.target.value); setAscendancy(""); }}>
            <option value="">Default</option>
            {classes?.map((c) => <option key={c.id}>{c.name}</option>)}
          </select>
        </label>
        <label className="col-span-1">
          <span className="label">Ascendancy</span>
          <select className="input mt-1" value={ascendancy} onChange={(e) => setAscendancy(e.target.value)} disabled={!ascList.length}>
            <option value="">None</option>
            {ascList.map((a) => <option key={a}>{a}</option>)}
          </select>
        </label>
        <label className="col-span-1">
          <span className="label">Level</span>
          <input type="number" min={1} max={100} className="input mt-1" value={level} onChange={(e) => setLevel(Number(e.target.value))} />
        </label>
      </div>
      <p className="mt-3 text-xs text-ink-400">This replaces the current build. Export it first if you want to keep it.</p>
      <ErrorText error={m.error} />
      <div className="mt-3 flex justify-end">
        <button className="btn btn-primary" disabled={m.isPending} onClick={() => m.mutate(undefined, { onSuccess: onClose })}>Create</button>
      </div>
    </Modal>
  );
}

export function ExportDialog({ onClose }: { onClose: () => void }) {
  const [data, setData] = useState<{ code: string } | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [copied, setCopied] = useState(false);
  useEffect(() => {
    api.get<{ code: string }>("/build/export").then(setData, setError);
  }, []);
  const copy = async () => {
    if (!data) return;
    await navigator.clipboard.writeText(data.code);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };
  return (
    <Modal title="Export build" onClose={onClose}>
      <label className="label">Path of Building share code</label>
      <textarea readOnly className="input mt-1.5 h-40 font-mono text-xs" value={data?.code ?? "Generating…"} onFocus={(e) => e.target.select()} />
      <ErrorText error={error} />
      <div className="mt-3 flex justify-end">
        <button className="btn btn-primary" disabled={!data} onClick={copy}>
          {copied ? <Check size={14} /> : <Copy size={14} />} {copied ? "Copied" : "Copy code"}
        </button>
      </div>
    </Modal>
  );
}

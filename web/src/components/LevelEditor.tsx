import { useEffect, useState } from "react";
import { api } from "../api/client";
import { useBuildMutation } from "../api/hooks";

export function LevelEditor({ level }: { level: number }) {
  const [value, setValue] = useState(String(level));
  useEffect(() => setValue(String(level)), [level]);
  const m = useBuildMutation((lvl: number) => api.post("/build/character", { level: lvl }));
  const commit = () => {
    const n = Math.min(100, Math.max(1, Number(value) || 1));
    if (n !== level) m.mutate(n);
    else setValue(String(level));
  };
  return (
    <label className="flex items-center gap-1 text-ink-400">
      Level
      <input
        className="w-12 rounded border border-transparent bg-transparent px-1 text-ink-200 tabular-nums hover:border-ink-600 focus:border-gold focus:outline-none"
        value={value}
        onChange={(e) => setValue(e.target.value.replace(/\D/g, ""))}
        onBlur={commit}
        onKeyDown={(e) => e.key === "Enter" && (e.target as HTMLInputElement).blur()}
      />
    </label>
  );
}

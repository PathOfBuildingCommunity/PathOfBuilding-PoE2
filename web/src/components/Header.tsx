import { Download, FilePlus2, Radio, Upload } from "lucide-react";
import { useState } from "react";
import type { BuildInfo } from "../api/types";
import { ExportDialog, ImportDialog, NewBuildDialog } from "./BuildDialogs";
import { LevelEditor } from "./LevelEditor";

type Dialog = "import" | "export" | "new" | null;

export function Header({ info, revision }: { info?: BuildInfo; revision?: number }) {
  const [dialog, setDialog] = useState<Dialog>(null);
  const close = () => setDialog(null);
  return (
    <header className="flex flex-wrap items-center gap-x-6 gap-y-2 border-b border-ink-700 bg-ink-900 px-4 py-2.5">
      <div className="flex items-center gap-2">
        <div className="h-6 w-6 rounded-full border-[5px] border-gold bg-ink-950" />
        <span className="font-semibold tracking-wide text-gold-soft">PoB2 Enhanced</span>
      </div>
      {info && (
        <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm">
          <span className="text-ink-200">
            {info.ascendClassName ?? info.className}
            {info.ascendClassName && <span className="text-ink-400"> ({info.className})</span>}
          </span>
          <LevelEditor level={info.level} />
          <span className="text-ink-400">Passives <span className="text-ink-200">{info.pointsUsed}</span></span>
          <span className="text-ink-400">Ascendancy <span className="text-ink-200">{info.ascendancyPointsUsed}</span></span>
          {info.mainSkill && <span className="text-ink-400">Main <span className="text-gold-soft">{info.mainSkill}</span></span>}
        </div>
      )}
      <div className="ml-auto flex items-center gap-2">
        <span className="hidden items-center gap-1 text-xs text-ink-400 sm:flex" title="The UI refreshes when the build changes (including changes made by an AI agent over MCP)">
          <Radio size={12} className="text-good" /> live · rev {revision ?? "–"}
        </span>
        <button className="btn" onClick={() => setDialog("new")}><FilePlus2 size={14} /> New</button>
        <button className="btn" onClick={() => setDialog("import")}><Upload size={14} /> Import</button>
        <button className="btn btn-primary" onClick={() => setDialog("export")}><Download size={14} /> Export</button>
      </div>
      {dialog === "import" && <ImportDialog onClose={close} />}
      {dialog === "export" && <ExportDialog onClose={close} />}
      {dialog === "new" && <NewBuildDialog onClose={close} />}
    </header>
  );
}

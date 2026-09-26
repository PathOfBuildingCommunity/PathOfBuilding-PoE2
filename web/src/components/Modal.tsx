import { X } from "lucide-react";
import { useEffect, type ReactNode } from "react";

export function Modal({ title, onClose, children, wide }: { title: string; onClose: () => void; children: ReactNode; wide?: boolean }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/60 p-4 pt-[10vh]" onMouseDown={onClose}>
      <div className={`panel w-full ${wide ? "max-w-3xl" : "max-w-lg"} shadow-2xl`} onMouseDown={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between border-b border-ink-700 px-4 py-3">
          <h2 className="font-semibold text-gold-soft">{title}</h2>
          <button className="btn btn-ghost" onClick={onClose} aria-label="Close"><X size={16} /></button>
        </div>
        <div className="p-4">{children}</div>
      </div>
    </div>
  );
}

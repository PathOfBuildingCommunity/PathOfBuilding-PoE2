import { Check, Copy } from "lucide-react";
import { useState } from "react";

function CopyBlock({ title, text }: { title: string; text: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="panel overflow-hidden">
      <div className="flex items-center justify-between border-b border-ink-700 px-3 py-2">
        <span className="text-sm text-ink-200">{title}</span>
        <button className="btn btn-ghost text-xs" onClick={async () => { await navigator.clipboard.writeText(text); setCopied(true); setTimeout(() => setCopied(false), 1200); }}>
          {copied ? <Check size={13} /> : <Copy size={13} />} {copied ? "Copied" : "Copy"}
        </button>
      </div>
      <pre className="overflow-x-auto p-3 text-xs text-ink-200"><code>{text}</code></pre>
    </div>
  );
}

export function AiTab() {
  const url = `${window.location.origin}/mcp`;
  return (
    <div className="mx-auto max-w-3xl space-y-5 p-4 text-sm leading-6">
      <section>
        <h2 className="text-lg font-semibold text-gold-soft">Connect an AI agent</h2>
        <p className="text-ink-400">
          This server exposes the build you are viewing as an MCP endpoint. Agents connected to it read and edit the same
          live build, and this page refreshes as they work.
        </p>
      </section>
      <CopyBlock title="Claude Code" text={`claude mcp add --transport http pob2 ${url}`} />
      <CopyBlock
        title="Claude Desktop / other MCP clients (claude_desktop_config.json)"
        text={JSON.stringify({ mcpServers: { pob2: { type: "http", url } } }, null, 2)}
      />
      <CopyBlock
        title="Standalone stdio server (no web UI needed)"
        text={JSON.stringify({ mcpServers: { pob2: { command: "uv", args: ["run", "--directory", "<repo>/python", "pob2-mcp"] } } }, null, 2)}
      />
      <section>
        <h3 className="label mb-2">Things to ask</h3>
        <ul className="list-disc space-y-1 pl-5 text-ink-200">
          <li>Load this build and tell me its three biggest defensive weaknesses: &lt;share code&gt;</li>
          <li>Find the best 5 passive points for more spell damage and show the DPS gain per point.</li>
          <li>Compare these two rings for my build and equip the better one.</li>
          <li>Set the enemy to a pinnacle boss that is shocked and exposed, then report DPS.</li>
        </ul>
      </section>
      <section>
        <h3 className="label mb-2">REST API</h3>
        <p className="text-ink-400">
          Every UI action is also a plain JSON endpoint. See <a className="text-gold hover:underline" href="/docs" target="_blank" rel="noreferrer">/docs</a> for the OpenAPI reference.
        </p>
      </section>
    </div>
  );
}

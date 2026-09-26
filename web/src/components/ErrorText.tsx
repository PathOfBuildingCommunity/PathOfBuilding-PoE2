export function ErrorText({ error }: { error: unknown }) {
  if (!error) return null;
  return <p className="mt-2 rounded border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{error instanceof Error ? error.message : String(error)}</p>;
}

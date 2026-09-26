import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// Dev: `npm run dev` proxies the API to `pob2-web` on :8080.
// Build output is served by the Python web app (python/src/pob2/web/static).
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    proxy: {
      "/api": "http://127.0.0.1:8080",
      "/mcp": "http://127.0.0.1:8080",
    },
  },
  build: {
    outDir: "../python/src/pob2/web/static",
    emptyOutDir: true,
  },
});

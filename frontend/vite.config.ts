import { fileURLToPath, URL } from "node:url";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

export default defineConfig({
    plugins: [react(), tailwindcss()],
    // Django uses the manifest to distinguish versioned build assets from unchanged public/ files.
    build: { manifest: true },
    resolve: {
        alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) },
    },
    server: {
        host: "127.0.0.1",
        port: Number(process.env.FRONTEND_PORT ?? 5173),
        strictPort: true,
        proxy: {
            // Same-origin /api keeps Django's session cookie and CSRF checks intact.
            "/api": {
                target: `http://127.0.0.1:${process.env.DJANGO_PORT ?? 8000}`,
                changeOrigin: false,
            },
        },
    },
});

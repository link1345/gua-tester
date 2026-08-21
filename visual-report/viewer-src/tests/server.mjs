import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer } from "node:http";
import { dirname, extname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../dist");
const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".json": "application/json; charset=utf-8", ".png": "image/png" };
const server = createServer(async (request, response) => {
  const url = new URL(request.url || "/", "http://127.0.0.1");
  if (!url.pathname.startsWith("/sample-repo/")) { response.writeHead(404).end(); return; }
  const requested = decodeURIComponent(url.pathname.slice("/sample-repo/".length)) || "index.html";
  const file = resolve(root, requested);
  const child = relative(root, file);
  if (!child || child.startsWith("..") || child.includes(":\\")) { response.writeHead(403).end(); return; }
  try {
    const info = await stat(file);
    if (!info.isFile()) throw new Error("not a file");
    response.writeHead(200, { "content-type": types[extname(file)] || "application/octet-stream" });
    createReadStream(file).pipe(response);
  } catch { response.writeHead(404).end(); }
});
server.listen(4323, "127.0.0.1");

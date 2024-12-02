import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, normalize } from "node:path";

const root = process.cwd();
const port = Number(process.env.PORT || 4173);
const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".wgsl": "text/plain; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml"
};

createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, `http://${request.headers.host}`).pathname);
    const relative = pathname === "/" ? "index.html" : pathname.slice(1);
    const target = normalize(join(root, relative));
    if (!target.startsWith(root)) throw new Error("Invalid path");
    if (!(await stat(target)).isFile()) throw new Error("Not a file");
    response.writeHead(200, { "Content-Type": types[extname(target)] || "application/octet-stream" });
    response.end(await readFile(target));
  } catch {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Not found");
  }
}).listen(port, "127.0.0.1", () => {
  console.log(`Lunaland running at http://127.0.0.1:${port}`);
});

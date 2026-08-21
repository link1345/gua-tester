import { cp, mkdir, rm } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const source = resolve(root, "dist");
const target = resolve(root, "..");
const viewer = resolve(target, "viewer");
if (viewer === target || !viewer.endsWith(`${process.platform === "win32" ? "\\" : "/"}viewer`)) {
  throw new Error(`Refusing to replace unsafe viewer path: ${viewer}`);
}
await rm(viewer, { recursive: true, force: true });
await mkdir(viewer, { recursive: true });
await cp(source, viewer, { recursive: true });

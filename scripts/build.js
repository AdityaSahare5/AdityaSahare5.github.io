// Build step: copy src/ to dist/ and stamp build information.
// In a real project this is where bundling/minifying would happen.
const fs = require("fs");
const path = require("path");

const src = path.join(__dirname, "..", "src");
const dist = path.join(__dirname, "..", "dist");

fs.rmSync(dist, { recursive: true, force: true });
fs.cpSync(src, dist, { recursive: true });

const info = {
  commit: (process.env.COMMIT_SHA || "local").slice(0, 7),
  run: process.env.RUN_NUMBER || "local",
  builtAt: new Date().toISOString(),
};
fs.writeFileSync(path.join(dist, "build.json"), JSON.stringify(info, null, 2));

console.log("Built dist/ with", info);

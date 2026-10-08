#!/usr/bin/env node
// Validates planning/timeline.json and renders a timing animatic to preview/animatic_v1.mp4
// (ffmpeg drawtext, no external media). Usage: node ae/scripts/build-animatic.mjs [--check-only]
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const T = JSON.parse(readFileSync(join(root, "planning/timeline.json"), "utf8"));
const errors = [];
const eps = 1e-6;

// ---- validation
let cursor = 0;
for (const s of T.shots) {
  if (Math.abs(s.start - cursor) > eps) errors.push(`${s.id} starts at ${s.start}, expected ${cursor}`);
  if (Math.abs((s.start / T.beatSeconds) % 1) > eps) errors.push(`${s.id} cut not on beat`);
  cursor = s.end;
}
if (Math.abs(cursor - T.duration) > eps) errors.push(`shots end at ${cursor}, film is ${T.duration}`);
for (const [version, lines] of Object.entries(T.narration)) {
  for (const n of lines) {
    if (n.start < 0 || n.end > T.duration || n.end <= n.start) errors.push(`${version} ${n.id} window invalid`);
  }
  for (let i = 1; i < lines.length; i++) if (lines[i].start < lines[i - 1].end) errors.push(`${version} ${lines[i].id} overlaps`);
}
const share = { ui: 0, higgsfield: 0, plate: 0 };
for (const s of T.shots) {
  if (!(s.base in share)) errors.push(`${s.id} unknown base "${s.base}"`);
  else share[s.base] += s.end - s.start;
}
const pct = (v) => ((v / T.duration) * 100).toFixed(1);
console.log(`shots=${T.shots.length} duration=${T.duration}s frames=${T.duration * T.fps} beats=${T.duration / T.beatSeconds}`);
console.log(`UI ${share.ui}s (${pct(share.ui)}%) / Higgsfield ${share.higgsfield}s (${pct(share.higgsfield)}%) / Plate ${share.plate}s (${pct(share.plate)}%)`);
if (share.ui / T.duration < 0.7 || share.ui / T.duration > 0.8) errors.push("UI share outside 70–80%");
if (errors.length) { console.error("TIMELINE ERRORS:\n- " + errors.join("\n- ")); process.exit(1); }
console.log("timeline OK");
if (process.argv.includes("--check-only")) process.exit(0);

// ---- animatic
const fontCandidates = [
  "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
  "/System/Library/Fonts/Hiragino Sans GB.ttc",
];
const font = fontCandidates.find(existsSync);
if (!font) { console.error("No Japanese font found for drawtext"); process.exit(1); }

const outDir = join(root, "preview");
const tmpDir = join(outDir, ".animatic-text");
mkdirSync(tmpDir, { recursive: true });
let fileIndex = 0;
// drawtext reads text from files, which avoids escaping Japanese punctuation and colons.
const textFile = (text) => {
  const p = join(tmpDir, `t${fileIndex++}.txt`);
  writeFileSync(p, text);
  return p.replace(/:/g, "\\:").replace(/'/g, "\\'");
};
const fontArg = font.replace(/:/g, "\\:");
const dt = (text, { x, y, size, color = "0xF5F5F7", from, to }) =>
  `drawtext=fontfile='${fontArg}':textfile='${textFile(text)}':x=${x}:y=${y}:fontsize=${size}:fontcolor=${color}` +
  (from !== undefined ? `:enable='between(t,${from},${to - 0.0001})'` : "");

const filters = [];
for (const s of T.shots) {
  const tint = { higgsfield: "0x1B1530", plate: "0x1F1A12" }[s.base] ?? "0x0F1A2B";
  filters.push(`drawbox=x=0:y=0:w=iw:h=ih:color=${tint}:t=fill:enable='between(t,${s.start},${s.end - 0.0001})'`);
  filters.push(dt(`${s.id} ${s.name}  ·  ${{ higgsfield: "HIGGSFIELD", plate: "PHOTO PLATE + AE" }[s.base] ?? "REAL UI"}  ·  ${s.asset}`, { x: 96, y: 72, size: 26, color: "0x8E8E93", from: s.start, to: s.end }));
  if (s.label) filters.push(dt(s.label, { x: 96, y: 120, size: 22, color: "0x8E8E93", from: s.start, to: s.end }));
  s.copy.forEach((c, i) => filters.push(dt(c, { x: 96, y: 520 + i * 96, size: s.copy.length > 2 ? 60 : 76, from: s.start, to: s.end })));
}
for (const n of T.narration.standard) filters.push(dt(`VO ${n.id}: ${n.text}`, { x: 96, y: 960, size: 30, color: "0x0A84FF", from: n.start, to: n.end }));
filters.push(`drawtext=fontfile='${fontArg}':text='%{eif\\:t\\:d\\:2}s  beat %{eif\\:floor(t*2)+1\\:d}':x=w-tw-96:y=72:fontsize=26:fontcolor=0x8E8E93`);
filters.push(`drawbox=x=0:y=ih-6:w=iw*t/${T.duration}:h=6:color=0x0A84FF:t=fill`);

const filterPath = join(tmpDir, "filter.txt");
writeFileSync(filterPath, filters.join(",\n"));
const out = join(outDir, "animatic_v1.mp4");
execFileSync("ffmpeg", [
  "-hide_banner", "-loglevel", "error", "-y",
  "-f", "lavfi", "-i", `color=c=0x0A0A0B:s=${T.width}x${T.height}:r=${T.fps}:d=${T.duration}`,
  "-filter_script:v", filterPath,
  "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", "-movflags", "+faststart", out,
], { stdio: "inherit" });
console.log(`wrote ${out}`);

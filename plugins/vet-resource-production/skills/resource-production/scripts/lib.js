// Shared helpers: config, paths, the work order file, dates, CSV, and the register column maps.
"use strict";
const fs = require("fs");
const path = require("path");
const os = require("os");

const SKILL_DIR = path.resolve(__dirname, "..");
function expand(p) { return p ? p.replace(/^~(?=$|[\\/])/, os.homedir()) : p; }
function loadConfig() {
  const cfg = JSON.parse(fs.readFileSync(path.join(SKILL_DIR, "config", "loop.config.json"), "utf8").replace(/^﻿/, ""));
  cfg.buildRoot = expand(cfg.buildRoot); cfg.registerMirror = expand(cfg.registerMirror); cfg.serviceAccountKey = expand(cfg.serviceAccountKey);
  for (const k of Object.keys(cfg.skills)) cfg.skills[k] = expand(cfg.skills[k]);
  return cfg;
}
function today() { return new Date().toISOString().slice(0, 10); }
function readJson(p) { return JSON.parse(fs.readFileSync(p, "utf8").replace(/^﻿/, "")); }
function writeJson(p, o) { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, JSON.stringify(o, null, 2)); }
function fail(msg, code) { console.error("STOP: " + msg); process.exit(code || 2); }
function arg(name, dflt) { const i = process.argv.indexOf("--" + name); if (i < 0) return dflt; const v = process.argv[i + 1]; return (v === undefined || v.startsWith("--")) ? true : v; }
function has(name) { return process.argv.includes("--" + name); }

// The build folder for one unit in one college: <buildRoot>/<UNIT>-<COLLEGE>/
function buildDir(cfg, unit, college) { return path.join(cfg.buildRoot, `${unit}-${college}`); }
function workOrderPath(cfg, unit, college) { return path.join(buildDir(cfg, unit, college), "work-order.json"); }
function loadWorkOrder(cfg, unit, college) {
  const p = workOrderPath(cfg, unit, college);
  if (!fs.existsSync(p)) fail(`no work order at ${p} - run work-order.js first (R1)`);
  return readJson(p);
}
function saveWorkOrder(cfg, wo) { writeJson(workOrderPath(cfg, wo.unit, wo.college), wo); }
function logRun(cfg, wo, step, text) {
  const p = path.join(buildDir(cfg, wo.unit, wo.college), "run-log.md");
  const stamp = new Date().toISOString().replace("T", " ").slice(0, 19);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  if (!fs.existsSync(p)) fs.writeFileSync(p, `# Run log - ${wo.unit} ${wo.college}\n\nEvery entry is written by the command at the time. Nothing here is edited afterwards.\n\n`);
  fs.appendFileSync(p, `- ${stamp} · ${step} · ${text}\n`);
}

// CSV
function csvEscape(v) { const s = v == null ? "" : String(v); return /[",\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; }
function toCsv(rows) { return rows.map(r => r.map(csvEscape).join(",")).join("\r\n") + "\r\n"; }
function parseCsv(text) {
  const rows = []; let row = [], field = "", q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) { if (c === '"') { if (text[i + 1] === '"') { field += '"'; i++; } else q = false; } else field += c; }
    else if (c === '"') q = true;
    else if (c === ",") { row.push(field); field = ""; }
    else if (c === "\r") { /* skip */ }
    else if (c === "\n") { row.push(field); rows.push(row); row = []; field = ""; }
    else field += c;
  }
  if (field.length || row.length) { row.push(field); rows.push(row); }
  return rows;
}

// Register schemas: header names exactly as in the Google Sheets. Row ids are prefixed.
const REGISTERS = {
  tools: { prefix: "TR", sheetKey: "tools", headers: ["Row ID","Unit code","Unit release","Course","College","Document title","Type","Version","Status","Builder","Skills and versions","AI-drafted","Unit release read on","Reviewing trainer","Approver","Work order and run log","Compliance / resource report","AI verification report","Discrepancies resolved","Pack version derived from","Student AI-use rules stated","Pre-use review row","Consultation rows","Approved by","Approval date","Published to eSkilled on","Supersedes","Superseded by","Notes"] },
  preuse: { prefix: "PU", sheetKey: "preuse", headers: ["Row ID","Tool row","Unit code","Unit release checked","Date release read","Document and version","Reviewer","Reviewer holds the unit on the matrix","Reviewer is not the builder","AI verification report worked through","Validity","Reliability","Flexibility","Fairness","Sufficiency","Authenticity","Currency","Validity of evidence","Practical application components present","Findings and amendments required","Outcome","Review date","First-use date","Notes"] },
  consult: { prefix: "IC", sheetKey: "consult", headers: ["Row ID","Date","Method","Who","Organisation and role","Why relevant","Currency evidence","Course","Unit code","Documents and versions reviewed","Advice received","Decision","Change made, or reason for no change","New version produced","Recorded by","Next review trigger","Notes"] }
};
const DOC_TYPES = { tool: "Knowledge", practical: "Practical", workbook: "Workbook", assessorGuide: "Assessor guide", learnerGuide: "Learner guide", deck: "Delivery deck" };

module.exports = { SKILL_DIR, expand, loadConfig, today, readJson, writeJson, fail, arg, has, buildDir, workOrderPath, loadWorkOrder, saveWorkOrder, logRun, toCsv, parseCsv, csvEscape, REGISTERS, DOC_TYPES };

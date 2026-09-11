// R5 - the staging package: the deliverables and the attachments, nothing else from the build folder, uploaded to
// Drive > Registers > Staging > <UNIT>-<COLLEGE> > v0.x, then the tool rows set to Staged with links.
//
//   node stage-package.js --unit U --college C --version 0.3 --files files.json [--ai-rules-stated Yes]
// files.json: { "tool": "<path to the learner tool .docx>", "toolGuide": "...", "workbook": "...", "workbookGuide": "...",
//               "learnerGuide": "...", "deck": "...", "complianceReport": "...", "resourceReport": "..." }
// Requires verify/ai-verification-report.md (from verify-report.js resolve). Refuses while discrepancies are unresolved.
"use strict";
const fs = require("fs");
const path = require("path");
const L = require("./lib");
const G = require("./gapi");
const { execFileSync } = require("child_process");

const cfg = L.loadConfig();
const unit = (L.arg("unit") || "").toUpperCase(), college = (L.arg("college") || "").toUpperCase();
const version = L.arg("version"), filesPath = L.arg("files");
if (!unit || !college || !version || !filesPath) L.fail("usage: stage-package.js --unit CODE --college MVC|ACI --version 0.x --files files.json");
if (!/^0\.\d+$/.test(version)) L.fail("only a 0.x draft is staged; approval sets 1.0");
const wo = L.loadWorkOrder(cfg, unit, college);
const files = L.readJson(filesPath);
const report = path.join(wo.buildDir, "verify", "ai-verification-report.md");
if (!fs.existsSync(report)) L.fail("no AI verification report - run verify-report.js resolve first (R3/R4)");
const resolved = /Discrepancies resolved: YES/.test(fs.readFileSync(report, "utf8"));
if (!resolved) L.fail("the AI verification report still has open items - nothing unresolved reaches staging (R4)");

for (const d of wo.documents) if (!files[d.key] || !fs.existsSync(files[d.key])) L.fail(`files.json has no existing file for ${d.key} (${d.type})`);
const stageDir = path.join(wo.buildDir, "staging", "v" + version); fs.mkdirSync(stageDir, { recursive: true });
const copies = [];
function put(src, name) { const dst = path.join(stageDir, name || path.basename(src)); fs.copyFileSync(src, dst); copies.push(dst); return dst; }
for (const d of wo.documents) { d.file = put(files[d.key]); d.title = path.basename(d.file, path.extname(d.file)).replace(/[_-]+/g, " "); }
const attach = {};
if (files.complianceReport) attach.complianceReport = put(files.complianceReport);
if (files.resourceReport) attach.resourceReport = put(files.resourceReport);
attach.verification = put(report, `${unit}-ai-verification-report.md`);
attach.workOrder = put(L.workOrderPath(cfg, unit, college), `${unit}-work-order.json`);
attach.runLog = put(path.join(wo.buildDir, "run-log.md"), `${unit}-run-log.md`);
for (const r of (wo.verificationRounds || [])) { const p = path.join(wo.buildDir, "verify", `round-${r.round}.md`); if (fs.existsSync(p)) put(p, `${unit}-ai-verification-round-${r.round}.md`); }
console.log(`Staging package: ${copies.length} files in ${stageDir}`);

(async () => {
  const links = { workOrder: "", verification: "", discrepanciesResolved: "Yes", aiRulesStated: L.arg("ai-rules-stated", "No"), docs: {} };
  const key = G.loadKey(cfg.serviceAccountKey);
  if (key) {
    const unitFolder = await G.ensureFolder(key, `${unit}-${college}`, cfg.drive.stagingFolderId);
    const vFolder = await G.ensureFolder(key, `v${version}`, unitFolder.id);
    const up = {};
    for (const f of copies) { const r = await G.uploadFile(key, f, vFolder.id); up[path.basename(f)] = r.webViewLink; console.log(`  uploaded ${path.basename(f)}`); }
    links.workOrder = up[path.basename(attach.workOrder)] + " ; " + up[path.basename(attach.runLog)];
    links.verification = up[path.basename(attach.verification)];
    for (const d of wo.documents) links.docs[d.key] = { title: d.title, url: up[path.basename(d.file)],
      report: (d.key === "learnerGuide" || d.key === "deck") ? (attach.resourceReport ? up[path.basename(attach.resourceReport)] : "") : (attach.complianceReport ? up[path.basename(attach.complianceReport)] : "") };
    links.folder = vFolder.webViewLink;
    console.log(`Uploaded to Drive: ${vFolder.webViewLink || vFolder.id}`);
  } else {
    console.log("NOTE: no service-account key - the package is on disk only. Drag the folder into Drive > Registers > Staging and paste the links into the rows.");
    for (const d of wo.documents) links.docs[d.key] = { title: d.title, url: `(local) ${d.file}`, report: (d.key === "learnerGuide" || d.key === "deck") ? attach.resourceReport || "" : attach.complianceReport || "" };
    links.workOrder = `(local) ${attach.workOrder}`; links.verification = `(local) ${attach.verification}`;
  }
  const linksPath = path.join(stageDir, "links.json"); L.writeJson(linksPath, links);
  L.saveWorkOrder(cfg, wo);
  const out = execFileSync(process.execPath, [path.join(__dirname, "registers.js"), "stage", "--unit", unit, "--college", college, "--version", version, "--links", linksPath], { encoding: "utf8" });
  process.stdout.write(out);
  console.log(`\nR5 done. Hand to ${wo.reviewingTrainer} for the review sitting (R6, R7).`);
})().catch(e => { console.error("ERROR: " + (e && e.message ? e.message : e)); process.exit(1); });

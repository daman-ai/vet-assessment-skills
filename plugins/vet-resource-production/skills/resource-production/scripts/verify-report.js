// R3/R4 - the AI verification report. The clean-room agent returns JSON; this validates it, writes the round's
// Markdown report, and at the end of the loop writes the final report with every item resolved or reasoned.
//
//   node verify-report.js brief    --unit U --college C                      writes verify/brief.md - the agent's instructions + the unit's requirements
//   node verify-report.js round    --unit U --college C --json verify/round-N.json     validates and writes verify/round-N.md
//   node verify-report.js resolve  --unit U --college C --json verify/resolutions.json  final report; exit 1 while anything is unresolved
//
// round-N.json: { "round": 1, "checkedOn": "YYYY-MM-DD", "release": "Release 1", "documents": [ { "file": "<name>", "covered": ["E1.1", "PE3", "KE7", "AC2"], "discrepancies": [ { "id": "D1", "ref": "KE7", "requirement": "...", "finding": "...", "severity": "must" | "should" } ] } ] }
// resolutions.json: { "round": 3, "items": [ { "id": "D1", "status": "fixed" | "reasoned", "note": "..." } ] }
"use strict";
const fs = require("fs");
const path = require("path");
const L = require("./lib");

const cfg = L.loadConfig();
const cmd = process.argv[2]; const unit = (L.arg("unit") || "").toUpperCase(); const college = (L.arg("college") || "").toUpperCase();
if (!cmd || !unit || !college) L.fail("usage: verify-report.js <brief|round|resolve> --unit CODE --college MVC|ACI [--json file]");
const wo = L.loadWorkOrder(cfg, unit, college);
const vdir = path.join(wo.buildDir, "verify"); fs.mkdirSync(vdir, { recursive: true });

function listify(x) { if (Array.isArray(x)) return x; if (!x) return []; return String(x).split(/\r?\n/).map(t => t.trim()).filter(Boolean); }
function itemText(x) { return typeof x === "string" ? x : (x.text || x.description || x.title || JSON.stringify(x)); }

if (cmd === "brief") {
  const u = L.readJson(path.join(cfg.skills.tas, "assets", "units", unit + ".json"));
  let md = `# Clean-room verification brief - ${unit} ${u.title}\n\n`;
  md += `You are a verifier with no part in the build. You have the documents' text and the unit's requirements below, and nothing else. `;
  md += `Do not assume anything about how the documents were made. Read training.gov.au for ${unit} (${u.sourceUrl || "https://training.gov.au"}) and confirm the release is still ${wo.unitRelease}; if it is not, say so first.\n\n`;
  md += `## What to check\n\n1. **The assessment tool(s)** against every requirement listed below: is each element and performance criterion assessed; is each performance-evidence item collected, over the number of occasions it states; is each knowledge-evidence item asked; are the assessment conditions met by the tool's instructions. Cite the requirement id for every finding.\n`;
  md += `2. **The assessor guide(s)** against the tool: a benchmark for every task, and no task whose benchmark could pass a wrong answer.\n`;
  md += `3. **The learner guide and the deck** against the pack: nothing taught that the pack contradicts, and every assessed requirement taught somewhere. Cite the task or question.\n`;
  md += `4. Anything stated as fact that you can show is wrong - a temperature, a clause, a standard.\n\n`;
  md += `Severity: **must** = a requirement not evidenced, or a wrong fact; **should** = weak, ambiguous, or thin.\n\n`;
  md += `## Return\n\nOne JSON object, nothing else, in this shape:\n\n\`\`\`json\n{ "round": N, "checkedOn": "YYYY-MM-DD", "release": "${wo.unitRelease}", "documents": [ { "file": "<file name>", "covered": ["E1.1", "PE1", "KE1"], "discrepancies": [ { "id": "D1", "ref": "KE7", "requirement": "<quoted>", "finding": "<what is missing or wrong, where>", "severity": "must" } ] } ] }\n\`\`\`\n\n`;
  md += `## The unit's requirements (${wo.unitRelease})\n\n### Elements and performance criteria\n`;
  listify(u.elements).forEach(line => { md += (/^\d+\.\d+\./.test(line) ? `  - ` : `- `) + line + `\n`; });
  md += `\n### Performance evidence\n`; listify(u.performanceEvidence).forEach((x, i) => { md += `- **PE${i + 1}** ${itemText(x)}\n`; });
  md += `\n### Knowledge evidence\n`; listify(u.knowledgeEvidence).forEach((x, i) => { md += `- **KE${i + 1}** ${itemText(x)}\n`; });
  md += `\n### Assessment conditions\n`; listify(u.assessmentConditions).forEach((x, i) => { md += `- **AC${i + 1}** ${itemText(x)}\n`; });
  md += `\n### Foundation skills\n`; listify(u.foundationSkills).forEach((x, i) => { md += `- **FS${i + 1}** ${itemText(x)}\n`; });
  md += `\n## The documents\n\nThe text of each document is in this folder as <file>.txt. Read every one in full before writing a finding.\n`;
  fs.writeFileSync(path.join(vdir, "brief.md"), md);
  console.log(`brief written: ${path.join(vdir, "brief.md")}`);
}

if (cmd === "round") {
  const j = L.readJson(L.arg("json") || L.fail("round needs --json verify/round-N.json"));
  if (!j.round || !j.checkedOn || !Array.isArray(j.documents)) L.fail("round JSON needs round, checkedOn, documents[]");
  if (j.release && j.release !== wo.unitRelease) L.fail(`the verifier read ${j.release}; the work order is for ${wo.unitRelease} - stop and resolve the release first`);
  let md = `# AI verification - round ${j.round} - ${unit} ${wo.unitTitle}\n\nChecked on ${j.checkedOn} against ${wo.unitRelease} on training.gov.au by a clean-room agent with no access to the build.\n\n`;
  let musts = 0, shoulds = 0; const seen = new Set();
  for (const d of j.documents) {
    md += `## ${d.file}\n\nCovered: ${(d.covered || []).length} requirement ids.\n\n`;
    if (!(d.discrepancies || []).length) md += `No discrepancies.\n\n`;
    else { md += `| Id | Ref | Requirement | Finding | Severity |\n|---|---|---|---|---|\n`;
      for (const x of d.discrepancies) { if (!x.id || seen.has(x.id)) L.fail("every discrepancy needs a unique id (D1, D2 ...): " + JSON.stringify(x)); seen.add(x.id); if (x.severity === "must") musts++; else shoulds++;
        md += `| ${x.id} | ${x.ref || ""} | ${String(x.requirement || "").replace(/\|/g, "/")} | ${String(x.finding || "").replace(/\|/g, "/")} | ${x.severity || "should"} |\n`; }
      md += `\n`; }
  }
  md += `**Totals:** ${musts} must, ${shoulds} should.\n`;
  fs.writeFileSync(path.join(vdir, `round-${j.round}.md`), md);
  wo.verificationRounds = (wo.verificationRounds || []).filter(r => r.round !== j.round).concat([{ round: j.round, checkedOn: j.checkedOn, musts, shoulds, ids: Array.from(seen) }]);
  L.saveWorkOrder(cfg, wo);
  L.logRun(cfg, wo, "R3", `verification round ${j.round}: ${musts} must, ${shoulds} should`);
  console.log(`round ${j.round}: ${musts} must, ${shoulds} should -> ${path.join(vdir, `round-${j.round}.md`)}`);
  if (j.round > cfg.verification.maxRounds) console.log(`Round ${j.round} exceeds the limit of ${cfg.verification.maxRounds} - stop and hand the report to the builder.`);
  process.exit(musts + shoulds ? 3 : 0);
}

if (cmd === "resolve") {
  const j = L.readJson(L.arg("json") || L.fail("resolve needs --json verify/resolutions.json"));
  const rounds = (wo.verificationRounds || []).sort((a, b) => a.round - b.round);
  if (!rounds.length) L.fail("no verification round recorded yet");
  const last = rounds[rounds.length - 1];
  const open = new Set(last.ids); const res = new Map((j.items || []).map(i => [i.id, i]));
  const unresolved = Array.from(open).filter(id => !res.has(id) || !["fixed", "reasoned"].includes(res.get(id).status) || (res.get(id).status === "reasoned" && !res.get(id).note));
  let md = `# AI verification report - ${unit} ${wo.unitTitle} - v${wo.version}\n\n${rounds.length} round(s) by a clean-room agent against ${wo.unitRelease}. `;
  md += `Final round ${last.round} on ${last.checkedOn}: ${last.musts} must, ${last.shoulds} should.\n\n## Rounds\n\n| Round | Checked on | Must | Should |\n|---|---|---|---|\n`;
  rounds.forEach(r => { md += `| ${r.round} | ${r.checkedOn} | ${r.musts} | ${r.shoulds} |\n`; });
  md += `\n## Resolution of the final round's items\n\n`;
  if (!open.size) md += `Nothing open. The final round found no discrepancies.\n`;
  else { md += `| Id | Status | Note |\n|---|---|---|\n`; for (const id of open) { const r = res.get(id); md += `| ${id} | ${r ? r.status : "OPEN"} | ${r ? String(r.note || "").replace(/\|/g, "/") : ""} |\n`; } }
  md += `\n**Discrepancies resolved: ${unresolved.length ? "NO - " + unresolved.join(", ") + " still open" : "YES"}.**\n`;
  fs.writeFileSync(path.join(vdir, "ai-verification-report.md"), md);
  L.logRun(cfg, wo, "R4", unresolved.length ? `resolution incomplete: ${unresolved.join(", ")} open` : `every item of round ${last.round} fixed or reasoned`);
  console.log(unresolved.length ? `UNRESOLVED: ${unresolved.join(", ")}` : "All items resolved. Discrepancies resolved: YES");
  process.exit(unresolved.length ? 1 : 0);
}

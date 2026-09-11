// The three registers of the resource production loop, kept in Google Sheets (with a local CSV mirror) or, without
// a service-account key, in the local mirror alone with the row printed for a person to paste.
//
//   node registers.js open     --unit SITHCCC035 --college MVC            R1  open the tool rows from the work order
//   node registers.js stage    --unit U --college C --version 0.3 --links links.json   R5  Staged, attachments, links
//   node registers.js version  --unit U --college C --version 0.4 --note "rebuilt after R7"   R8  new 0.x on the same rows
//   node registers.js consult  --unit U --college C --json consult.json   R6  the reviewing trainer's consultation row(s)
//   node registers.js preuse   --unit U --college C --json preuse.json    R7  the pre-use review row for one tool
//   node registers.js approve  --unit U --college C --approver "K. Singh" [--version 1.0]   R9  gate one
//   node registers.js publish  --unit U --college C --publisher "Head of training" [--date YYYY-MM-DD]   R10
//   node registers.js show     --unit U --college C
//
// Nothing here decides anything. Every judgement value it writes was typed by a named person; the script checks the
// separation of duties and the order of dates, and refuses when they fail.
"use strict";
const fs = require("fs");
const path = require("path");
const L = require("./lib");
const G = require("./gapi");

const NEEDS_PREUSE = ["Knowledge", "Practical", "Observation", "Workbook", "Portfolio"];
const cfg = L.loadConfig();
const key = G.loadKey(cfg.serviceAccountKey);

// ---------------- store: Sheets with a mirror, or the mirror alone ----------------
class Store {
  constructor(reg) { this.reg = reg; this.def = L.REGISTERS[reg]; this.sheetId = cfg.drive.sheets[this.def.sheetKey]; this.sheetName = null; this.rows = null; }
  mirrorPath() { return path.join(cfg.registerMirror, this.reg + ".csv"); }
  async load() {
    if (key) {
      this.sheetName = await G.firstSheetName(key, this.sheetId);
      this.rows = await G.getValues(key, this.sheetId, this.sheetName);
      if (!this.rows.length) this.rows = [this.def.headers.slice()];
      this.writeMirror();
    } else {
      const p = this.mirrorPath();
      this.rows = fs.existsSync(p) ? L.parseCsv(fs.readFileSync(p, "utf8").replace(/^﻿/, "")) : [this.def.headers.slice()];
    }
    this.header = this.rows[0];
    const missing = this.def.headers.filter(h => !this.header.includes(h));
    if (missing.length) L.fail(`${this.reg} register is missing columns: ${missing.join(", ")} - the sheet's header row must match the register design`);
    return this;
  }
  writeMirror() { fs.mkdirSync(cfg.registerMirror, { recursive: true }); fs.writeFileSync(this.mirrorPath(), L.toCsv(this.rows)); }
  col(name) { return this.header.indexOf(name); }
  toObj(row) { const o = {}; this.header.forEach((h, i) => { o[h] = row[i] == null ? "" : row[i]; }); return o; }
  fromObj(o) { return this.header.map(h => o[h] == null ? "" : String(o[h])); }
  all() { return this.rows.slice(1).filter(r => r.some(v => v !== "")).map(r => this.toObj(r)); }
  find(rowId) { return this.all().find(o => o["Row ID"] === rowId) || null; }
  nextId() {
    let max = 0;
    for (const o of this.all()) { const m = /^[A-Z]+-(\d+)$/.exec(o["Row ID"] || ""); if (m) max = Math.max(max, parseInt(m[1], 10)); }
    return `${this.def.prefix}-${String(max + 1).padStart(4, "0")}`;
  }
  async append(obj) {
    obj["Row ID"] = obj["Row ID"] || this.nextId();
    const row = this.fromObj(obj);
    this.rows.push(row);
    if (key) await G.appendRows(key, this.sheetId, this.sheetName, [row]);
    this.writeMirror();
    if (!key) manual(this.reg, obj);
    return obj["Row ID"];
  }
  async update(rowId, patch) {
    const idx = this.rows.findIndex((r, i) => i > 0 && r[0] === rowId);
    if (idx < 0) L.fail(`${this.reg}: row ${rowId} not found`);
    const obj = Object.assign(this.toObj(this.rows[idx]), patch);
    const row = this.fromObj(obj);
    this.rows[idx] = row;
    if (key) {
      const last = colLetter(this.header.length);
      await G.updateRange(key, this.sheetId, `${this.sheetName}!A${idx + 1}:${last}${idx + 1}`, [row]);
    }
    this.writeMirror();
    if (!key) manual(this.reg, obj, "UPDATE");
    return obj;
  }
}
function colLetter(n) { let s = ""; while (n > 0) { const m = (n - 1) % 26; s = String.fromCharCode(65 + m) + s; n = Math.floor((n - 1) / 26); } return s; }
function manual(reg, obj, kind) {
  const url = `https://docs.google.com/spreadsheets/d/${cfg.drive.sheets[L.REGISTERS[reg].sheetKey]}/edit`;
  console.log(`\nMANUAL ${kind || "ROW"} - no service-account key, so this ${reg} row is in the local mirror only. Paste it into ${url}:`);
  for (const [k, v] of Object.entries(obj)) if (v !== "") console.log(`  ${k}: ${v}`);
}
function appendList(existing, id) { const set = new Set((existing || "").split(",").map(s => s.trim()).filter(Boolean)); set.add(id); return Array.from(set).join(", "); }
function same(a, b) { return (a || "").trim().toLowerCase() === (b || "").trim().toLowerCase(); }

// ---------------- commands ----------------
async function cmdOpen(wo) {
  const tools = await new Store("tools").load();
  for (const d of wo.documents) {
    if (d.rowId) continue;
    d.rowId = await tools.append({
      "Unit code": wo.unit, "Unit release": wo.unitRelease, "Course": wo.courseId, "College": wo.collegeLabel,
      "Document title": d.plannedTitle, "Type": d.type, "Version": wo.version, "Status": "Draft",
      "Builder": wo.builder, "Skills and versions": wo.skills, "AI-drafted": "Yes", "Unit release read on": wo.unitReleaseReadOn,
      "Reviewing trainer": wo.reviewingTrainer, "Approver": wo.approver,
      "Pack version derived from": (d.key === "learnerGuide" || d.key === "deck") ? wo.version : "",
      "Notes": `Opened from the work order on ${L.today()}${wo.aiUsesUnregistered ? " - R0 NOT SATISFIED: " + wo.aiUsesUnregistered : ""}`
    });
    L.logRun(cfg, wo, "R1", `tool row ${d.rowId} opened for ${d.type} (${d.plannedTitle})`);
  }
  L.saveWorkOrder(cfg, wo);
  console.log("Tool rows: " + wo.documents.map(d => `${d.rowId} ${d.type}`).join("; "));
}

async function cmdStage(wo) {
  const version = L.arg("version"); const linksPath = L.arg("links");
  if (!version || !linksPath) L.fail("stage needs --version 0.x and --links links.json");
  const links = L.readJson(linksPath);
  const tools = await new Store("tools").load();
  for (const d of wo.documents) {
    const l = (links.docs || {})[d.key] || {};
    await tools.update(d.rowId, {
      "Document title": l.title || d.title || d.plannedTitle, "Version": version, "Status": "Staged",
      "Work order and run log": links.workOrder || "", "Compliance / resource report": l.report || "",
      "AI verification report": links.verification || "", "Discrepancies resolved": links.discrepanciesResolved || "No",
      "Pack version derived from": (d.key === "learnerGuide" || d.key === "deck") ? version : "",
      "Student AI-use rules stated": NEEDS_PREUSE.includes(d.type) ? (links.aiRulesStated || "No") : "N/A",
      "Notes": `Staged ${L.today()} v${version}${l.url ? " · " + l.url : ""}`
    });
    if (l.title) d.title = l.title; if (l.url) d.url = l.url;
  }
  wo.version = version; wo.status = "Staged"; wo.stagedOn = L.today();
  L.saveWorkOrder(cfg, wo);
  L.logRun(cfg, wo, "R5", `staged v${version}; discrepancies resolved: ${links.discrepanciesResolved || "No"}`);
  console.log(`Staged v${version} on ${wo.documents.length} rows.`);
}

async function cmdVersion(wo) {
  const version = L.arg("version"); if (!version) L.fail("version needs --version 0.x");
  if (!/^0\.\d+$/.test(version)) L.fail("the command only ever produces 0.x versions; 1.0 and above are set at approve");
  const tools = await new Store("tools").load();
  for (const d of wo.documents) { const r = tools.find(d.rowId); if (r && ["Approved", "Published", "Superseded"].includes(r["Status"])) L.fail(`${d.rowId} is ${r["Status"]} - an approved version is never re-versioned in place. Start a new row set with work-order.js --force and approve it as the next 1.x`); }
  for (const d of wo.documents) await tools.update(d.rowId, { "Version": version, "Status": "Draft", "Discrepancies resolved": "No", "Notes": `Rebuilt as v${version} on ${L.today()}: ${L.arg("note", "rebuild")}` });
  wo.version = version; wo.status = "Draft"; L.saveWorkOrder(cfg, wo);
  L.logRun(cfg, wo, "R8", `rebuilt as v${version}: ${L.arg("note", "rebuild")}`);
  console.log(`All rows now v${version} Draft.`);
}

async function cmdConsult(wo) {
  const j = L.readJson(L.arg("json") || L.fail("consult needs --json consult.json"));
  for (const k of ["date", "who", "advice", "decision", "change", "recordedBy"]) if (!j[k]) L.fail(`consult.json is missing ${k}`);
  if (same(j.who, wo.builder)) L.fail(`${j.who} built this unit and cannot be its reviewer`);
  if (!j.currencyEvidence) L.fail("consult.json needs currencyEvidence - a trainer's review without currency on file is an opinion, not consultation");
  if (!["Changed", "No change, reasoned", "Pending"].includes(j.decision)) L.fail("decision must be Changed | No change, reasoned | Pending");
  const docRows = (j.documents && j.documents.length) ? j.documents : wo.documents.map(d => d.rowId);
  const consult = await new Store("consult").load();
  const id = await consult.append({
    "Date": j.date, "Method": j.method || "Review of a draft tool", "Who": j.who, "Organisation and role": j.organisation || "",
    "Why relevant": j.whyRelevant || "", "Currency evidence": j.currencyEvidence, "Course": wo.courseId, "Unit code": wo.unit,
    "Documents and versions reviewed": docRows.map(r => `${r} v${wo.version}`).join("; "), "Advice received": j.advice, "Decision": j.decision,
    "Change made, or reason for no change": j.change, "New version produced": j.newVersion || "", "Recorded by": j.recordedBy,
    "Next review trigger": j.nextTrigger || `Next release of ${wo.unit}, or the annual consultation`, "Notes": j.notes || ""
  });
  const tools = await new Store("tools").load();
  for (const r of docRows) { const cur = tools.find(r); if (cur) await tools.update(r, { "Consultation rows": appendList(cur["Consultation rows"], id) }); }
  L.logRun(cfg, wo, "R6", `consultation row ${id} by ${j.who}: ${j.decision}`);
  console.log(`Consultation row ${id} written and linked to ${docRows.join(", ")}.`);
}

async function cmdPreuse(wo) {
  const j = L.readJson(L.arg("json") || L.fail("preuse needs --json preuse.json"));
  const P = ["validity", "reliability", "flexibility", "fairness", "sufficiency", "authenticity", "currency", "validityOfEvidence"];
  for (const k of ["toolRow", "reviewer", "reviewDate", "outcome", "practical"]) if (j[k] == null) L.fail(`preuse.json is missing ${k}`);
  for (const k of P) if (!["Met", "Amend"].includes(j[k])) L.fail(`preuse.json: ${k} must be Met or Amend`);
  if (same(j.reviewer, wo.builder)) L.fail(`${j.reviewer} built this unit and cannot pre-use review it`);
  if (j.holdsUnit !== "Yes") L.fail("the reviewer must hold the unit on the credential matrix (holdsUnit: Yes)");
  const anyAmend = P.some(k => j[k] === "Amend");
  const outcome = anyAmend ? "Return to builder" : (j.outcome === "Return to builder" ? "Return to builder" : "Ready for approval");
  if (outcome === "Return to builder" && !j.findings) L.fail("an Amend needs findings and amendments required");
  const d = wo.documents.find(x => x.rowId === j.toolRow); if (!d) L.fail(`tool row ${j.toolRow} is not in this work order`);
  if (!NEEDS_PREUSE.includes(d.type)) L.fail(`${j.toolRow} is a ${d.type}; pre-use review is for assessment tools only`);
  const preuse = await new Store("preuse").load();
  const id = await preuse.append({
    "Tool row": j.toolRow, "Unit code": wo.unit, "Unit release checked": j.releaseChecked || wo.unitRelease, "Date release read": j.dateReleaseRead || j.reviewDate,
    "Document and version": `${d.title || d.plannedTitle} v${wo.version}`, "Reviewer": j.reviewer, "Reviewer holds the unit on the matrix": j.holdsUnit,
    "Reviewer is not the builder": "Yes", "AI verification report worked through": j.aiReportWorked || "No",
    "Validity": j.validity, "Reliability": j.reliability, "Flexibility": j.flexibility, "Fairness": j.fairness, "Sufficiency": j.sufficiency,
    "Authenticity": j.authenticity, "Currency": j.currency, "Validity of evidence": j.validityOfEvidence,
    "Practical application components present": j.practical, "Findings and amendments required": j.findings || "", "Outcome": outcome,
    "Review date": j.reviewDate, "First-use date": "", "Notes": j.notes || ""
  });
  const tools = await new Store("tools").load();
  const cur = tools.find(j.toolRow);
  await tools.update(j.toolRow, { "Pre-use review row": appendList(cur["Pre-use review row"], id) });
  L.logRun(cfg, wo, "R7", `pre-use row ${id} for ${j.toolRow} by ${j.reviewer}: ${outcome}`);
  console.log(`Pre-use review ${id}: ${outcome}.`);
}

async function cmdApprove(wo) {
  const approver = L.arg("approver"); if (!approver || approver === true) L.fail("approve needs --approver \"Name\"");
  const date = L.arg("date", L.today());
  const version = L.arg("version", cfg.versions.firstApproval);
  if (!/^[1-9]\d*\.\d+$/.test(version)) L.fail("an approved version is 1.0 or above");
  if (same(approver, wo.builder)) L.fail(`${approver} built this unit and cannot approve it`);
  if (same(approver, wo.reviewingTrainer)) L.fail(`${approver} will deliver this unit and cannot approve it`);
  const tools = await new Store("tools").load(), preuse = await new Store("preuse").load(), consult = await new Store("consult").load();
  const problems = [];
  for (const d of wo.documents) {
    const row = tools.find(d.rowId); if (!row) { problems.push(`${d.rowId} not found`); continue; }
    if (row["Status"] !== "Staged") problems.push(`${d.rowId} is ${row["Status"]}, not Staged`);
    if (row["Discrepancies resolved"] !== "Yes") problems.push(`${d.rowId}: AI verification discrepancies not resolved`);
    if (!(row["Consultation rows"] || "").trim()) problems.push(`${d.rowId}: no consultation row`);
    if (NEEDS_PREUSE.includes(row["Type"])) {
      const ids = (row["Pre-use review row"] || "").split(",").map(s => s.trim()).filter(Boolean);
      const pu = ids.map(i => preuse.find(i)).filter(Boolean).filter(p => p["Document and version"].endsWith(`v${wo.version}`));
      const ready = pu.find(p => p["Outcome"] === "Ready for approval");
      if (!ready) problems.push(`${d.rowId}: no pre-use review at v${wo.version} with outcome Ready for approval`);
      else if (ready["Review date"] > date) problems.push(`${d.rowId}: pre-use review is dated after the approval date`);
      else if (same(ready["Reviewer"], approver)) problems.push(`${d.rowId}: the pre-use reviewer cannot also approve`);
    }
    for (const i of (row["Consultation rows"] || "").split(",").map(s => s.trim()).filter(Boolean)) {
      const c = consult.find(i); if (c && c["Decision"] === "Pending") problems.push(`${i} is still Pending`);
    }
  }
  if (problems.length) L.fail("cannot approve:\n  - " + problems.join("\n  - "));
  // supersede: any other Approved/Published row for the same unit, college and type
  const packRows = wo.documents.filter(d => d.key !== "learnerGuide" && d.key !== "deck"), resRows = wo.documents.filter(d => d.key === "learnerGuide" || d.key === "deck");
  const mine = new Set(wo.documents.map(d => d.rowId));
  for (const d of packRows.concat(resRows)) {
    const title = (d.title || d.plannedTitle || "").trim().toLowerCase();
    const olds = tools.all().filter(o => o["Unit code"] === wo.unit && o["College"] === wo.collegeLabel && o["Type"] === d.type && ["Approved", "Published"].includes(o["Status"])
      && !mine.has(o["Row ID"]) && (o["Document title"] || "").trim().toLowerCase() === title);
    for (const o of olds) await tools.update(o["Row ID"], { "Status": "Superseded", "Superseded by": d.rowId });
    await tools.update(d.rowId, { "Status": "Approved", "Version": version, "Approved by": approver, "Approval date": date,
      "Pack version derived from": (d.key === "learnerGuide" || d.key === "deck") ? version : "", "Supersedes": olds.map(o => o["Row ID"]).join(", ") });
  }
  wo.version = version; wo.status = "Approved"; wo.approvedBy = approver; wo.approvedOn = date; L.saveWorkOrder(cfg, wo);
  L.logRun(cfg, wo, "R9", `approved v${version} by ${approver}`);
  console.log(`Approved v${version} by ${approver} on ${date}. ${wo.documents.length} rows; previous versions superseded where they existed.`);
}

async function cmdPublish(wo) {
  const date = L.arg("date", L.today()); const publisher = L.arg("publisher", cfg.people.publisher || "Head of training");
  const tools = await new Store("tools").load();
  for (const d of wo.documents) { const r = tools.find(d.rowId); if (!r || r["Status"] !== "Approved") L.fail(`${d.rowId} is not Approved`); }
  for (const d of wo.documents) await tools.update(d.rowId, { "Status": "Published", "Published to eSkilled on": date, "Notes": `Published by ${publisher} ${date}; eSkilled version must equal v${wo.version}` });
  wo.status = "Published"; wo.publishedOn = date; L.saveWorkOrder(cfg, wo);
  L.logRun(cfg, wo, "R10", `published v${wo.version} to eSkilled by ${publisher}; TAS tools-in-use to be updated`);
  console.log(`Published v${wo.version}. Update the TAS's tools-in-use list to v${wo.version} for ${wo.unit} in ${wo.courseId}.`);
}

async function cmdShow(wo) {
  const tools = await new Store("tools").load();
  for (const d of wo.documents) { const r = tools.find(d.rowId); console.log(r ? `${r["Row ID"]}  ${r["Type"].padEnd(14)} v${r["Version"].padEnd(5)} ${r["Status"].padEnd(10)} PU:${r["Pre-use review row"] || "-"}  IC:${r["Consultation rows"] || "-"}  AI:${r["Discrepancies resolved"] || "-"}` : `${d.rowId} missing`); }
}

(async () => {
  const cmd = process.argv[2]; const unit = L.arg("unit"); const college = L.arg("college");
  if (!cmd || !unit || !college) L.fail("usage: registers.js <open|stage|version|consult|preuse|approve|publish|show> --unit CODE --college MVC|ACI ...");
  if (!key) console.log("NOTE: no service-account key at " + cfg.serviceAccountKey + " - writing to the local mirror only; rows are printed for manual entry.");
  const wo = L.loadWorkOrder(cfg, unit, college);
  const fns = { open: cmdOpen, stage: cmdStage, version: cmdVersion, consult: cmdConsult, preuse: cmdPreuse, approve: cmdApprove, publish: cmdPublish, show: cmdShow };
  if (!fns[cmd]) L.fail("unknown command " + cmd);
  await fns[cmd](wo);
})().catch(e => { console.error("ERROR: " + (e && e.message ? e.message : e)); process.exit(1); });

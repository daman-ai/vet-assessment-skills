// R1 - the work order. The command's first output, before any skill runs.
//   node work-order.js --unit SITHCCC035 --college MVC --builder "D. Rana" --trainer "R. Sharma" --approver "K. Singh" [--course MVC-SIT30821] [--publisher "K. Singh"] [--allow-unregistered-ai]
// Resolves the course from the tas registry, reads the unit record, checks the three names against each other,
// checks the five AI uses, decides the expected document set, and writes <buildRoot>/<UNIT>-<COLLEGE>/work-order.json.
"use strict";
const fs = require("fs");
const path = require("path");
const L = require("./lib");

const cfg = L.loadConfig();
const unit = (L.arg("unit") || "").toUpperCase(); const college = (L.arg("college") || "").toUpperCase();
const builder = L.arg("builder"), trainer = L.arg("trainer"), approver = L.arg("approver");
if (!unit || !college || !builder || !trainer || !approver || [builder, trainer, approver].some(v => v === true))
  L.fail('usage: work-order.js --unit CODE --college MVC|ACI --builder "Name" --trainer "Name" --approver "Name" [--course ID]');
if (!["MVC", "ACI"].includes(college)) L.fail("college must be MVC or ACI");

// ---- separation of duties: three people, never fewer ----
const same = (a, b) => a.trim().toLowerCase() === b.trim().toLowerCase();
if (same(builder, trainer)) L.fail(`${builder} cannot both build the unit and review it`);
if (same(builder, approver)) L.fail(`${builder} cannot both build the unit and approve it`);
if (same(trainer, approver)) L.fail(`${trainer} will deliver the unit and cannot approve it - a third person approves`);

// ---- the registry: which course, which unit record ----
const tasDir = cfg.skills.tas;
const coursesDir = path.join(tasDir, "assets", "courses");
const unitFile = path.join(tasDir, "assets", "units", unit + ".json");
if (!fs.existsSync(unitFile)) L.fail(`no unit record for ${unit} in the registry - harvest it first: ${tasDir}\\scripts\\Get-UnitRecord.ps1`);
const u = L.readJson(unitFile);
if (u.status !== "current" && u.currency !== "current") L.fail(`${unit} is ${u.statusLabel || u.status} on training.gov.au - a superseded unit is a blocker, not advice`);
const candidates = fs.readdirSync(coursesDir).filter(f => f.startsWith(college + "-") && f.endsWith(".json"))
  .map(f => L.readJson(path.join(coursesDir, f)))
  .filter(c => (c.units || []).some(x => x.code === unit && x.deliveryStatus === "delivered"));
let course = null; const want = L.arg("course");
if (want && want !== true) { course = candidates.find(c => c.courseId.toUpperCase() === want.toUpperCase()); if (!course) L.fail(`${unit} is not a delivered unit of ${want} at ${college}`); }
else if (candidates.length === 1) course = candidates[0];
else if (!candidates.length) L.fail(`${unit} is not a delivered unit in any ${college} course on the registry`);
else L.fail(`${unit} is delivered in ${candidates.length} ${college} courses - name one with --course: ${candidates.map(c => c.courseId).join(", ")}`);
const cu = course.units.find(x => x.code === unit);
const blockers = [];
if (cu.status && cu.status !== "current") blockers.push(`unit is ${cu.statusLabel || cu.status} in the course record`);
if ((course.supersededUnits || []).some(s => (s.code || s) === unit)) blockers.push("listed under supersededUnits in the course record");
if (blockers.length) L.fail("blockers from the registry: " + blockers.join("; "));

// ---- brand and college label ----
let variant = null, collegeLabel = "MVC";
if (college === "ACI") {
  variant = course.brandVariant || (u.trainingPackage === "SIT" ? "culinary" : u.trainingPackage === "CPC" ? "construction" : null);
  if (!variant) L.fail(`cannot resolve the ACI trading name for a ${u.trainingPackage} unit - set brandVariant on ${course.courseId} in the registry`);
  collegeLabel = variant === "culinary" ? "ACI Culinary" : "ACI Construction";
}

// ---- AI uses (R0) ----
const todayS = L.today();
const bad = cfg.aiUses.filter(a => !a.registeredOn || (a.reviewDue && a.reviewDue < todayS)).map(a => `${a.id} ${a.use}${a.registeredOn ? " (review overdue " + a.reviewDue + ")" : " (not registered)"}`);
let aiUsesUnregistered = "";
if (bad.length) {
  if (!L.has("allow-unregistered-ai")) L.fail("R0 not satisfied - these AI uses are unregistered or past review, and ICT & AI must register them before the first build:\n  - " + bad.join("\n  - ") + "\nRe-run with --allow-unregistered-ai to proceed with the finding recorded on every row.");
  aiUsesUnregistered = bad.join("; ");
}

// ---- expected documents ----
const pe = Array.isArray(u.performanceEvidence) ? u.performanceEvidence.map(x => typeof x === "string" ? x : JSON.stringify(x)).join(" ") : String(u.performanceEvidence || "");
const food = u.trainingPackage === "SIT" && /recipe|dish|produce|prepare and (cook|present)/i.test(pe) && !/^SITX/.test(unit);
const docs = food
  ? [{ key: "tool", type: "Knowledge", plannedTitle: `${unit} ${u.title} - Unit Assessment Tool` }, { key: "toolGuide", type: "Assessor guide", plannedTitle: `${unit} ${u.title} - Assessor Guide` },
     { key: "workbook", type: "Workbook", plannedTitle: `${unit} ${u.title} - Recipe Workbook` }, { key: "workbookGuide", type: "Assessor guide", plannedTitle: `${unit} ${u.title} - Recipe Workbook Assessor Guide` }]
  : [{ key: "tool", type: "Knowledge", plannedTitle: `${unit} ${u.title} - Unit Assessment Tool` }, { key: "toolGuide", type: "Assessor guide", plannedTitle: `${unit} ${u.title} - Assessor Guide` }];
docs.push({ key: "learnerGuide", type: "Learner guide", plannedTitle: `${unit} ${u.title} - Learner Guide` }, { key: "deck", type: "Delivery deck", plannedTitle: `${unit} ${u.title} - Delivery PowerPoint` });

const wo = {
  unit, unitTitle: u.title, unitRelease: `Release ${u.releaseNumber || "?"}`, unitReleaseReadOn: (u.fetchedUtc || "").slice(0, 10) || todayS,
  unitSourceUrl: u.sourceUrl || "", college, collegeLabel, brand: college, brandVariant: variant, courseId: course.courseId, qualification: course.qualificationCode,
  foodUnit: food, builder, reviewingTrainer: trainer, approver, publisher: L.arg("publisher", cfg.people.publisher || "Head of training"),
  skills: "tas; assessment; docx-images; learner-guide; resource-production", version: "0.1", status: "Draft", openedOn: todayS,
  aiUsesUnregistered, aiUseIds: cfg.aiUses.map(a => a.id), documents: docs, buildDir: L.buildDir(cfg, unit, college), verificationRounds: []
};
const existing = L.workOrderPath(cfg, unit, college);
if (fs.existsSync(existing)) {
  const old = L.readJson(existing);
  if (!L.has("force")) L.fail(`a work order already exists at ${existing} (v${old.version}, ${old.status}). A draft continues on it; a new version after approval needs --force, which archives this one and opens a new row set`);
  const archived = existing.replace(/work-order\.json$/, `work-order.v${old.version}.${old.status.toLowerCase()}.json`);
  fs.renameSync(existing, archived);
  wo.previousWorkOrder = path.basename(archived);
  wo.previousRows = (old.documents || []).map(d => ({ key: d.key, rowId: d.rowId, version: old.version }));
}
L.saveWorkOrder(cfg, wo);
L.logRun(cfg, wo, "R1", `work order opened by ${builder}: ${unit} ${u.title} in ${course.courseId} (${collegeLabel}); trainer ${trainer}; approver ${approver}; ${docs.length} documents expected${aiUsesUnregistered ? "; R0 NOT SATISFIED: " + aiUsesUnregistered : ""}`);

console.log(`WORK ORDER  ${unit} ${u.title}  ·  ${course.courseId}  ·  ${collegeLabel}  ·  ${wo.unitRelease} read ${wo.unitReleaseReadOn}`);
console.log(`  builder ${builder} · reviewing trainer ${trainer} · approver ${approver} · publisher ${wo.publisher}`);
console.log(`  documents (${docs.length}): ` + docs.map(d => d.type).join(", "));
if (aiUsesUnregistered) console.log(`  R0 NOT SATISFIED: ${aiUsesUnregistered}`);
console.log(`  written to ${existing}`);
console.log(`Next: node registers.js open --unit ${unit} --college ${college}`);

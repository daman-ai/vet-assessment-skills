// R3 - plain text out of .docx and .pptx for the clean-room verifier, with nothing else from the build.
//   node extract-text.js --out <dir> <file.docx> [<file.pptx> ...]
// Writes <dir>/<basename>.txt per file. Paragraphs become lines; tables become tab-separated rows; slides are numbered.
// A minimal zip reader (central directory + deflate) so no dependency is needed.
"use strict";
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

function readZip(buf) {
  const eocd = buf.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
  if (eocd < 0) throw new Error("not a zip");
  const count = buf.readUInt16LE(eocd + 10), cdOff = buf.readUInt32LE(eocd + 16);
  const entries = {}; let p = cdOff;
  for (let i = 0; i < count; i++) {
    if (buf.readUInt32LE(p) !== 0x02014b50) throw new Error("bad central directory");
    const method = buf.readUInt16LE(p + 10), csize = buf.readUInt32LE(p + 20), usize = buf.readUInt32LE(p + 24);
    const nlen = buf.readUInt16LE(p + 28), elen = buf.readUInt16LE(p + 30), clen = buf.readUInt16LE(p + 32), lho = buf.readUInt32LE(p + 42);
    const name = buf.toString("utf8", p + 46, p + 46 + nlen);
    entries[name] = { method, csize, usize, lho };
    p += 46 + nlen + elen + clen;
  }
  return {
    names: Object.keys(entries),
    read(name) {
      const e = entries[name]; if (!e) return null;
      const nlen = buf.readUInt16LE(e.lho + 26), elen = buf.readUInt16LE(e.lho + 28);
      const start = e.lho + 30 + nlen + elen; const data = buf.subarray(start, start + e.csize);
      return e.method === 8 ? zlib.inflateRawSync(data) : Buffer.from(data);
    }
  };
}
function decode(s) { return s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&#(\d+);/g, (m, n) => String.fromCharCode(+n)).replace(/&amp;/g, "&"); }
function wordText(xml) {
  return decode(xml
    .replace(/<w:tab\/>/g, "\t").replace(/<w:br[^>]*\/>/g, "\n")
    .replace(/<\/w:tc>/g, "\t").replace(/<\/w:tr>/g, "\n").replace(/<\/w:p>/g, "\n")
    .replace(/<w:instrText[^>]*>[\s\S]*?<\/w:instrText>/g, "").replace(/<[^>]+>/g, ""))
    .replace(/[ \t]+\n/g, "\n").replace(/\n{3,}/g, "\n\n");
}
function slideText(xml) { return decode(xml.replace(/<\/a:p>/g, "\n").replace(/<a:tab\/>/g, "\t").replace(/<[^>]+>/g, "")).replace(/\n{3,}/g, "\n\n"); }

function extract(file) {
  const zip = readZip(fs.readFileSync(file)); const ext = path.extname(file).toLowerCase(); let out = "";
  if (ext === ".docx") {
    for (const part of ["word/document.xml", "word/footnotes.xml", "word/endnotes.xml"]) { const x = zip.read(part); if (x) out += wordText(x.toString("utf8")) + "\n"; }
    for (const n of zip.names.filter(n => /^word\/(header|footer)\d*\.xml$/.test(n)).sort()) out += `\n[${n}]\n` + wordText(zip.read(n).toString("utf8"));
  } else if (ext === ".pptx") {
    const slides = zip.names.filter(n => /^ppt\/slides\/slide\d+\.xml$/.test(n)).sort((a, b) => +a.match(/\d+/)[0] - +b.match(/\d+/)[0]);
    for (const s of slides) {
      const n = +s.match(/slide(\d+)/)[1]; out += `\n=== Slide ${n} ===\n` + slideText(zip.read(s).toString("utf8"));
      const notes = zip.read(`ppt/notesSlides/notesSlide${n}.xml`); if (notes) out += `--- notes ---\n` + slideText(notes.toString("utf8"));
    }
  } else throw new Error("unsupported: " + file);
  return out.trim() + "\n";
}

const outDir = (() => { const i = process.argv.indexOf("--out"); return i > 0 ? process.argv[i + 1] : null; })();
const files = process.argv.slice(2).filter((a, i, arr) => a !== "--out" && arr[i - 1] !== "--out");
if (!outDir || !files.length) { console.error("usage: extract-text.js --out <dir> <file.docx|pptx> ..."); process.exit(2); }
fs.mkdirSync(outDir, { recursive: true });
for (const f of files) {
  const txt = extract(f); const target = path.join(outDir, path.basename(f) + ".txt");
  fs.writeFileSync(target, txt); console.log(`${path.basename(f)} -> ${target} (${txt.length} chars)`);
}

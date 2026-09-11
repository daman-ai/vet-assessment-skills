// Minimal Google Sheets + Drive client on a service account. No npm dependencies: node >= 20 (fetch, crypto).
// Auth: the JSON key at config.serviceAccountKey. The Registers folder and the three sheets must be shared
// with the service account's client_email as Editor, or every call below returns 403/404.
"use strict";
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const SCOPES = ["https://www.googleapis.com/auth/spreadsheets", "https://www.googleapis.com/auth/drive"];
let tokenCache = null;

function b64url(buf) { return Buffer.from(buf).toString("base64").replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_"); }

function loadKey(keyPath) {
  if (!keyPath || !fs.existsSync(keyPath)) return null;
  const k = JSON.parse(fs.readFileSync(keyPath, "utf8").replace(/^﻿/, ""));
  if (!k.client_email || !k.private_key) throw new Error("service account key is missing client_email or private_key");
  return k;
}

async function getToken(key) {
  if (tokenCache && tokenCache.exp > Date.now() / 1000 + 60) return tokenCache.token;
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64url(JSON.stringify({ iss: key.client_email, scope: SCOPES.join(" "), aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600 }));
  const sig = crypto.sign("RSA-SHA256", Buffer.from(header + "." + claim), key.private_key);
  const jwt = header + "." + claim + "." + b64url(sig);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: "grant_type=" + encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer") + "&assertion=" + jwt
  });
  if (!res.ok) throw new Error("token request failed: " + res.status + " " + await res.text());
  const j = await res.json();
  tokenCache = { token: j.access_token, exp: now + (j.expires_in || 3600) };
  return tokenCache.token;
}

async function call(key, method, url, body, contentType) {
  const token = await getToken(key);
  const headers = { Authorization: "Bearer " + token };
  if (contentType) headers["Content-Type"] = contentType;
  const res = await fetch(url, { method, headers, body });
  const text = await res.text();
  if (!res.ok) throw new Error(method + " " + url.split("?")[0] + " -> " + res.status + ": " + text.slice(0, 400));
  return text ? JSON.parse(text) : {};
}

// ---- Sheets ----
async function getValues(key, spreadsheetId, range) {
  const r = await call(key, "GET", `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${encodeURIComponent(range)}?majorDimension=ROWS`);
  return r.values || [];
}
async function appendRows(key, spreadsheetId, sheetName, rows) {
  const url = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${encodeURIComponent(sheetName + "!A1")}:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS`;
  return call(key, "POST", url, JSON.stringify({ values: rows }), "application/json");
}
async function updateRange(key, spreadsheetId, range, rows) {
  const url = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${encodeURIComponent(range)}?valueInputOption=USER_ENTERED`;
  return call(key, "PUT", url, JSON.stringify({ values: rows }), "application/json");
}
async function firstSheetName(key, spreadsheetId) {
  const r = await call(key, "GET", `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}?fields=sheets.properties.title`);
  return r.sheets[0].properties.title;
}

// ---- Drive ----
async function driveList(key, q, fields) {
  const r = await call(key, "GET", `https://www.googleapis.com/drive/v3/files?q=${encodeURIComponent(q)}&fields=${encodeURIComponent(fields || "files(id,name,mimeType,webViewLink)")}&supportsAllDrives=true&includeItemsFromAllDrives=true`);
  return r.files || [];
}
async function ensureFolder(key, name, parentId) {
  const found = await driveList(key, `name = '${name.replace(/'/g, "\\'")}' and '${parentId}' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false`);
  if (found.length) return found[0];
  return call(key, "POST", "https://www.googleapis.com/drive/v3/files?supportsAllDrives=true&fields=id,name,webViewLink",
    JSON.stringify({ name, mimeType: "application/vnd.google-apps.folder", parents: [parentId] }), "application/json");
}
const MIME = { ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document", ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", ".pdf": "application/pdf", ".md": "text/markdown", ".txt": "text/plain", ".json": "application/json", ".csv": "text/csv", ".png": "image/png" };
async function uploadFile(key, filePath, parentId, name) {
  const ext = path.extname(filePath).toLowerCase();
  const mime = MIME[ext] || "application/octet-stream";
  const meta = { name: name || path.basename(filePath), parents: [parentId] };
  const boundary = "rp" + crypto.randomBytes(8).toString("hex");
  const head = Buffer.from(`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(meta)}\r\n--${boundary}\r\nContent-Type: ${mime}\r\n\r\n`);
  const tail = Buffer.from(`\r\n--${boundary}--`);
  const body = Buffer.concat([head, fs.readFileSync(filePath), tail]);
  return call(key, "POST", "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true&fields=id,name,webViewLink",
    body, `multipart/related; boundary=${boundary}`);
}

module.exports = { loadKey, getValues, appendRows, updateRange, firstSheetName, driveList, ensureFolder, uploadFile };

// Loads a script of static/ into a sandbox, the way a browser would run it (no module system, a global `window`).
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function load(file, globals = {}) {
  const src = fs.readFileSync(path.join(__dirname, '..', 'static', file), 'utf8');
  const sandbox = { console, URL, Response, Headers, Request, ...globals };
  sandbox.window = sandbox.window || sandbox;
  vm.createContext(sandbox);
  vm.runInContext(src, sandbox, { filename: file });
  return sandbox;
}
module.exports = { load };

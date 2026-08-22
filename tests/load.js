const fs = require("fs")
const path = require("path")
const vm = require("vm")

const ROOT = path.dirname(__dirname)

function load(relativePath) {
  const source = fs
    .readFileSync(path.join(ROOT, relativePath), "utf8")
    .replace(/^\.pragma library\s*$/m, "")
  const context = {}
  vm.createContext(context)
  vm.runInContext(source, context)
  return context
}

module.exports = { load, ROOT }

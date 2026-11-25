const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.join(__dirname, 'compiled.luau');
const ENTRY = fs.existsSync(path.join(ROOT, 'src', 'init.luau'))
    ? 'src/init.luau'
    : 'src/interface/Pc/init.luau';

const TEXT_EXTENSIONS = new Set(['.luau', '.lua', '.json']);
const ASSET_EXTENSIONS = new Set(['.png', '.ttf', '.otf']);
const SKIP_DIRS = new Set(['.git', 'node_modules', 'Compilation', 'GDH-main']);
const SKIP_FILES = new Set(['ui.luau', 'orig_Widget.luau']);
const SKIP_ASSETS = new Set(['pc_ui.png', 'mobile_ui.png']);

function walk(dir, root, entries) {
    if (SKIP_DIRS.has(path.basename(dir))) return;
    const items = fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));
    for (const item of items) {
        const full = path.join(dir, item.name);
        const rel = path.relative(root, full).split(path.sep).join('/');
        if (item.isDirectory()) {
            walk(full, root, entries);
        } else {
            if (SKIP_FILES.has(item.name)) continue;
            if (SKIP_ASSETS.has(item.name)) continue;
            const ext = path.extname(item.name).toLowerCase();
            if (TEXT_EXTENSIONS.has(ext) || ASSET_EXTENSIONS.has(ext)) {
                entries.push({ rel, full, ext, name: item.name });
            }
        }
    }
}

const entries = [];
walk(ROOT, ROOT, entries);
entries.sort((a, b) => a.rel.localeCompare(b.rel));

function luaEscape(str) {
    let out = '"';
    for (const byte of Buffer.from(str, 'utf8')) {
        const ch = String.fromCharCode(byte);
        if (byte === 92) out += '\\\\';
        else if (byte === 34) out += '\\"';
        else if (byte === 10) out += '\\n';
        else if (byte === 13) out += '\\r';
        else if (byte === 9) out += '\\t';
        else if (byte < 32 || byte > 126) out += '\\x' + byte.toString(16).padStart(2, '0');
        else out += ch;
    }
    return out + '"';
}

const B64_DECODER = `local genv = (typeof(getgenv) == "function" and getgenv())
    or (typeof(_G) == "table" and _G)
    or (typeof(shared) == "table" and shared)
    or (typeof(getfenv) == "function" and getfenv())
    or {}

local PACKAGE = genv.GDH_PACKAGE or {}
local MODULES = genv.GDH_MODULES or {}
genv.GDH_PACKAGE = PACKAGE
genv.GDH_MODULES = MODULES

genv.GDH_B64DECODE = genv.GDH_B64DECODE or function(data)
    local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}
    for i = 1, 64 do lookup[b64chars:sub(i, i)] = i - 1 end
    local out = {}
    local bits = 0
    local value = 0
    for i = 1, #data do
        local c = data:sub(i, i)
        if c == "=" then break end
        local n = lookup[c]
        if n then
            value = value * 64 + n
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                out[#out + 1] = string.char(math.floor(value / 2 ^ bits) % 256)
                value = value % 2 ^ bits
            end
        end
    end
    return table.concat(out)
end
`;

const assetEntries = [];
const dataEntries = [];
const moduleEntries = [];

for (const e of entries) {
    const buf = fs.readFileSync(e.full);
    const key = luaEscape(e.rel);
    if (e.ext === '.png' || e.ext === '.ttf' || e.ext === '.otf') {
        const b64 = buf.toString('base64');
        assetEntries.push(`PACKAGE[${key}] = ${luaEscape(b64)}`);
        assetEntries.push(`PACKAGE[${luaEscape(e.name)}] = PACKAGE[${key}]`);
    } else if (e.ext === '.luau' || e.ext === '.lua') {
        const content = buf.toString('utf8');
        moduleEntries.push(`MODULES[${key}] = function()\n${content}\nend`);
    } else if (e.ext === '.json') {
        const content = buf.toString('utf8');
        dataEntries.push(`PACKAGE[${key}] = ${luaEscape(content)}`);
    }
}

let output = B64_DECODER.trim() + '\n\n';
output += assetEntries.join('\n') + '\n\n';
output += dataEntries.join('\n') + '\n\n';
output += moduleEntries.join('\n') + '\n\n';
output += `local Import = MODULES["src/Function/Import.luau"]()

if Import then
    return Import(${JSON.stringify(ENTRY)})
else
    warn("[GDH Compilation] Failed to initialize Import module.")
end
`;

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, output);

let totalBytes = 0;
for (const e of entries) totalBytes += fs.statSync(e.full).size;

console.log(`Successfully compiled GDH!`);
console.log(`Bundled ${entries.length} items (${(totalBytes / 1024).toFixed(1)} KiB raw source).`);
console.log(`Output: ${OUT} (${(Buffer.byteLength(output) / 1024).toFixed(1)} KiB standalone bundle).`);

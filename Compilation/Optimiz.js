const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const TARGETS = [path.join(ROOT, 'src'), path.join(ROOT, 'Script')];

function longBracket(s, pos) {
    if (s[pos] !== '[') return null;
    let j = pos + 1;
    while (s[j] === '=') j++;
    if (s[j] !== '[') return null;
    const close = ']' + '='.repeat(j - pos - 1) + ']';
    const contentStart = j + 1;
    const contentEnd = s.indexOf(close, contentStart);
    if (contentEnd < 0) return null;
    return { close, contentStart, contentEnd, end: contentEnd + close.length };
}

function stripComments(input) {
    let out = '';
    let i = 0;
    let lineOnlyWhitespace = true;
    const n = input.length;

    while (i < n) {
        const ch = input[i];

        if (ch === '\r' || ch === '\n') {
            if (ch === '\r' && input[i + 1] === '\n') i += 2;
            else i += 1;
            out += '\n';
            lineOnlyWhitespace = true;
            continue;
        }

        if (ch === ' ' || ch === '\t') {
            out += ch;
            i += 1;
            continue;
        }

        if (ch === '-' && input[i + 1] === '-') {
            const block = longBracket(input, i + 2);
            if (block) {
                if (/[\r\n]/.test(input.slice(i, block.end))) lineOnlyWhitespace = true;
                i = block.end;
                continue;
            }
            if (lineOnlyWhitespace && input[i + 2] === '!') {
                const start = i;
                while (i < n && input[i] !== '\n' && input[i] !== '\r') i += 1;
                out += input.slice(start, i);
                lineOnlyWhitespace = false;
                continue;
            }
            while (i < n && input[i] !== '\n' && input[i] !== '\r') i += 1;
            continue;
        }

        if (ch === '"' || ch === "'") {
            const start = i;
            i += 1;
            while (i < n) {
                const c = input[i];
                if (c === '\\') {
                    i = Math.min(n, i + 2);
                    continue;
                }
                if (c === ch) {
                    i += 1;
                    break;
                }
                if (c === '\n' || c === '\r') break;
                i += 1;
            }
            out += input.slice(start, i);
            lineOnlyWhitespace = false;
            continue;
        }

        if (ch === '[') {
            const block = longBracket(input, i);
            if (block) {
                out += input.slice(i, block.end);
                i = block.end;
                lineOnlyWhitespace = false;
                continue;
            }
        }

        out += ch;
        i += 1;
        lineOnlyWhitespace = false;
    }

    return out;
}

function optimize(source) {
    const totalLines = (source.match(/\n/g) || []).length;
    const crlfLines = (source.match(/\r\n/g) || []).length;
    const eol = crlfLines > totalLines - crlfLines ? '\r\n' : '\n';
    const stripped = stripComments(source.replace(/\r\n?/g, '\n'));

    const lines = stripped.split('\n').map((line) =>
        line.replace(/[ \t\r]+$/, '').replace(/;\s*$/, '')
    );
    const result = [];
    let blank = 0;
    for (const line of lines) {
        if (line.trim() === '') {
            blank += 1;
            if (blank <= 1) result.push('');
        } else {
            blank = 0;
            result.push(line);
        }
    }
    while (result.length && result[0] === '') result.shift();
    while (result.length && result[result.length - 1] === '') result.pop();
    return result.join(eol) + eol;
}

const files = [];
for (const target of TARGETS) {
    (function walk(dir) {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            const full = path.join(dir, entry.name);
            if (entry.isDirectory()) walk(full);
            else files.push(full);
        }
    })(target);
}

for (const file of files) {
    fs.writeFileSync(file, optimize(fs.readFileSync(file, 'utf8')), 'utf8');
}

console.log('files.length ');

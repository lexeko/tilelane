.pragma library

function parse(raw) {
    if (!raw || raw.length > 65536)
        return null;
    const text = String(raw).replace(/^\uFEFF/, "").replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "").replace(/\r\n?/g, "\n").replace(/[\x00-\x08\x0b-\x1f\x7f]/g, "");
    const rows = text.split("\n").map(function (line) {
        const cells = [];
        for (let offset = 0; offset < line.length;) {
            const length = line.codePointAt(offset) > 0xffff ? 2 : 1;
            const character = line.slice(offset, offset + length);
            offset += length;
            if (character === "\t") {
                const spaces = 8 - cells.length % 8;
                for (let index = 0; index < spaces; index++)
                    cells.push(" ");
            } else {
                cells.push(character);
            }
        }
        return cells;
    });
    function blank(row) {
        return row.every(function (character) {
            return /\s/.test(character);
        });
    }
    while (rows.length && blank(rows[0]))
        rows.shift();
    while (rows.length && blank(rows[rows.length - 1]))
        rows.pop();
    if (!rows.length || rows.length > 256)
        return null;
    let left = Infinity;
    let right = -1;
    rows.forEach(function (row) {
        row.forEach(function (character, x) {
            if (!/\s/.test(character)) {
                left = Math.min(left, x);
                right = Math.max(right, x);
            }
        });
    });
    if (right < left || right - left >= 256)
        return null;
    return {
        "columns": right - left + 1,
        "rows": rows.map(function (row) {
            return row.slice(left, right + 1);
        })
    };
}

function escapeXml(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\"/g, "&quot;").replace(/'/g, "&apos;");
}

function svg(art, color) {
    if (!art)
        art = parse("██ ██\n\n██ ██");
    if (!/^#[0-9a-f]{6}$/i.test(color))
        color = "#ffffff";
    const shapes = [];
    function rectangle(x, y, width, height, opacity) {
        shapes.push('<rect x="' + x + '" y="' + y + '" width="' + width + '" height="' + height + '"' + (opacity === undefined ? "" : ' opacity="' + opacity + '"') + "/>");
    }
    art.rows.forEach(function (row, y) {
        for (let x = 0; x < row.length; x++) {
            const character = row[x];
            const code = character.codePointAt(0);
            if (/\s/.test(character))
                continue;
            if (code === 0x2588) {
                const start = x;
                while (x + 1 < row.length && row[x + 1] === character)
                    x++;
                rectangle(start * 10, y * 20, (x - start + 1) * 10, 20);
            } else if (code === 0x2580) {
                rectangle(x * 10, y * 20, 10, 10);
            } else if (code >= 0x2581 && code <= 0x2587) {
                const height = (code - 0x2580) * 2.5;
                rectangle(x * 10, y * 20 + 20 - height, 10, height);
            } else if (code >= 0x2589 && code <= 0x258f) {
                rectangle(x * 10, y * 20, (0x2590 - code) * 1.25, 20);
            } else if (code === 0x2590) {
                rectangle(x * 10 + 5, y * 20, 5, 20);
            } else if (code >= 0x2591 && code <= 0x2593) {
                rectangle(x * 10, y * 20, 10, 20, (code - 0x2590) / 4);
            } else {
                shapes.push('<text x="' + x * 10 + '" y="' + (y * 20 + 16) + '" font-family="monospace" font-size="16" textLength="10" lengthAdjust="spacingAndGlyphs">' + escapeXml(character) + "</text>");
            }
        }
    });
    return '<svg xmlns="http://www.w3.org/2000/svg" width="' + art.columns * 10 + '" height="' + art.rows.length * 20 + '" viewBox="0 0 ' + art.columns * 10 + " " + art.rows.length * 20 + '"><g fill="' + color + '">' + shapes.join("") + "</g></svg>";
}

function source(art, color) {
    return "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg(art, color));
}

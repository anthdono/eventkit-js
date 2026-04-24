// Loads repo-root .env into process.env before any tests run. Values already
// set in the environment win — so `TEST_CALENDAR_ID=... npm test` still
// overrides the file.
import * as fs from "fs";
import * as path from "path";

const envPath = path.resolve(__dirname, "..", ".env");
if (fs.existsSync(envPath)) {
    for (const raw of fs.readFileSync(envPath, "utf8").split("\n")) {
        const line = raw.trim();
        if (!line || line.startsWith("#")) continue;
        const m = line.match(/^([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$/);
        if (!m) continue;
        const key = m[1];
        let value = m[2];
        // Strip a single pair of surrounding quotes if present.
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
            value = value.slice(1, -1);
        }
        if (process.env[key] === undefined) process.env[key] = value;
    }
}

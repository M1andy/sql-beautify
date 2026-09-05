/**
 * Test harness for the SQL Beautify formatter.
 *
 * Reads test/hive_test.sql (the deliberately messy input), formats every
 * statement with the vkbeautify engine (DDL statements with sqlddl(), all
 * others with sql() using the default style: uppercase keywords, 4-space
 * indentation, AS alignment up to 150 chars), preserves comments/section
 * headers verbatim, then compares the result byte-for-byte with
 * test/hive_test.output.sql (the golden file defining the target style).
 *
 * Exits with code 0 on success, 1 on any mismatch.
 */

const fs = require("fs");
const path = require("path");
const vkbeautify = require("../node_modules/vkbeautify");

const INPUT = path.join(__dirname, "hive_test.sql");
const GOLDEN = path.join(__dirname, "hive_test.output.sql");

const DDL_RE = /^\s*(create|alter|drop|truncate)\b/i;

/**
 * Split the input text into blocks. Comment-only lines, section headers and
 * blank lines are preserved verbatim; statement blocks are accumulated until
 * a line containing the terminating ";" is found.
 *
 * @param {string[]} lines - Input lines.
 * @returns {Array<{raw: boolean, text: string}>} Blocks.
 */
function parseBlocks(lines) {
	const blocks = [];
	let inBlockComment = false;
	let statement = null;

	const flushStatement = () => {
		if (statement !== null) {
			blocks.push({ raw: false, text: statement.join("\n") });
			statement = null;
		}
	};

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const trimmed = line.trim();

		if (inBlockComment) {
			flushStatement();
			blocks.push({ raw: true, text: line });
			if (trimmed.includes("*/")) inBlockComment = false;
			continue;
		}
		if (trimmed.startsWith("/*") && !trimmed.includes("*/")) {
			flushStatement();
			blocks.push({ raw: true, text: line });
			inBlockComment = true;
			continue;
		}
		if (trimmed === "" || trimmed.startsWith("--")) {
			flushStatement();
			blocks.push({ raw: true, text: line });
			continue;
		}

		if (statement === null) {
			statement = [line];
		} else {
			statement.push(line);
		}
		if (line.includes(";")) {
			flushStatement();
		}
	}
	flushStatement();
	return blocks;
}

/**
 * Format a single statement with the appropriate engine function.
 *
 * @param {string} text - Raw statement text (including trailing ";").
 * @returns {string} Formatted statement text.
 */
function formatStatement(text) {
	return DDL_RE.test(text)
		? vkbeautify.sqlddl(text)
		: vkbeautify.sql(text, true, false, true, 150, 150);
}

/**
 * Build the formatted document from the parsed blocks: statements are
 * formatted individually, raw blocks are kept verbatim, and one blank line is
 * inserted after each statement.
 *
 * @param {Array<{raw: boolean, text: string}>} blocks - Parsed blocks.
 * @returns {string} Full formatted document.
 */
function buildOutput(blocks) {
	const out = [];
	for (const block of blocks) {
		if (block.raw) {
			out.push(block.text);
		} else {
			out.push(formatStatement(block.text).trim());
			out.push("");
		}
	}
	return out
		.join("\n")
		.replace(/\n{3,}/g, "\n\n")
		.trim() + "\n";
}

/**
 * Compare two texts line by line and report the first few differences.
 *
 * @param {string} actual - Formatted output.
 * @param {string} expected - Golden file content.
 * @returns {boolean} True when the texts match.
 */
function compare(actual, expected) {
	if (actual === expected) {
		return true;
	}
	const a = actual.split("\n");
	const e = expected.split("\n");
	const max = Math.max(a.length, e.length);
	let diffs = 0;
	for (let i = 0; i < max && diffs < 5; i++) {
		if (a[i] !== e[i]) {
			diffs++;
			console.log("--- line " + (i + 1) + " ---");
			console.log("  actual  : " + JSON.stringify(a[i]));
			console.log("  expected: " + JSON.stringify(e[i]));
		}
	}
	console.log(
		"total lines: actual=" + a.length + ", expected=" + e.length,
	);
	return false;
}

function normalize(text) {
	return text.replace(/\r\n/g, "\n");
}

/**
 * Inline cases for Velocity #set directive formatting (see CONTEXT.md:
 * #set 指令). Cases whose directive line carries a trailing ";" cannot live
 * in hive_test.sql: parseBlocks closes a statement block on any line
 * containing ";", which would isolate the directive into its own block and
 * force the blank-line statement separation the directive style forbids.
 */
const DIRECTIVE_CASES = [
	{
		name: "uppercase name lowercased, paren padding, trailing ; removed",
		input: "#SET(a='123');\nselect 1 from t;",
		expected: "#set( a='123' )\nSELECT  1\nFROM t\n;\n\n",
	},
	{
		name: "numeric constant kept, = compacted",
		input: "#set( b = 456 )\nselect 1 from t;",
		expected: "#set( b=456 )\nSELECT  1\nFROM t\n;\n\n",
	},
	{
		name: "several directives on one line split onto their own lines",
		input: "#set(a='1'); #set(b=2); select 1 from t;",
		expected: "#set( a='1' )\n#set( b=2 )\nSELECT  1\nFROM t\n;\n\n",
	},
	{
		name: "keyword-colliding variable name stays untouched",
		input: "#set( date = '2024-01-01' )\nselect 1 from t;",
		expected: "#set( date='2024-01-01' )\nSELECT  1\nFROM t\n;\n\n",
	},
	{
		name: "= inside string literal preserved",
		input: "#set( x = 'a=b' )\nselect 1 from t;",
		expected: "#set( x='a=b' )\nSELECT  1\nFROM t\n;\n\n",
	},
	{
		name: "#set inside string literal / -- comment left as-is",
		input: "select a from t where c = '#set(x=1)'; -- #set(y=2)",
		expected: "SELECT  a\nFROM t\nWHERE c = '#set(x=1)'; -- #set(y=2)\n",
	},
	{
		name: "directives keep literal restoration aligned for later literals",
		input: "#set( a='1' )\nselect a from t where b = 'B' and c = 'C';",
		expected:
			"#set( a='1' )\nSELECT  a\nFROM t\nWHERE b = 'B'\nAND c = 'C'\n;\n\n",
	},
];

/**
 * Format every directive case with the default style and compare with the
 * expected output.
 *
 * @returns {number} Number of failed cases.
 */
function runDirectiveCases() {
	let failed = 0;
	for (const c of DIRECTIVE_CASES) {
		const actual = vkbeautify.sql(c.input, true, false, true, 150, 150);
		if (actual !== c.expected) {
			failed++;
			console.log("FAIL directive case: " + c.name);
			console.log("  input   : " + JSON.stringify(c.input));
			console.log("  actual  : " + JSON.stringify(actual));
			console.log("  expected: " + JSON.stringify(c.expected));
		}
	}
	return failed;
}

const inputText = normalize(fs.readFileSync(INPUT, "utf8"));
const goldenText = normalize(fs.readFileSync(GOLDEN, "utf8"));

const blocks = parseBlocks(inputText.split("\n"));
const actual = buildOutput(blocks);

const statementCount = blocks.filter((b) => !b.raw).length;
const directiveFailures = runDirectiveCases();

if (directiveFailures === 0 && compare(actual, goldenText)) {
	console.log(
		"PASS: " +
			DIRECTIVE_CASES.length +
			" directive cases, " +
			statementCount +
			" statements formatted, output matches " +
			path.basename(GOLDEN),
	);
	process.exit(0);
} else {
	console.log(
		"FAIL: formatted output differs from " + path.basename(GOLDEN),
	);
	process.exit(1);
}

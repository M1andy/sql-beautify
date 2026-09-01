/**
 * Verification harness for the SQL Beautify formatter.
 *
 * Reads test/verify_samples.sql (messy, realistic engineering samples whose
 * cases are marked with "-- @case" / "-- @expect" comments), formats every
 * statement with the vkbeautify engine using the extension's default options
 * (DML: uppercase keywords, 4-space indent, AS alignment and IN-list wrapping
 * at 150 chars; DDL: sqlddl()), and writes the result to test_result.sql in
 * the repo root with a checkbox header before each case for manual review.
 *
 * Exits with code 0 on success, 1 on any error.
 */

const fs = require("fs");
const path = require("path");
const vkbeautify = require("../node_modules/vkbeautify");

const INPUT = path.join(__dirname, "verify_samples.sql");
const OUTPUT = path.join(__dirname, "..", "test_result.sql");

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
 * Format a single statement with the appropriate engine function, using the
 * extension's default option values.
 *
 * @param {string} text - Raw statement text (including trailing ";").
 * @returns {string} Formatted statement text.
 */
function formatStatement(text) {
	return DDL_RE.test(text)
		? vkbeautify.sqlddl(text)
		: vkbeautify.sql(text, true, false, true, 150, 150);
}

function normalize(text) {
	return text.replace(/\r\n/g, "\n");
}

const inputText = normalize(fs.readFileSync(INPUT, "utf8"));
const blocks = parseBlocks(inputText.split("\n"));

const out = [];
out.push("-- ============================================================");
out.push("-- SQL Beautify 格式化验证结果（供人工逐项打勾审查）");
out.push("-- 引擎: vkbeautify");
out.push("-- DML 参数: uppercase=true, comma_location=false, bracket_char=true,");
out.push("--           as_loc_cnt=150, in_wrap_length=150");
out.push("-- DDL 参数: vkbeautify.sqlddl() 默认样式");
out.push("-- ============================================================");
out.push("");

let caseNo = 0;
let title = null;
let expects = [];

for (const block of blocks) {
	if (block.raw) {
		const trimmed = block.text.trim();
		let m = trimmed.match(/^--\s*@case\s+(.+)$/);
		if (m) {
			title = m[1].trim();
			expects = [];
			continue;
		}
		m = trimmed.match(/^--\s*@expect\s+(.+)$/);
		if (m) {
			expects.push(m[1].trim());
			continue;
		}
		continue;
	}
	caseNo++;
	const label = title || "未命名用例";
	title = null;
	out.push("-- ------------------------------------------------------------");
	out.push("-- [ ] 用例 " + caseNo + ": " + label);
	for (const e of expects) {
		out.push("-- 期望: " + e);
	}
	out.push("-- ------------------------------------------------------------");
	try {
		out.push(formatStatement(block.text).trim());
	} catch (err) {
		out.push("-- !!! 格式化失败: " + err.message);
	}
	out.push("");
	expects = [];
}

fs.writeFileSync(
	OUTPUT,
	out.join("\n").replace(/\n{3,}/g, "\n\n").trim() + "\n",
	"utf8",
);
console.log("OK: " + caseNo + " cases formatted -> " + OUTPUT);

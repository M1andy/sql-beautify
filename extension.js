/**
 * VS Code extensibility API - referenced as vscode below.
 */
var vscode = require("vscode");
/**
 * Core SQL beautification engine (vendored dependency).
 */
var vkbeautify = require("vkbeautify");

/**
 * Extension entry point. Called by VS Code when the extension is first activated
 * (on the first execution of a registered command). Registers all commands and
 * adds their disposables to the provided context for cleanup.
 *
 * @param {vscode.ExtensionContext} context - Extension context provided by VS Code.
 */
function activate(context) {
	// Use the console to output diagnostic information (console.log) and errors (console.error)
	// This line of code will only be executed once when your extension is activated
	console.log('Congratulations, your extension "sql-beautify" is now active!');

	// Command 1: beautify the selected SQL (or the whole document when nothing is selected)
	// using the user-configured options. Bound to Alt+Shift+F for SQL files.
	var disposable = vscode.commands.registerCommand(
		"extension.beautifySql",
		function () {
			// Collect all non-empty selections, so multi-cursor selections are supported.
			var selections = [];
			for (
				var i = 0;
				i < vscode.window.activeTextEditor.selections.length;
				i++
			) {
				var s = vscode.window.activeTextEditor.selections[i];
				if (!s.start.isEqual(s.end))
					selections.push(new vscode.Range(s.start, s.end));
			}

			// If nothing is selected, fall back to formatting the entire document.
			if (selections.length === 0) {
				selections.push(
					new vscode.Range(
						vscode.window.activeTextEditor.document.positionAt(0),
						vscode.window.activeTextEditor.document.positionAt(
							vscode.window.activeTextEditor.document.getText().length,
						),
					),
				);
			}

			// Beautify each selection and replace it with the formatted result.
			vscode.window.activeTextEditor.edit(function (builder) {
				for (var i = 0; i < selections.length; i++) {
					var range = selections[i];
					var text = vscode.window.activeTextEditor.document
						.getText(range)
						.toString();
					var uppercase = vscode.workspace
						.getConfiguration("extension")
						.get("uppercase"); // Convert keywords to uppercase
					var comma_location = vscode.workspace
						.getConfiguration("extension")
						.get("comma_location"); // Comma position (end of line)
					var bracket_char = vscode.workspace
						.getConfiguration("extension")
						.get("bracket_char"); // Tab vs. space indentation
					var as_loc_cnt = vscode.workspace
						.getConfiguration("extension")
						.get("as_loc_cnt"); // Max column length participating in AS alignment
					var bt = vkbeautify.sql(
						text,
						uppercase,
						comma_location,
						bracket_char,
						as_loc_cnt,
					);
					builder.replace(range, bt);
				}
			});
		},
	);

	// Command 2: beautify Hive DDL statements. Bound to Alt+Shift+L for SQL files.
	var disposable2 = vscode.commands.registerCommand(
		"extension.beautifySqlddl",
		function () {
			// Collect all non-empty selections (supports multi-cursor selection).
			var selections = [];
			for (
				var i = 0;
				i < vscode.window.activeTextEditor.selections.length;
				i++
			) {
				var s = vscode.window.activeTextEditor.selections[i];
				if (!s.start.isEqual(s.end))
					selections.push(new vscode.Range(s.start, s.end));
			}
			// If nothing is selected, fall back to formatting the entire document.
			if (selections.length === 0) {
				selections.push(
					new vscode.Range(
						vscode.window.activeTextEditor.document.positionAt(0),
						vscode.window.activeTextEditor.document.positionAt(
							vscode.window.activeTextEditor.document.getText().length,
						),
					),
				);
			}

			// Beautify each selection and replace it with the formatted DDL.
			vscode.window.activeTextEditor.edit(function (builder) {
				for (var i = 0; i < selections.length; i++) {
					var range = selections[i];
					var text = vscode.window.activeTextEditor.document
						.getText(range)
						.toString();

					var bt = vkbeautify.sqlddl(text);
					builder.replace(range, bt);
				}
			});
		},
	);

	// Command 3: extract column DDL from INSERT statements. Bound to Alt+Shift+; for SQL files.
	var disposable3 = vscode.commands.registerCommand(
		"extension.extractDdl",
		function () {
			// Collect all non-empty selections (supports multi-cursor selection).
			var selections = [];
			for (
				var i = 0;
				i < vscode.window.activeTextEditor.selections.length;
				i++
			) {
				var s = vscode.window.activeTextEditor.selections[i];
				if (!s.start.isEqual(s.end))
					selections.push(new vscode.Range(s.start, s.end));
			}
			// If nothing is selected, fall back to processing the entire document.
			if (selections.length === 0) {
				selections.push(
					new vscode.Range(
						vscode.window.activeTextEditor.document.positionAt(0),
						vscode.window.activeTextEditor.document.positionAt(
							vscode.window.activeTextEditor.document.getText().length,
						),
					),
				);
			}

			// Extract the DDL of each selection and replace it with the result.
			vscode.window.activeTextEditor.edit(function (builder) {
				for (var i = 0; i < selections.length; i++) {
					var range = selections[i];
					var text = vscode.window.activeTextEditor.document
						.getText(range)
						.toString();
					var bt = vkbeautify.extractddl(text);
					builder.replace(range, bt);
				}
			});
		},
	);

	// Register the disposables so the commands are cleaned up when the extension is deactivated.
	context.subscriptions.push(disposable);
	context.subscriptions.push(disposable2);
	context.subscriptions.push(disposable3);
}
exports.activate = activate;

/**
 * Cleanup hook. Called by VS Code when the extension is deactivated.
 */
function deactivate() {}
exports.deactivate = deactivate;

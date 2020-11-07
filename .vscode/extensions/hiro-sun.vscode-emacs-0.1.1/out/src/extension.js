"use strict";
const vscode = require('vscode');
const operation_1 = require('./operation');
var inMarkMode = false;
function activate(context) {
    let op = new operation_1.Operation(), commandList = [
        "C-g",
        // Edit
        "C-k", "C-w", "M-w", "C-y", "C-x_C-o",
        "C-x_u", "C-/",
        // R-Mode
        "C-x_r"
    ], cursorMoves = [
        "cursorUp", "cursorDown", "cursorLeft", "cursorRight",
        "cursorHome", "cursorEnd",
        "cursorWordLeft", "cursorWordRight",
        "cursorPageDown", "cursorPageUp",
        "cursorTop", "cursorBottom"
    ];
    commandList.forEach(commandName => {
        context.subscriptions.push(registerCommand(commandName, op));
    });
    cursorMoves.forEach(element => {
        context.subscriptions.push(vscode.commands.registerCommand("emacs." + element, () => {
            vscode.commands.executeCommand(inMarkMode ?
                element + "Select" :
                element);
        }));
    });
    // 'type' is not an "emacs." command and should be registered separately
    context.subscriptions.push(vscode.commands.registerCommand("type", function (args) {
        if (!vscode.window.activeTextEditor) {
            return;
        }
        op.onType(args.text);
    }));
    initMarkMode(context);
}
exports.activate = activate;
function deactivate() {
}
exports.deactivate = deactivate;
function initMarkMode(context) {
    context.subscriptions.push(vscode.commands.registerCommand('emacs.enterMarkMode', () => {
        initSelection();
        inMarkMode = true;
        vscode.window.setStatusBarMessage("Mark Set", 1000);
    }));
    context.subscriptions.push(vscode.commands.registerCommand('emacs.exitMarkMode', () => {
        vscode.commands.executeCommand("cancelSelection");
        if (inMarkMode) {
            inMarkMode = false;
            vscode.window.setStatusBarMessage("Mark deactivated", 1000);
        }
    }));
}
function registerCommand(commandName, op) {
    return vscode.commands.registerCommand("emacs." + commandName, op.getCommand(commandName));
}
function initSelection() {
    var currentPosition = vscode.window.activeTextEditor.selection.active;
    vscode.window.activeTextEditor.selection = new vscode.Selection(currentPosition, currentPosition);
}
//# sourceMappingURL=extension.js.map
"use strict";
const vscode = require('vscode');
const registers_1 = require('./registers');
var KeybindProgressMode;
(function (KeybindProgressMode) {
    KeybindProgressMode[KeybindProgressMode["None"] = 0] = "None";
    KeybindProgressMode[KeybindProgressMode["RMode"] = 1] = "RMode";
    KeybindProgressMode[KeybindProgressMode["RModeS"] = 2] = "RModeS";
    KeybindProgressMode[KeybindProgressMode["RModeI"] = 3] = "RModeI";
    KeybindProgressMode[KeybindProgressMode["AMode"] = 4] = "AMode";
    KeybindProgressMode[KeybindProgressMode["MacroRecordingMode"] = 5] = "MacroRecordingMode"; // (FUTURE, TBD) Emacs macro recording [started by 'Ctrl-x+('] is currently in progress
})(KeybindProgressMode || (KeybindProgressMode = {}));
;
class Editor {
    constructor() {
        this.killRing = '';
        this.isKillRepeated = false;
        this.keybindProgressMode = KeybindProgressMode.None;
        this.registersStorage = {};
        vscode.window.onDidChangeTextEditorSelection(() => {
            this.isKillRepeated = false;
        });
    }
    setStatusBarMessage(text) {
        return vscode.window.setStatusBarMessage(text, 1000);
    }
    setStatusBarPermanentMessage(text) {
        return vscode.window.setStatusBarMessage(text);
    }
    getSelectionRange() {
        let selection = vscode.window.activeTextEditor.selection, start = selection.start, end = selection.end;
        return (start.character !== end.character || start.line !== end.line) ? new vscode.Range(start, end) : null;
    }
    getSelection() {
        return vscode.window.activeTextEditor.selection;
    }
    setSelection(start, end) {
        let editor = vscode.window.activeTextEditor;
        editor.selection = new vscode.Selection(start, end);
    }
    /** Behave like Emacs kill command
    */
    kill() {
        let saveIsKillRepeated = this.isKillRepeated, promises = [
            vscode.commands.executeCommand("emacs.exitMarkMode"),
            vscode.commands.executeCommand("cursorEndSelect")
        ];
        Promise.all(promises).then(() => {
            let selection = this.getSelection(), range = new vscode.Range(selection.start, selection.end);
            this.setSelection(range.start, range.start);
            this.isKillRepeated = saveIsKillRepeated;
            if (range.isEmpty) {
                this.killEndOfLine(saveIsKillRepeated, range);
            }
            else {
                this.killText(range);
            }
        });
    }
    killEndOfLine(saveIsKillRepeated, range) {
        let doc = vscode.window.activeTextEditor.document, eof = doc.lineAt(doc.lineCount - 1).range.end;
        if (doc.lineCount && !range.end.isEqual(eof) &&
            doc.lineAt(range.start.line).rangeIncludingLineBreak) {
            this.isKillRepeated ? this.killRing += '\n' : this.killRing = '\n';
            saveIsKillRepeated = true;
        }
        else {
            this.setStatusBarMessage("End of buffer");
        }
        vscode.commands.executeCommand("deleteRight").then(() => {
            this.isKillRepeated = saveIsKillRepeated;
        });
    }
    killText(range) {
        let text = vscode.window.activeTextEditor.document.getText(range), promises = [
            Editor.delete(range),
            vscode.commands.executeCommand("emacs.exitMarkMode")
        ];
        this.isKillRepeated ? this.killRing += text : this.killRing = text;
        Promise.all(promises).then(() => {
            this.isKillRepeated = true;
        });
    }
    copy(range = null) {
        this.killRing = '';
        if (range === null) {
            range = this.getSelectionRange();
            if (range === null) {
                vscode.commands.executeCommand("emacs.exitMarkMode");
                return false;
            }
        }
        this.killRing = vscode.window.activeTextEditor.document.getText(range);
        vscode.commands.executeCommand("emacs.exitMarkMode");
        return this.killRing !== undefined;
    }
    cut() {
        let range = this.getSelectionRange();
        if (!this.copy(range)) {
            return false;
        }
        Editor.delete(range);
        return true;
    }
    yank() {
        if (this.killRing.length === 0) {
            return false;
        }
        vscode.window.activeTextEditor.edit(editBuilder => {
            editBuilder.insert(this.getSelection().active, this.killRing);
        });
        this.isKillRepeated = false;
        return true;
    }
    undo() {
        vscode.commands.executeCommand("undo");
    }
    getFirstBlankLine(range) {
        let doc = vscode.window.activeTextEditor.document;
        if (range.start.line === 0) {
            return range;
        }
        range = doc.lineAt(range.start.line - 1).range;
        while (range.start.line > 0 && range.isEmpty) {
            range = doc.lineAt(range.start.line - 1).range;
        }
        if (range.isEmpty) {
            return range;
        }
        else {
            return doc.lineAt(range.start.line + 1).range;
        }
    }
    deleteBlankLines() {
        let selection = this.getSelection(), anchor = selection.anchor, doc = vscode.window.activeTextEditor.document, range = doc.lineAt(selection.start.line).range, promises = [], nextLine;
        if (range.isEmpty) {
            range = this.getFirstBlankLine(range);
            anchor = range.start;
            nextLine = range.start;
        }
        else {
            nextLine = range.start.translate(1, 0);
        }
        selection = new vscode.Selection(nextLine, nextLine);
        vscode.window.activeTextEditor.selection = selection;
        for (let line = selection.start.line; line < doc.lineCount - 1 && doc.lineAt(line).range.isEmpty; ++line) {
            promises.push(vscode.commands.executeCommand("deleteRight"));
        }
        Promise.all(promises).then(() => {
            vscode.window.activeTextEditor.selection = new vscode.Selection(anchor, anchor);
        });
    }
    static delete(range = null) {
        if (range === null) {
            let start = new vscode.Position(0, 0), doc = vscode.window.activeTextEditor.document, end = doc.lineAt(doc.lineCount - 1).range.end;
            range = new vscode.Range(start, end);
        }
        return vscode.window.activeTextEditor.edit(editBuilder => {
            editBuilder.delete(range);
        });
    }
    setRMode() {
        this.setStatusBarPermanentMessage("C-x r");
        this.keybindProgressMode = KeybindProgressMode.RMode;
        return;
    }
    onType(text) {
        let fHandled = false;
        switch (this.keybindProgressMode) {
            case KeybindProgressMode.RMode:
                switch (text) {
                    // Rectangles
                    case 'r':
                        this.setStatusBarMessage("'C-x r r' (Copy rectangle to register) is not supported.");
                        this.keybindProgressMode = KeybindProgressMode.None;
                        fHandled = true;
                        break;
                    case 'k':
                        this.setStatusBarMessage("'C-x r k' (Kill rectangle) is not supported.");
                        this.keybindProgressMode = KeybindProgressMode.None;
                        fHandled = true;
                        break;
                    case 'y':
                        this.setStatusBarMessage("'C-x r y' (Yank rectangle) is not supported.");
                        this.keybindProgressMode = KeybindProgressMode.None;
                        fHandled = true;
                        break;
                    case 'o':
                        this.setStatusBarMessage("'C-x r o' (Open rectangle) is not supported.");
                        this.keybindProgressMode = KeybindProgressMode.None;
                        fHandled = true;
                        break;
                    case 'c':
                        this.setStatusBarMessage("'C-x r c' (Blank out rectangle) is not supported.");
                        this.keybindProgressMode = KeybindProgressMode.None;
                        fHandled = true;
                        break;
                    case 't':
                        this.setStatusBarMessage("'C-x r t' (prefix each line with a string) is not supported.");
                        this.keybindProgressMode = KeybindProgressMode.None;
                        fHandled = true;
                        break;
                    // Registers
                    case 's':
                        this.setStatusBarPermanentMessage("Copy to register:");
                        this.keybindProgressMode = KeybindProgressMode.RModeS;
                        fHandled = true;
                        break;
                    case 'i':
                        this.setStatusBarPermanentMessage("Insert register:");
                        this.keybindProgressMode = KeybindProgressMode.RModeI;
                        fHandled = true;
                        break;
                    default:
                        break;
                }
                break;
            case KeybindProgressMode.RModeS:
                this.setStatusBarPermanentMessage("");
                this.SaveTextToRegister(text);
                this.keybindProgressMode = KeybindProgressMode.None;
                fHandled = true;
                break;
            case KeybindProgressMode.RModeI:
                this.setStatusBarPermanentMessage("");
                this.RestoreTextFromRegister(text);
                this.keybindProgressMode = KeybindProgressMode.None;
                fHandled = true;
                break;
            case KeybindProgressMode.AMode: // not supported [yet]
            case KeybindProgressMode.MacroRecordingMode: // not supported [yet]
            case KeybindProgressMode.None:
            default:
                this.keybindProgressMode = KeybindProgressMode.None;
                this.setStatusBarPermanentMessage("");
                break;
        }
        if (!fHandled) {
            // default input handling: pass control to VSCode
            vscode.commands.executeCommand('default:type', {
                text: text
            });
        }
        return;
    }
    SaveTextToRegister(registerName) {
        if (null == registerName) {
            return;
        }
        let range = this.getSelectionRange();
        if (range !== null) {
            let selectedText = vscode.window.activeTextEditor.document.getText(range);
            if (null !== selectedText) {
                this.registersStorage[registerName] = registers_1.RegisterContent.fromRegion(selectedText);
            }
        }
        return;
    }
    RestoreTextFromRegister(registerName) {
        vscode.commands.executeCommand("emacs.exitMarkMode"); // emulate Emacs 
        let obj = this.registersStorage[registerName];
        if (null == obj) {
            this.setStatusBarMessage("Register does not contain text.");
            return;
        }
        if (registers_1.RegisterKind.KText === obj.getRegisterKind()) {
            const content = obj.getRegisterContent();
            if (typeof content === 'string') {
                vscode.window.activeTextEditor.edit(editBuilder => {
                    editBuilder.insert(this.getSelection().active, content);
                });
            }
        }
        return;
    }
}
exports.Editor = Editor;
//# sourceMappingURL=editor.js.map
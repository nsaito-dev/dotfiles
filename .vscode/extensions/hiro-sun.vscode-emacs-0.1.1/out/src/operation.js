"use strict";
const editor_1 = require('./editor');
class Operation {
    constructor() {
        this.commandList = {};
        this.editor = new editor_1.Editor();
        this.commandList = {
            'C-k': () => {
                this.editor.kill();
            },
            'C-w': () => {
                if (this.editor.cut()) {
                    this.editor.setStatusBarMessage("Cut");
                }
                else {
                    this.editor.setStatusBarMessage("Cut Error!");
                }
            },
            'M-w': () => {
                if (this.editor.copy()) {
                    this.editor.setStatusBarMessage("Copy");
                }
                else {
                    this.editor.setStatusBarMessage("Copy Error!");
                }
            },
            'C-y': () => {
                if (this.editor.yank()) {
                    this.editor.setStatusBarMessage("Yank");
                }
                else {
                    this.editor.setStatusBarMessage("Kill ring is empty");
                }
            },
            "C-x_C-o": () => {
                this.editor.deleteBlankLines();
            },
            "C-x_u": () => {
                this.editor.undo();
                this.editor.setStatusBarMessage("Undo!");
            },
            "C-/": () => {
                this.editor.undo();
                this.editor.setStatusBarMessage("Undo!");
            },
            'C-g': () => {
                this.editor.setStatusBarMessage("Quit");
            },
            "C-x_r": () => {
                this.editor.setRMode();
            },
        };
    }
    getCommand(commandName) {
        return this.commandList[commandName];
    }
    onType(text) {
        this.editor.onType(text);
    }
}
exports.Operation = Operation;
//# sourceMappingURL=operation.js.map
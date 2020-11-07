var vscode = require('vscode');
var point_1 = require('./point');
var edit_mode_1 = require('./edit_mode');
var Motion = (function () {
    function Motion(edit_mode) {
        var _this = this;
        this.column = 0;
        this.disposable_list = new Array();
        this.edit_mode = edit_mode;
        if (vscode.window.activeTextEditor) {
            var current_position = vscode.window.activeTextEditor.selection.active;
            this.point = new point_1.Point(current_position.line, current_position.character);
            this.column = this.point.character;
        }
        this.disposable_list.push(vscode.window.onDidChangeActiveTextEditor(function (e) {
            if (e.selection) {
                var current_position = vscode.window.activeTextEditor.selection.active;
                _this.point = new point_1.Point(current_position.line, current_position.character);
                _this.column = _this.point.character;
            }
        }));
        this.disposable_list.push(vscode.window.onDidChangeTextEditorSelection(function (e) {
            var selection = e.selections[0];
            if (selection) {
                var line = selection.active.line;
                var character = selection.active.character;
                if (_this.point.line != line || _this.point.character != character) {
                    _this.point = new point_1.Point(line, character);
                    _this.column = _this.point.character;
                }
            }
        }));
    }
    Motion.prototype.updateMode = function (edit_mode) {
        this.edit_mode = edit_mode;
        if (this.edit_mode === edit_mode_1.EditMode.MARK) {
            this.mark_point = new point_1.Point(this.point.line, this.point.character);
        }
        else {
            this.mark_point = null;
        }
        return this;
    };
    Motion.prototype.move = function (line, character) {
        if (line === void 0) { line = null; }
        if (character === void 0) { character = null; }
        if (this.edit_mode === edit_mode_1.EditMode.MARK) {
            return this.select(line, character);
        }
        if (line != null && character != null) {
            this.point = new point_1.Point(line, character);
        }
        var selection = new vscode.Selection(this.point, this.point);
        vscode.window.activeTextEditor.selection = selection;
        var range = new vscode.Range(this.point, this.getPoint().translate(0, 1));
        vscode.window.activeTextEditor.revealRange(range, vscode.TextEditorRevealType.InCenterIfOutsideViewport);
        return this;
    };
    Motion.prototype.select = function (line, character) {
        if (line === void 0) { line = null; }
        if (character === void 0) { character = null; }
        if (line != null && character != null) {
            this.mark_point = new point_1.Point(line, character);
        }
        var selection = new vscode.Selection(this.mark_point, this.getPoint());
        vscode.window.activeTextEditor.selection = selection;
        var range = new vscode.Range(this.point, this.getPoint().translate(0, 1));
        vscode.window.activeTextEditor.revealRange(range, vscode.TextEditorRevealType.InCenterIfOutsideViewport);
        return this;
    };
    Motion.prototype.quit = function () {
        vscode.window.activeTextEditor.selection = new vscode.Selection(this.point, this.point);
        return this;
    };
    Motion.prototype.right = function () {
        this.point = this.point.right();
        this.column = this.point.character;
        return this;
    };
    Motion.prototype.left = function () {
        this.point = this.point.left();
        this.column = this.point.character;
        return this;
    };
    Motion.prototype.down = function () {
        if (!this.point.isLastLine()) {
            this.point = this.point.nextLine(this.column);
        }
        return this;
    };
    Motion.prototype.up = function () {
        if (!this.point.isFirstLine()) {
            this.point = this.point.prevLine(this.column);
        }
        return this;
    };
    Motion.prototype.leftWord = function () {
        this.point = this.point.leftWord();
        this.column = this.getPoint().character;
        return this;
    };
    Motion.prototype.rightWord = function () {
        this.point = this.point.rightWord();
        this.column = this.getPoint().character;
        return this;
    };
    Motion.prototype.lineBegin = function () {
        this.point = this.point.lineBegin();
        this.column = this.point.character;
        return this;
    };
    Motion.prototype.lineEnd = function () {
        this.point = this.point.lineEnd();
        this.column = this.point.character;
        return this;
    };
    Motion.prototype.documentBegin = function () {
        this.point = this.point.documentBegin();
        this.column = this.point.character;
        return this;
    };
    Motion.prototype.documentEnd = function () {
        this.point = this.point.documentEnd();
        this.column = this.point.character;
        return this;
    };
    Motion.prototype.getPoint = function () {
        return this.point;
    };
    Motion.prototype.getMarkPoint = function () {
        return this.mark_point;
    };
    Motion.prototype.dispose = function () {
        _.each(this.disposable_list, function (disposable) {
            disposable.dispose();
        });
    };
    return Motion;
})();
exports.Motion = Motion;
//# sourceMappingURL=motion.js.map
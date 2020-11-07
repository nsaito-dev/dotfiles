var __extends = (this && this.__extends) || function (d, b) {
    for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p];
    function __() { this.constructor = d; }
    d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
};
var vscode = require('vscode');
var _ = require('lodash');
var Point = (function (_super) {
    __extends(Point, _super);
    function Point(line, character) {
        _super.call(this, line, character);
        this.non_word_characters = "/\\()\"':,.;<>~!@#$%^&*|+=[]{}`?-";
        this.word_delimiters = ["(", ")", "[", "]", "{", "}", ":", " ", "=", "<", ">", "|", "/", "'", "\"", "~", "`", "@", "*", "+", "-", "?", ",", ".", ";"];
        var segments = ["(^[\t ]*$)"];
        segments.push("([^\\s" + _.escapeRegExp(this.non_word_characters) + "]+)");
        segments.push("[\\s" + _.escapeRegExp(this.non_word_characters) + "]+");
        this.non_word_char_regex = new RegExp(segments.join("|"), "g");
    }
    Point.prototype.create = function (line, character) {
        return new Point(line, character);
    };
    Point.prototype.left = function () {
        return (!this.isLineBegin()) ? new Point(this.line, this.character - 1) : this;
    };
    Point.prototype.right = function () {
        return (!this.isLineEnd()) ? new Point(this.line, this.character + 1) : this;
    };
    Point.prototype.nextLine = function (column) {
        return (!this.isBufferEnd()) ? new Point(this.line + 1, Math.min(this.getLineLength(this.line + 1), column)) : this;
    };
    Point.prototype.prevLine = function (column) {
        return (!this.isBufferEnd()) ? new Point(this.line - 1, Math.min(this.getLineLength(this.line - 1), column)) : this;
    };
    Point.prototype.leftWord = function () {
        var current_line = vscode.window.activeTextEditor.document.lineAt(this);
        if (!this.isFirstLine() && this.isExistWordAtCurrentLine(current_line)) {
            var prev_line = new Point(this.line - 1, this.character);
            return prev_line.lineEnd();
        }
        var line = this.getLineAt(this);
        var words = line.text.match(this.non_word_char_regex);
        var start_word;
        var end_word;
        if (words) {
            words = words.reverse();
            end_word = line.range.end.character;
            for (var index = 0; index < words.length; index++) {
                end_word = end_word - words[index].length;
                var word = words[index].trim();
                if (word.length > 0) {
                    start_word = line.text.indexOf(word, end_word);
                    if (start_word !== -1 && this.character > start_word) {
                        return new Point(this.line, start_word);
                    }
                }
            }
        }
        return this.lineBegin();
    };
    Point.prototype.rightWord = function () {
        if (!this.isLastLine() && this.character === this.lineEnd().character) {
            var line_1 = this.getLineAt(this.translate(1));
            return new Point(line_1.lineNumber, line_1.firstNonWhitespaceCharacterIndex);
        }
        var line = this.getLineAt(this);
        var words = line.text.match(this.non_word_char_regex);
        var start_word;
        var end_word;
        if (words) {
            for (var index = 0; index < words.length; index++) {
                var word = words[index].trim();
                if (word.length > 0) {
                    start_word = line.text.indexOf(word, end_word);
                    end_word = start_word + word.length;
                    if (this.character < start_word) {
                        return new Point(this.line, start_word);
                    }
                }
            }
        }
        return this.lineEnd();
    };
    Point.prototype.documentBegin = function () {
        return new Point(0, 0);
    };
    Point.prototype.documentEnd = function () {
        var line_count = vscode.window.activeTextEditor.document.lineCount;
        var max_line = line_count > 0 ? line_count - 1 : 0;
        var max_character = this.getLineLength(max_line);
        return new Point(max_line, max_character);
    };
    Point.prototype.isFirstLine = function () {
        return this.line === 0;
    };
    Point.prototype.isLastLine = function () {
        return this.line === (vscode.window.activeTextEditor.document.lineCount - 1);
    };
    Point.prototype.isExistWordAtCurrentLine = function (current_line) {
        return this.character <= current_line.firstNonWhitespaceCharacterIndex;
    };
    Point.prototype.getLineAt = function (position) {
        return vscode.window.activeTextEditor.document.lineAt(position);
    };
    Point.prototype.lineBegin = function () {
        return new Point(this.line, 0);
    };
    Point.prototype.lineEnd = function () {
        return new Point(this.line, this.getLineLength(this.line));
    };
    Point.prototype.isLineBegin = function () {
        return this.character === 0;
    };
    Point.prototype.isLineEnd = function () {
        return this.character === this.getLineLength(this.line);
    };
    Point.prototype.isBufferBegin = function () {
        return false;
    };
    Point.prototype.isBufferEnd = function () {
        return false;
    };
    Point.prototype.getLineLength = function (line_number) {
        if (line_number === void 0) { line_number = null; }
        line_number = (line_number === null) ? vscode.window.activeTextEditor.selection.active.line : line_number;
        if (line_number < vscode.window.activeTextEditor.document.lineCount) {
            var count = vscode.window.activeTextEditor.document.lineAt(line_number).text.length;
            return count;
        }
        return 0;
    };
    return Point;
})(vscode.Position);
exports.Point = Point;
//# sourceMappingURL=point.js.map
var vscode = require('vscode');
var StatusBar = (function () {
    function StatusBar() {
        this.item = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left);
        this.item.show();
        this.init();
    }
    StatusBar.prototype.addText = function (text) {
        this.item.text += text;
        return this;
    };
    StatusBar.prototype.setText = function (text) {
        this.item.text = text;
        return this;
    };
    StatusBar.prototype.clear = function () {
        var _this = this;
        setTimeout(function () {
            _this.init();
        }, 1000);
        return this;
    };
    StatusBar.prototype.init = function () {
        this.item.text = "";
        return this;
    };
    return StatusBar;
})();
exports.StatusBar = StatusBar;
//# sourceMappingURL=status_bar.js.map
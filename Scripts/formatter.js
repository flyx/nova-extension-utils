const ConfigItem = require("config-item.js").ConfigItem;

class Formatter {
  /// Will register a command with id `identifier` with Nova.
  /// The given identifier should start with your extension's identifier.
  ///
  /// `path` may be either a string or a ConfigItem with type path.
  /// it specifies the path to the executable doing the formatting.
  ///
  /// `syntaxes` must be a string array containing all syntax names for
  /// which this formatter should be used.
  ///
  /// `args` must be a either a string array or a ConfigItem returning a string array.
  /// it defines the arguments passed to the formatter.
  /// the arguments must tell the formatter to take input from stdin and write output to stdout.
  ///
  /// `autoFormatCfg` may be a ConfigItem or null.
  /// The formatter will auto-format files before saving if this is a ConfigItem
  /// and the ConfigItem's value is true.
  constructor(identifier, path, args, syntaxes, autoFormatCfg) {
    this.path = path;
    this.args = args;
    this.syntaxes = syntaxes;
    this.autoFormatCfg = autoFormatCfg;
    
    this.command = nova.commands.register(
      identifier, this.formatDocument, this
    );
    
    this.callbacks = [];
    this.callbacks.push(nova.workspace.onDidAddTextEditor((editor) => {
      this.callbacks.push(
        editor.onWillSave(async (textEditor) => {
          if (this.autoFormatCfg && this.autoFormatCfg.value()) {
            await nova.commands.invoke(identifier, textEditor);
          }
        })
      );
    }));
  }
  
  dispose() {
    this.command.dispose();
    for (const callback of this.callbacks) callback.dispose();
    this.command = undefined;
    this.callbacks = [];
  }
  
  formatDocument(a, b) {
    // depends on how formatDocument has been called.
    // if b is set, a is the workspace.
    const editor = b ? b : a;
    const doc = editor.document;
    if (this.syntaxes.includes(doc.syntax)) {
      const formatter = (
        this.path instanceof ConfigItem ? this.path.value() : this.path
      );
      const process = new Process("/usr/bin/env", {
        cwd: nova.workspace.path,
        stdio: "pipe",
        args: [
          formatter,
          ...(this.args instanceof ConfigItem ? this.args.value() : this.args)
        ],
      });
      process.onStderr((line) => console.error(`[${formatter}] ${line}`));
      
      const all = new Range(0, doc.length);
      
      return new Promise((resolve, reject) => {
        let result = "";
        process.onStdout((line) => result += line);
        process.onDidExit((status) => {
          if (status == 0) {
            editor.edit((edit) => {
              edit.replace(all, result);
            }).then(() => resolve());
          } else (reject());
        });
        
        const writer = process.stdin.getWriter();
        writer.ready.then(() => {
          writer.write(doc.getTextInRange(all));
          writer.close();
        });
        process.start();
      });
    }
  }
}

exports.Formatter = Formatter;
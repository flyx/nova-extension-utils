// code formatting support
// part of nova-extension-utils

const ConfigItem = require("config-item.js").ConfigItem;

class Formatter {
  /// Will register a command with id `identifier` with Nova.
  /// The given identifier should start with your extension's identifier.
  ///
  /// `path` must be resolvable via ConfigItem.process to a string.
  /// This parameter specifies the path to the executable doing the formatting.
  ///
  /// `args` must be resolvable via ConfigItem.process to an array of strings.
  /// This parameter defines the arguments passed to the formatter.
  ///
  /// `syntaxes` must be resolvable via ConfigItem.process to a string array.
  /// The formatter will format only files whose syntax is contained in this array.
  ///
  /// `autoFormat` may be null/undefined. If not, it must be resolvable to a boolean value.
  /// The formatter will auto-format files before saving if `autoFormat` is set and resolves to true.
  constructor(identifier, path, args, syntaxes, autoFormat) {
    this.path = path;
    this.args = args;
    this.syntaxes = syntaxes;
    this.autoFormat = autoFormat;
    
    this.command = nova.commands.register(
      identifier, this.formatDocument, this
    );
    
    this.callbacks = [];
    this.callbacks.push(nova.workspace.onDidAddTextEditor((editor) => {
      this.callbacks.push(
        editor.onWillSave(async (textEditor) => {
          if (ConfigItem.process(this.autoFormat)) {
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
    const syntaxes = ConfigItem.process(this.syntaxes);
    if (syntaxes.includes(doc.syntax)) {
      const formatter = ConfigItem.process(this.path);
      const process = new Process("/usr/bin/env", {
        cwd: nova.workspace.path,
        stdio: "pipe",
        args: [
          formatter,
          ...(ConfigItem.process(this.args))
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
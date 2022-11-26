// language server support
// part of nova-extension-utils

const ConfigItem = require("config-item.js").ConfigItem;

class LanguageServer {
  /// `clientIdentifier` is the identifier used for the LanguageClient that will be started.
  /// `path` may be a ConfigItem or a literal string.
  /// `args` may be a ConfigItem, a literal array, an array of ConfigItem|string, or null/undefined.
  constructor(clientIdentifier, clientOptions, path, args) {
    this.path = path;
    this.args = args;
    this.clientIdentifier = clientIdentifier;
    this.clientOptions = clientOptions;
    // Observe the configuration setting for the server's location, and restart the server on change
    ConfigItem.registerChangeListener(path, this.start, this);
    this.start();
  }
    
  dispose() {
    this.stop();
  }
    
  start() {
    this.stop();
    const path = ConfigItem.process(this.path);
    if (path === null || path === "") {
      if (nova.inDevMode()) console.log(`[${this.clientIdentifier}] not starting server due to empty path`);
      return;
    }
    console.log(`[${this.clientIdentifier}] searching for ${path} (${typeof path})`);
    
    const proc = new Process("/usr/bin/which", {
      args: [path],
      shell: true
    });
    let absPath = null;
    proc.onStdout((line) => {
      absPath = line.trim();
    });
    proc.onStderr((line) => {
      console.error(`[${this.clientIdentifier}] while looking up ${path}: ${line}`);
    });
    proc.onDidExit((status) => {
      if (status == 0) {
        let serverOptions = {
          path: absPath,
          args: ConfigItem.process(this.args, [])
        };
        let client = new LanguageClient(
          this.clientIdentifier,
          path,
          serverOptions,
          this.clientOptions
        );
        
        try {
          client.start();
          if (nova.inDevMode()) console.log(`[${this.clientIdentifier}] started language server: ${absPath}`);
          
          this.languageClient = client;
        } catch (err) {
          console.error(`[${this.clientIdentifier}] while trying to start ${absPath}:`, err)
        }
      } else {
        console.warn(`[${this.clientIdentifier}] unable to find '${path}' in PATH`);
      }
    });
    proc.start();
  }
    
  stop() {
    if (this.languageClient) {
      this.languageClient.stop();
      this.languageClient = null;
    }
  }
}

exports.LanguageServer = LanguageServer;
class LanguageServer {
  constructor(identifier, clientOptions, pathConfigItem) {
    this.path = pathConfigItem;
    this.identifier = identifier;
    this.clientOptions = clientOptions;
    // Observe the configuration setting for the server's location, and restart the server on change
    pathConfigItem.onDidChange(() => this.start());
    this.start();
  }
    
  dispose() {
    this.stop();
  }
    
  start() {
    this.stop();
    const path = this.path.value();
    if (path === null || path === "") {
      if (nova.inDevMode()) console.log(`[${this.identifier}] not starting server due to empty path`);
      return;
    }
    const proc = new Process("/usr/bin/which", {
      args: [path]
    });
    let absPath = null;
    proc.onStdout((line) => {
      absPath = line.trim();
    });
    proc.onDidExit((status) => {
      if (status == 0) {
        let serverOptions = {
          path: absPath,
          args: [],
        };
        let client = new LanguageClient(
          this.identifier + ".client",
          path,
          serverOptions,
          this.clientOptions
        );
        
        try {
          client.start();
          if (nova.inDevMode()) console.log(`[${this.identifier}] started language server: ${absPath}`);
          
          this.languageClient = client;
        } catch (err) {
          console.error(`[${this.identifier}] while trying to start ${absPath}:`, err)
        }
      } else {
        console.warn(`[${this.identifier}] unable to find '${path}' in PATH`);
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
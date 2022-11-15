class LanguageServer {
  constructor(identifier, clientOptions, pathConfigItem) {
    this.path = pathConfigItem;
    this.identifier = identifier;
    this.clientOptions = clientOptions;
    // Observe the configuration setting for the server's location, and restart the server on change
    pathConfigItem.onDidChange(() => this.start());
    this.start();
  }
    
  deactivate() {
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
        var serverOptions = {
          path: absPath,
          args: [],
        };
        var client = new LanguageClient(
          this.identifier + ".client",
          path,
          serverOptions,
          this.clientOptions
        );
        
        try {
          client.start();
          if (nova.inDevMode()) console.log(`[${this.identifier}] started language server: ${absPath}`);
          
          // Add the client to the subscriptions to be cleaned up
          nova.subscriptions.add(client);
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
      nova.subscriptions.remove(this.languageClient);
      this.languageClient = null;
    }
  }
}

exports.LanguageServer = LanguageServer;
{
  inputs = {
    nixpkgs.url    = "github:NixOS/nixpkgs/nixos-22.05";
    nova-utils.url = "github:flyx/nova-extension-utils";
    utils.url      = "github:numtide/flake-utils";
    
    # This is an example. Reference any tree sitter grammar you want to use here.
    tree-sitter-nix = {
      url = "github:cstrahan/tree-sitter-nix";
      flake = false;
    }; 
  };
  outputs = {
    self, nixpkgs, nova-utils, utils, tree-sitter-nix
  }: utils.lib.eachSystem [
    utils.lib.system.x86_64-darwin
    utils.lib.system.aarch64-darwin
  ] (system: let
    # Use the overlays provided by nova-extension-utils
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ nova-utils.overlays.default ];
    };
    # This is example code for building a tree sitter syntax library.
    # The resulting package contains *only* the compiled .so file, not
    # any queries or other things that may be contained in the source tree.
    # See below in `derivationParams` how to include upstream queries in your extension.
    syntax-lib = pkgs.buildNovaTreeSitterLib {
      langName = "myLanguage";
      src = tree-sitter-nix;
    };
  in {
    packages.default = pkgs.buildNovaExtension {
      src = self;
      # These are example values, change them
      pname = "MyExtensionName";
      version = "1.0.0";
      identifier = "org.example.myExtension";
      organization = "Example Corp";
      description = "This is an example Nova extension";
      categories = [ "languages" ];
      # ensure this is what you want!
      license = "MIT";
      # can use any library built via pkgs.buildNovaTreeSitterLib here
      treeSitterLibs = [ syntax-lib ];
      # These parameters override the default mkDerivation parameters.
      # In this example, we add a postInstall script that uses `sed`
      # to modify the injection definition provided by our grammar.
      #
      # I recommend doing this only if changes are minimal. For example,
      # an upstream `highlights.scm` usually needs larger edits to be usable with Nova.
      # You can always manually modify the file, put the result into your repository, and use that.
      derivationParams = {
        nativeBuildInputs = [ pkgs.gnused ];
        postInstall = ''
          ${pkgs.gnused}/bin/sed 's/injection.language "bash"/injection.language "shell"/g' ${tree-sitter-nix}/queries/injections.scm > $extDir/Queries/injections.scm
        '';
      };
      # Values in `config` are put into both the global and the workspace configuration.
      # A `config.js` will be autogenerated that contains the items listed here.
      # The user will be able to set a global value, and override it per workspace.
      config = {
        # This will generate a configuration item with the key 'org.example.myExtension.languageServer'.
        # The prefix is taken from your extension's identifier.
        languageServer = {
          title   = "Language Server";
          type    = "path";
          default = "myLanguageServer";
        };
      };
      main = "main.js";
      entitlements = {
        # required if you use a LanguageServer
        process = true;
      };
    };
  });
}
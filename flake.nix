{
  inputs = {
    utils.url = "github:numtide/flake-utils";
    nova = {
      url = "https://download.panic.com/nova/Nova%2010.3.zip";
      flake = false;
    };
  };
  outputs = { self, utils, nova }: {
    overlays.default = final: prev: {
      buildNovaTreeSitterLib = {
        # name of the language this tree sitter syntax is for
        langName,
        # derivation containing the tree sitter sources
        src,
        # relative path in `src` that contains `parser.c` and possibly `scanner.c`
        srcPath ? "src" }:
        final.stdenvNoCC.mkDerivation {
          name = "nova-tree-sitter-${langName}-dylib";
          inherit src srcPath;
          passthru = { inherit langName; };
          buildPhase = ''
            runHook preBuild
            FRAMEWORKS_PATH="${nova}/Contents/Frameworks/"
            BUILD_FLAGS=( -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 -Isrc -Wall -Wextra )
            LDFLAGS=( ''${BUILD_FLAGS[@]} -F$FRAMEWORKS_PATH -framework SyntaxKit -rpath @loader_path/../Frameworks )
            LINKSHARED=(-dynamiclib -Wl,-install_name,libtree-sitter-${langName}.dylib,-rpath,@executable_path/../Frameworks)
            CPPSRC=()
            SRC=()
            KNOWN_NAMES=(parser scanner)
            for name in "''${KNOWN_NAMES[@]}"; do
              if [[ -f "$srcPath/$name.c" ]]; then
                SRC+=( $name )
              fi
              if [[ -f "$srcPath/$name.cc" ]]; then
                CPPSRC+=( $name )
              fi
            done
            if (( ''${#CPPSRC[@]} )); then
              LDFLAGS+=( -lc++ )
            fi
            OBJ=()
            for f in ''${SRC[@]}; do
              /usr/bin/clang -c ''${BUILD_FLAGS[@]} -o $f.o $srcPath/$f.c
              OBJ+=( $f.o )
            done
            for f in ''${CPPSRC[@]}; do
              /usr/bin/clang -c -lc++ ''${BUILD_FLAGS[@]} -o $f.o $srcPath/$f.cc
              OBJ+=( $f.o )
            done
            /usr/bin/clang ''${LDFLAGS[*]} ''${LINKSHARED[@]} ''${OBJ[*]} -o libtree-sitter-${langName}.dylib
            /usr/bin/codesign -s - libtree-sitter-${langName}.dylib
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            cp libtree-sitter-${langName}.dylib $out
            runHook postInstall
          '';
        };

      buildNovaExtension = {
        # user-facing name of your extension
        name,
        # version of the extension
        version,
        # sources of your extension
        src,
        # extension identifier
        identifier,
        # organization name
        organization,
        # extension description
        description,
        # extension categories
        categories,
        # extension license
        license,
        # derivations built via buildNovaTreeSitterLib
        treeSitterLibs ? [ ],
        # configuration options of your extension
        config ? { },
        # workspace-only configuration options
        configWorkspace ? { },
        # additional parameters to mkDerivation
        derivationParams ? { },
        # additional attributes get put into the extension.json file
        ... }@args:
        let
          genConfigItem = workspace: name: value:
            {
              key = identifier + "." + name;
            } // (if value.type == "section" then
              ((builtins.removeAttrs value [ "children" ]) // {
                children =
                  final.lib.mapAttrsToList genConfigItem value.children;
              })
            else
              (if workspace then
                ((builtins.removeAttrs value [ "default" "required" ]) // {
                  required = false;
                })
              else
                value));
          configJson = final.lib.mapAttrsToList (genConfigItem false) config;
          workspaceConfigJson =
            (final.lib.mapAttrsToList (genConfigItem true) config)
            ++ (final.lib.mapAttrsToList (genConfigItem false) configWorkspace);
          pname = final.lib.strings.sanitizeDerivationName name;
        in final.stdenvNoCC.mkDerivation ({
          inherit src pname version;
          EXTENSION_JSON = builtins.toJSON ((builtins.removeAttrs args [
            "name"
            "treeSitterLibs"
            "config"
            "workspaceConfig"
            "src"
            "derivationParams"
            "config"
            "workspaceConfig"
          ]) // {
            inherit name;
            config = configJson;
            configWorkspace = workspaceConfigJson;
          });
          CONFIG_JS = import ./Scripts/config.nix {
            inherit (final) lib;
            inherit config;
            basePath = identifier;
          };

          installPhase = ''
            runHook preInstall
            extDir=$out/${pname}.novaextension
            mkdir -p $extDir
            shopt -s nullglob
            for f in Syntaxes Scripts Images Themes Completions Queries *.lproj; do
              if [[ -d "$f" ]]; then cp -r "$f" $extDir; fi
            done
            if [[ -f Readme-user.md ]]; then
              cp Readme-user.md $extDir/Readme.md
            elif [[ -f Readme.md ]]; then
              cp Readme.md $extDir/Readme.md
            fi
            cp Changelog.md $extDir/Changelog.md
            shopt -u nullglob
            printenv EXTENSION_JSON >$extDir/extension.json
            mkdir -p $extDir/Syntaxes $extDir/Scripts
            ${final.lib.concatStrings (builtins.map (tsl: ''
              cp ${tsl} $extDir/Syntaxes/libtree-sitter-${tsl.langName}.dylib
            '') treeSitterLibs)}
            ${if builtins.length (builtins.attrValues config) > 0 then ''
              cp ${self}/Scripts/config-item.js $extDir/Scripts
              printenv CONFIG_JS >$extDir/Scripts/config.js
            '' else
              ""}
            cp ${self}/Scripts/{language-server,formatter}.js $extDir/Scripts
            runHook postInstall
          '';
        } // derivationParams);
    };
    templates.default = {
      path = ./template;
      description =
        "A Nova extension with a TreeSitter syntax and a language server";
      welcomeText = ''
        # A Nova extension has been initialized!
        ## First steps

        Edit `flake.nix` to your liking.
        You want to change the tree sitter grammar URL, and all metadata.

        `Scripts/main.js` starts your language server.
        You can of course do other things in there, or remove it if you don't need it.

        `Syntaxes/MyLanguage.xml` should reference your TreeSitter syntax.
        Consult the docs for other data you want to put in there.

        `Queries/highlights.scm` are highlighting queries for your syntax.
        It's empty now.
        Usually existing grammars provide these, but you need to adapt them for Nova.

        ## Testing in Nova

        Once you have set up everything, do a `nix build --impure`.
        You will get a folder `result` containing your extension.
        Open the extension in a new Nova window from the context menu.
        There you can activate your extension.

        Mind that a rebuild will create a different folder (`result` is a symlink) and you need to re-open the testing window after changing stuff.

        ## More Information

        Refer to the [documentation](https://github.com/flyx/nova-extension-utils/blob/master/docs/Documentation.md).
      '';
    };
  };
}

{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-22.05;
    utils.url   = github:numtide/flake-utils;
    nova        = {
      url   = "https://download.panic.com/nova/Nova%2010.zip";
      flake = false;
    };
  };
  outputs = {
    self, nixpkgs, utils, nova
  }: {
    overlays.default = final: prev: {
      buildNovaTreeSitterLib = {
        # name of the language this tree sitter syntax is for
        langName,
        # derivation containing the tree sitter sources
        src,
        # relative path in `src` that contains `parser.c` and possibly `scanner.c`
        srcPath ? "src"
      }@args: final.stdenvNoCC.mkDerivation {
        name = "nova-tree-sitter-${langName}-dylib";
        inherit src srcPath;
        passthru = { inherit langName; };
        buildPhase = ''
          runHook preBuild
          FRAMEWORKS_PATH="${nova}/Contents/Frameworks/"
          BUILD_FLAGS=( -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 -Isrc -Wall -Wextra )
          LDFLAGS=( ''${BUILD_FLAGS[@]} -F$FRAMEWORKS_PATH -framework SyntaxKit -rpath @loader_path/../Frameworks )
          LINKSHARED=(-dynamiclib -Wl,-install_name,libtree-sitter-${langName}.dylib,-rpath,@executable_path/../Frameworks)
          echo cpp
          CPPSRC=()
          SRC=()
          KNOWN_NAMES=(parser scanner)
          for name in "''${KNOWN_NAMES[@]}"; do
            echo infor
            if [[ -f "$srcPath/$name.c" ]]; then
              SRC+=( $name )
            fi
            echo forsrc
            if [[ -f "$srcPath/$name.cc" ]]; then
              CPPSRC+=( $name )
            fi
            echo forcppsrc
          done
          if (( ''${#CPPSRC[@]} )); then
            LDFLAGS+=( -lc++ )
          fi
          echo lc++
          OBJ=()
          echo obj
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
        # name of your extension (without .novaextension)
        pname,
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
        treeSitterLibs ? [],
        # configuration options of your extension
        config ? {},
        # workspace-only configuration options
        workspaceConfig ? {},
        # additional parameters to mkDerivation
        derivationParams ? {},
        # additional attributes get put into the extension.json file
        ...
      }@args: let
        genConfigItem = workspace: name: value: {
          key = identifier + "." + name;
        } // (if value.type == "section" then ((builtins.removeAttrs value [ "children"]) // {
          children = final.lib.mapAttrsToList genConfigItem value.children;
        }) else (if workspace then (builtins.removeAttrs value [ "default" ]) else value));
        configJson = final.lib.mapAttrsToList (genConfigItem false) config;
        workspaceConfigJson = (final.lib.mapAttrsToList (genConfigItem true) config) ++ (final.lib.mapAttrsToList (genConfigItem false) workspaceConfig);
      in final.stdenvNoCC.mkDerivation ({
        inherit src pname version;
        EXTENSION_JSON = builtins.toJSON ((
          builtins.removeAttrs args [
            "pname" "treeSitteLibs" "config" "workspaceConfig"
            "src" "derivationParams" "config" "workspaceConfig"
          ]
        ) // {
          config = configJson;
          workspaceConfig = workspaceConfigJson;
          name = pname;
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
          shopt -u nullglob
          printenv EXTENSION_JSON >$extDir/extension.json
          mkdir -p $extDir/Syntaxes $extDir/Scripts
          ${final.lib.concatStrings (
            builtins.map (tsl: "cp ${tsl} $extDir/Syntaxes/libtree-sitter-${tsl.langName}.dylib\n") treeSitterLibs
          )}
          ${if builtins.length (builtins.attrValues config) > 0 then ''
            cp ${self}/Scripts/config-item.js $extDir/Scripts
            printenv CONFIG_JS >$extDir/Scripts/config.js
          '' else ""}
          cp ${self}/Scripts/language-server.js $extDir/Scripts
          runHook postInstall
        '';
      } // derivationParams);
    };
  };
}
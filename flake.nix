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
      }@args: final.stdenvNoCC.mkDerivation ({
        inherit src pname version;
        CONFIG_JSON = builtins.toJSON ((
          builtins.removeAttrs args [ "pname" "treeSitteLibs" "config" "workspaceConfig" "src" "derivationParams" ]
        ) // {
          inherit config workspaceConfig;
          name = pname;
        });
        
        installPhase = ''
          runHook preInstall
          extDir=$out/${pname}.novaextension
          mkdir -p $extDir
          shopt -s nullglob
          for f in Syntaxes Scripts Images Themes Completions Queries *.lproj; do
            if [[ -d "$f" ]]; then cp -r "$f" $extDir; fi
          done
          shopt -u nullglob
          printenv CONFIG_JSON >$out/${pname}.novaextension/extension.json
          mkdir -p $extDir/Syntaxes
          ${final.lib.concatStrings (
            builtins.map (tsl: "cp ${tsl} $extDir/Syntaxes/libtree-sitter-${tsl.langName}.dylib") treeSitterLibs
          )}
          runHook postInstall
        '';
      } // derivationParams);
    };
  };
}
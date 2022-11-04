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
        buildPhase = ''
          runHook preBuild
          FRAMEWORKS_PATH="${nova}/Contents/Frameworks/"
          BUILD_FLAGS=( -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 -Isrc -Wall -Wextra )
          LDFLAGS=( ${BUILD_FLAGS[@]} -F$FRAMEWORKS_PATH -framework SyntaxKit -rpath @loader_path/../Frameworks )
          LINKSHARED=(-dynamiclib -Wl,-install_name,libtree-sitter-zig.dylib,-rpath,@executable_path/../Frameworks)
          CPPSRC=()
          SRC=()
          for name in (parser scanner); do
            if [[ -f "$srcPath/$name.c" ]]; then
              SRC+=( $name )
            fi
            if [[ -f "$srcPath/$name.cc" ]]; then
              CPPSRC+=( $name )
            fi
          done
          if (( ${#CPPSRC[@]} )); then
            LDFLAGS+=( -lc++ )
          fi
          OBJ=()
          for f in ${SRC[@]}; do
            /usr/bin/clang -c $BUILD_FLAGS -o $f.o $srcPath/$f.c
            OBJ+=( $f.o )
          done
          for f in ${CPPSRC[@]}; do
            /usr/bin/clang -c -lc++ $BUILD_FLAGS -o $f.o $srcPath/$f.cc
            OBJ+=( $f.o )
          done
          /usr/bin/clang $LDFLAGS $LINKSHARED $OBJ -o libtree-sitter-${langName}.dylib
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
        treeSitterLibs ? [],
        # configuration options of your extension
        config ? {},
        # workspace-only configuration options
        workspaceConfig ? {},
        # additional attributes get put into the extension.json file
        ...
      }@args: final.stdenvNoCC.mkDerivation {
        inherit src version;
        CONFIG_JSON = (
          builtins.removeAttrs args [ "treeSitteLibs" "config" "workspaceConfig" "src" ]
        ) // {
          inherit config workspaceConfig;
        };
        
        installPhase = ''
          mkdir -p $out/${name}.novaextension
          cp -r * $out/${name}.novaextension
          printenv CONFIG_JSON >$out/${name}.novaextension/extension.json
        '';
      };
    };
  };
}
# nova-extension-utils

This is a [Nix Flake][1] that provides utilities for building extensions for the [Nova][2] editor:

 * provides a Nix function to compile [Tree Sitter][3] grammars for use with Nova
 * lets you define configuration items that can be set globally while being overridable per workspace
 * provides JS utilities to reduce boilerplate code in your extension concerning language servers and fetching configuration items
 * Nix Flakes allow you to easily depend on external tree sitter grammars without `git submodule` or copying the grammar source.

## Usage

The general workflow for a Nova extension built with nova-extension-utils is as follows:

 * You create a `flake.nix` in your repository and reference `nova-extension-utils` there.
 * In `flake.nix`, you can instruct nix to compile tree sitter grammars (optional).
 * Also in `flake.nix`, you define the contents of your extension's `extension.json`.
 * nova-extension-utils will automatically recognize relevant folders in your repository (`Syntaxes`, `Scripts`, `Images`, …).
   `Readme-user.md` or, if this doesn't exist, `Readme.md`, are copied into the generated extension as Readme file.
 * Via `nix build`, you can build your extension, giving you `result/<name>.novaextension`.
 * For testing, you can open `result/<name>.novaextension` in a separate Nova window and enable it locally from there.
 * Also from there, you can publish your extension.

## Documentation

See [Documentation](docs/Documentation.md).

## License

[MIT](License.md)


 [1]: https://nixos.wiki/wiki/Flakes
 [2]: https://nova.app/
 [3]: https://tree-sitter.github.io/tree-sitter/
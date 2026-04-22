{ pkgs, ... }:

let
  grammars = pkgs.tree-sitter-grammars;
  # luadoc, luap, and vimdoc are not available as standalone packages in
  # nixpkgs tree-sitter-grammars; they are omitted here.

  # grammarToPlugin names the helm parser go_template_helm.so (derived from
  # the Nix package name), but Neovim expects helm.so. The internal symbol
  # is already tree_sitter_helm, so a rename is sufficient.
  helm-parser = pkgs.runCommand "nvim-treesitter-grammar-helm" { } ''
    mkdir -p $out/parser
    ln -s ${pkgs.neovimUtils.grammarToPlugin grammars.tree-sitter-go-template-helm}/parser/go_template_helm.so $out/parser/helm.so
  '';

  treesitter-parsers = pkgs.symlinkJoin {
    name = "neovim-treesitter-parsers";
    paths = [
      helm-parser
    ]
    ++ map (g: pkgs.neovimUtils.grammarToPlugin g) [
      grammars.tree-sitter-bash
      grammars.tree-sitter-c
      grammars.tree-sitter-gitcommit
      grammars.tree-sitter-html
      grammars.tree-sitter-javascript
      grammars.tree-sitter-jsdoc
      grammars.tree-sitter-json
      grammars.tree-sitter-lua
      grammars.tree-sitter-markdown
      grammars.tree-sitter-markdown-inline
      grammars.tree-sitter-python
      grammars.tree-sitter-query
      grammars.tree-sitter-regex
      grammars.tree-sitter-tsx
      grammars.tree-sitter-typescript
      grammars.tree-sitter-vim
      grammars.tree-sitter-yaml
    ];
  };
in
{
  # Only the parser/ directory is symlinked. The queries/ directory from
  # pkgs.tree-sitter-grammars is intentionally excluded: grammar repo queries
  # would shadow Neovim's built-in runtime queries (which are curated by the
  # Neovim team). Highlighting relies on Neovim's bundled queries; textobject
  # queries are shipped by the nvim-treesitter-textobjects plugin itself.
  xdg.dataFile."nvim/site/parser".source = "${treesitter-parsers}/parser";
}

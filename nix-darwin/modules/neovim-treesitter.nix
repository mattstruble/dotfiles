{ pkgs, ... }:

let
  grammars = pkgs.tree-sitter-grammars;
  # luadoc, luap, and vimdoc are not available as standalone packages in
  # nixpkgs tree-sitter-grammars; they are omitted here and will be
  # downloaded and compiled by nvim-treesitter at runtime.
  # helm (tree-sitter-go-template-helm) is also omitted: grammarToPlugin
  # names the parser go_template_helm.so, not helm.so, so it would not be
  # found by nvim-treesitter's helm filetype mapping.
  treesitter-parsers = pkgs.symlinkJoin {
    name = "neovim-treesitter-parsers";
    paths = map (g: pkgs.neovimUtils.grammarToPlugin g) [
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
  # pkgs.tree-sitter-grammars is intentionally excluded: those queries are
  # incompatible with nvim-treesitter's query format and would shadow
  # nvim-treesitter's own bundled queries, breaking highlighting and
  # textobjects. nvim-treesitter manages queries internally.
  xdg.dataFile."nvim/site/parser".source = "${treesitter-parsers}/parser";
}

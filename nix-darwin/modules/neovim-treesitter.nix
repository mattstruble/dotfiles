{ pkgs, ... }:

let
  grammars = pkgs.tree-sitter-grammars;
  # luadoc, luap, and vimdoc are not available as standalone packages in
  # nixpkgs tree-sitter-grammars; they are omitted here.
  # helm (tree-sitter-go-template-helm) is also omitted: grammarToPlugin
  # names the parser go_template_helm.so, not helm.so, so Neovim's helm
  # filetype would not find it.
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
  # pkgs.tree-sitter-grammars is intentionally excluded: grammar repo queries
  # would shadow Neovim's built-in runtime queries (which are curated by the
  # Neovim team). Highlighting relies on Neovim's bundled queries; textobject
  # queries are shipped by the nvim-treesitter-textobjects plugin itself.
  xdg.dataFile."nvim/site/parser".source = "${treesitter-parsers}/parser";
}

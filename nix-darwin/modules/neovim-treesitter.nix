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

  # nixpkgs ships tree-sitter-lua v0.0.19 while upstream is at v0.5.0.
  # Override the source until nixpkgs catches up.
  lua-grammar = grammars.tree-sitter-lua.overrideAttrs {
    version = "0.5.0";
    src = pkgs.fetchFromGitHub {
      owner = "tree-sitter-grammars";
      repo = "tree-sitter-lua";
      rev = "v0.5.0";
      hash = "sha256-VzaaN5pj7jMAb/u1fyyH6XmLI+yJpsTlkwpLReTlFNY=";
    };
  };

  # nixpkgs ships tree-sitter-vim v0.2.0 (2023), but Neovim 0.12's bundled
  # queries/vim/highlights.scm references node types (e.g. "tab") added in
  # later versions. Override the source until nixpkgs catches up.
  vim-grammar = grammars.tree-sitter-vim.overrideAttrs {
    version = "0.8.1";
    src = pkgs.fetchFromGitHub {
      owner = "tree-sitter-grammars";
      repo = "tree-sitter-vim";
      rev = "v0.8.1";
      hash = "sha256-MnLBFuJCJbetcS07fG5fkCwHtf/EcNP+Syf0Gn0K39c=";
    };
  };

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
      lua-grammar
      grammars.tree-sitter-markdown
      grammars.tree-sitter-markdown-inline
      grammars.tree-sitter-python
      grammars.tree-sitter-query
      grammars.tree-sitter-regex
      grammars.tree-sitter-sql
      grammars.tree-sitter-tsx
      grammars.tree-sitter-typescript
      vim-grammar
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

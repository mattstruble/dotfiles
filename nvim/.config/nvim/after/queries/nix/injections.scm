;extends

; Home-manager attributes ending in "Extra" (bashrcExtra, initExtra, profileExtra, etc.)
(binding
  attrpath: (attrpath
    (identifier) @_path)
  expression: [
    (string_expression
      ((string_fragment) @injection.content
        (#set! injection.language "bash")))
    (indented_string_expression
      ((string_fragment) @injection.content
        (#set! injection.language "bash")))
  ]
  (#lua-match? @_path "Extra$")
  (#set! injection.combined))

; Home-manager initContent (programs.zsh.initContent, etc.)
(binding
  attrpath: (attrpath
    (identifier) @_path)
  expression: [
    (string_expression
      ((string_fragment) @injection.content
        (#set! injection.language "bash")))
    (indented_string_expression
      ((string_fragment) @injection.content
        (#set! injection.language "bash")))
  ]
  (#eq? @_path "initContent")
  (#set! injection.combined))

; dag.entryAfter/entryBefore/entryAnywhere (lib.hm.dag.entryAfter ["deps"] ''script'')
(apply_expression
  function: (apply_expression
    function: (_) @_func)
  argument: [
    (string_expression
      ((string_fragment) @injection.content
        (#set! injection.language "bash")))
    (indented_string_expression
      ((string_fragment) @injection.content
        (#set! injection.language "bash")))
  ]
  (#lua-match? @_func "entry%a+$")
  (#set! injection.combined))

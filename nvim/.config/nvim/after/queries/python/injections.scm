;extends

; cursor.execute("...") / connection.execute("...")
; Matches any .execute() method call's first string argument
(call
  function: (attribute
    attribute: (identifier) @_method)
  arguments: (argument_list
    .
    [
      (string
        (string_content) @injection.content)
      (concatenated_string
        (string
          (string_content) @injection.content))
    ])
  (#eq? @_method "execute")
  (#set! injection.language "sql"))

; SQLAlchemy text("...")
(call
  function: (identifier) @_func
  arguments: (argument_list
    .
    [
      (string
        (string_content) @injection.content)
      (concatenated_string
        (string
          (string_content) @injection.content))
    ])
  (#eq? @_func "text")
  (#set! injection.language "sql"))

; Comment tag: # sql
; A string preceded by a comment containing "sql"
(comment) @_comment
.
[
  (expression_statement
    [
      (string
        (string_content) @injection.content)
      (concatenated_string
        (string
          (string_content) @injection.content))
    ])
  (assignment
    right: [
      (string
        (string_content) @injection.content)
      (concatenated_string
        (string
          (string_content) @injection.content))
    ])
]
(#match? @_comment "^#\\s*sql")
(#set! injection.language "sql")

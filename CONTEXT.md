# SQL Beautify

A VSCode extension that formats Hive-dialect SQL. This glossary defines the formatter's domain language.

## Language

**IN list（IN 列表）**:
The parenthesized, comma-separated item list following `IN` or `NOT IN`. An IN list whose items include a `SELECT` is an *IN subquery*, not a plain IN list.
_Avoid_: value list, in-clause items

**IN wrap threshold（IN 换行阈值）**:
The maximum formatted line length beyond which an IN list is wrapped one item per line, block-indented. Zero or negative disables wrapping.
_Avoid_: line limit, max length

**#set 指令（Velocity set directive）**:
A Velocity template assignment directive embedded ahead of a SQL statement, assigning a string literal or a numeric constant to a template variable. Its formatted form is `#set( … )` — lowercase directive name, exactly one space of padding inside the parentheses, no spaces around `=`, no trailing semicolon, one directive per line.
_Avoid_: set statement, variable assignment

# SQL Beautify

A VSCode extension that formats Hive-dialect SQL. This glossary defines the formatter's domain language.

## Language

**IN list（IN 列表）**:
The parenthesized, comma-separated item list following `IN` or `NOT IN`. An IN list whose items include a `SELECT` is an *IN subquery*, not a plain IN list.
_Avoid_: value list, in-clause items

**IN wrap threshold（IN 换行阈值）**:
The maximum formatted line length beyond which an IN list is wrapped one item per line, block-indented. Zero or negative disables wrapping.
_Avoid_: line limit, max length

==TODO list for zerg==

* rename sv_type to zsh_type; zerg_types to lextype?

* Trigger `usage` display on certain errors

* Avoid redundant usage info for negated options

* zsh autocomplete file generation?
probably just add a 'zsh-completion' option to `zerg_add`, used only for this.

* zerg_new should clean up if it dies mid-construction

* Add functions to pack/unpack composites

* Enhance req_zerg_type and is_objname to take specific class as suffix:
`req_zerg_type object.PARSER x`. Rename objname to just "object"?


===Compatibility===

* `zerg_to_argparse`: Include aliases, something for flag options

* finish --version

* finish --nargs REMAINDER

* Allow dcls for positional args? In that case, rename their
parser option items in the parser assoc so they can't collide with plain
names.

* Option to add `choices` to usage output

* Finish support for short option bundling (optional)

* Maybe add `prefix_chars` (e.g. for "+")


===Low priority===

* Support keep-blank-lines for help descriptions

* Implement `ignore-hyphens` parser option

* Add export to zsh case form
For case form, maybe offer to expand matching for abbrs,
like (-h|-he|-hel|-help)....

* Allow changing the negation prefix?

* Support `quoting` setting for `sv_quote` and `aa_export`

* aa-get option to store vs. parse?

* Finish `set_symmdiff`, rest of str functions

* Finish help and doc for [ar_accessors.sh] and [set_accessors.sh]

* Decide which version(s) to use for `is_regex`

* Lose unneeded calls to `aa_get` and `aa_set` (for small speedup)

* Add array-to-assoc conversion

* Potential types:
    * tensor shape support
    * [units] such as for *nix `units` command
    * [glob]
    * [function] -- the name of an existing shell functions
    * [alias]
    * [host] numeric vs. named?
    * [user] numeric vs named
    * [group] numeric vs named
    * xsd types? date portions, pos/neg/nonpos int
    * locale for date types?

* Maybe add `is_path` tests like [ugo][rwx], tests for fifos, whiteouts, etc.

* Add `--format` support?

* Should aa_get offer choice of q/qq/qqq/qqqq and 'quoting'?

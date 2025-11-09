==TODO list for zerg==

* support --version

* Implement --nargs REMAINDER

* `zerg_to_argparse`: Include aliases, something for flag options

* Implement `ignore-hyphens` parser option

* Support keep-blank-lines for help descriptions

* zerg_new should clean up if it dies mid-construction.

* Allow dcls for positional args? In that case, rename all the
parser option items in the parser assoc so they can't collide with plain
names. Maybe start with ^ (to suggest top-level?)

* Sort option to _keys and _values functions

* Support `quoting` setting for `sv_quote` and `aa_export`

* Trigger `usage` display on certain errors

* Avoid redundant usage info for negated options

* Option to add `choices` to usage output

* zsh autocomplete file generation?
probably just add a 'zsh-completion' option to `zerg_add`, used only for this.

* Finish support for short option bundling, and make it optional

* Allow changing the negation prefix?

* Add exports to zsh case form
For case form, maybe offer to expand matching for abbrs,
like (-h|-he|-hel|-help)....

* separate out the ar, set and str support

* Finish `set_symmdiff`, rest of str functions

* Finish help and doc for [ar_accessors.sh] and [set_accessors.sh]

* Decide which version(s) to use for `is_regex`


===Low priority===

* Lose unneeded calls to `aa_get` and `aa_set` (for small speedup)

* Add array-to-assoc conversion

* Maybe just make zerg_type a type named type?

* tensor types, by shape? Model on numpy? To allow
whitespace, require quotingm or maybe add an `narg` keyword
to grab a balanced () group like
    ( (1 2 3) (4 5 6) (7 8 9) )

* Add `--format` support?

* Maybe extend date types to support locale and/or strftime %-strings?

* Maybe add `is_path` tests like [ugo][rwx], tests for fifos, whiteouts, etc.

* Maybe add `parents`, `prefix_chars` (e.g. for "+")

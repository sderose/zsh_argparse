==TODO list for zerg==

* finish --version

* finish --nargs REMAINDER

* Unify type system across sv type, zerg type, and edda class.
    * zerg types are all strings, with regex, some w/ semantics
    * edda class objects are all assocs, with a reserved classname item
    * zsh types are built in
    * rename sv_type to zsh_type; edda_class to zerg_class, zerg_types to lextype?
    * zerg_int vs. sv integer

* Lose all the req_xxx functions?

* Upgrade req_ thing that takes multiple types and test against $*.
varname should be able to distinguish sv_types; maybe varname.svtype?

* `zerg_to_argparse`: Include aliases, something for flag options

* Allow dcls for positional args? In that case, rename all the
parser option items in the parser assoc so they can't collide with plain
names. Maybe start with ^ (to suggest top-level?)

* Sort option to _keys and _values functions

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

* req_arg_types (which probably requires adding varname subtypes, edda type
varname.assoc.PARSER ('varname'->'ref'? 'assoc*'?)

* Ability to store/retrieve qq form

* Implement `ignore-hyphens` parser option

* Support keep-blank-lines for help descriptions

* zerg_new should clean up if it dies mid-construction.

* Packed type for values that should be treated as a typeset dcl on retrieval,
e.g. parsed as a (...) array or assoc, or maybe all the other options too.


===Low priority===

* Support `quoting` setting for `sv_quote` and `aa_export`

* aa-get option to parse and/or store?

* Finish `set_symmdiff`, rest of str functions

* Finish help and doc for [ar_accessors.sh] and [set_accessors.sh]

* Decide which version(s) to use for `is_regex`

* Lose unneeded calls to `aa_get` and `aa_set` (for small speedup)

* Add array-to-assoc conversion

* Maybe just make zerg_type a type named type?

* types: See also [zerg_types.md]. tensor shape support.

* Maybe add `is_path` tests like [ugo][rwx], tests for fifos, whiteouts, etc.

* Add `--format` support?

* Maybe extend date types to support locale and/or strftime %-strings?

* Maybe add `prefix_chars` (e.g. for "+")

* Should int allow like 1E8? Need unsigned?

* Should aa_get offer choice of q/qq/qqq/qqqq and 'quoting'?

* Should the list of sv_types be itself a zerg type?

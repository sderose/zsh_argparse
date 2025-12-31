==TODO list for zerg==

===Known bugs and limitations===

* Finish `--version`

* Finish `--nargs REMAINDER`

* Finish support for short option bundling (optional)

* Allow dcls for positional args? In that case, rename their parser option
items in the parser assoc so they can't collide with plain names.

* Maybe add `prefix_chars` (e.g. for "+")

* You can't have an option with refname "results" if you're using
`--var-style` assoc for that parser.

* Need a way to give options to (some) types with `--type`. Perhaps:
like `zerg_add --type 'path -r -e'` so you just unbundle the tokens when
calling `is_path` (or whatever). Code to parse/store, but not use, is in.


===Features===

* Add capability to give any number of argname:typename=defaultval items
at once on zerg_new!!! See [zerg_compact.sh].
    parser_new MYPARSER -- \
    'quiet|q:store_true[Reduce messages]' \
    'format:choice(xml,json,yaml)[Output format]' \
    'out:path=foo.log[Where to write results]'

* Option to (not) add `choices` to usage output

* Finish extras/.

* Document `zerg_add` option abbrevs.

* Integrate `zerg_use` into compact -- maybe just @PAR__ref? Or is
it enough to just use `--parent`? Does `zerg-use` allow multiple?

* Avoid redundant usage info for negated options

* Add a clean wat to specify is_xxx options with `zerg_add --type`.

* Trigger `usage` display on certain errors

* zsh autocomplete file generation?
probably just add a `zsh-completion` option to `zerg_add`, used only for this.

* Finish type `packed`???
    * perhaps interconvert w/ varname (shoulds varname self-label? =*name?
    * anything special for object definitions?


===Low priority===

* Should `zerg_actions_re` accept [-_] just to be forgiving?

* Option to exclude parent parser(s) from option list.
Or show as a single msg such as "Also supports the options of xxx."

* Should aa provide a way to find all key(s) matching a given value?

* 'toggle' uses +x for short opts, so `is_argname` allows it.

* Check parser compatibility with `zerg_parent`: add_help, case, ....

* `zerg_new` should clean up if it dies mid-construction.

* Add `parser_new` option to set result dict name?

* Make zerg functions use zerg for options, mainly to get abbrevs?

* Add option to pick which form to accept for `is_lang`. Perhaps also
check specific codes (or add types for ISO language and country codes)

* Check specific codes for `is_lang`? Add type for country, script?
Could do as below (though Language only seems to know the 2-letter forms):
    perl -e 'use Locale::Country; print code2country("US");'
    perl -e 'use Locale::Language; print code2language("EN");'
    perl -e 'use Locale::Script; print code2script("latn");'

* Implement `ignore-hyphens` parser option?

* Add `aa_export` option for getting to zsh case-statement format.
For that, maybe offer to expand matching for abbrs,
like (-h|-he|-hel|-help)....

* Allow changing the negation prefix?

* Support `quoting` setting for `zsh_quote` and `aa_export`

* Should `aa_get` offer choice of q/qq/qqq/qqqq and 'quoting'?

* `aa-get` option to store vs. just parse?

* Decide which version(s) to use for `is_regex`

* Lose unneeded calls to `aa_get` and `aa_set` (for small speedup)

* Add array-to-assoc conversion

* Potential types:
    * [glob]
    * [host] numeric vs. named?
    * [user] numeric vs named
    * [group] numeric vs named
    * date portions
    * pos/neg/nonpos int?

* Maybe add `is_path` tests like [ugo][rwx], tests for fifos, whiteouts, etc.

* Add `--format` support? Integrate wth typeset

* Check whether Linux uses en_GB.ISO8859-1 or en_GB.ISO-8859-1.

* Should `is_float` make nan/inf optional?

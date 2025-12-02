==TODO list for zerg==

===Known bugs and limitations===

* find_key broken

* `action=count` doesn't.

* Finish `--version`

* Option to add `choices` to usage output

* Finish `--nargs REMAINDER`

* Finish support for short option bundling (optional)

* Allow dcls for positional args? In that case, rename their parser option
items in the parser assoc so they can't collide with plain names.

* Maybe add `prefix_chars` (e.g. for "+")

* Finish help and doc for extras.


===Features===

* Integrate zerg_use into compact -- maybe just @PAR__ref? Or is
it enough to just use --parent? Does zerg-use allow multiple?

* Add capability to give any number of argname:typename=defaultval items
at once on zerg_new!!! See [zerg_compact.sh].
    parser_new MYPARSER -- \
    'quiet|q:store_true[Reduce messages]' \
    'format:choice(xml,json,yaml)[Output format]' \
    'out:path=foo.log[Where to write results]'

* Rename `sv_type` to `zsh_type`?

* Avoid redundant usage info for negated options

* Trigger `usage` display on certain errors

* zsh autocomplete file generation?
probably just add a `zsh-completion` option to `zerg_add`, used only for this.

* Enhance `req_zerg_type` and `is_objname` to take specific class as suffix:
`req_zerg_type object.PARSER x`. Rename `objname` to just `object`?

* Finish type `packed`???
    * perhaps interconvert w/ varname (shoulds varname self-label? =*name?
    * anything special for object definitions?

* Is there value in providing persistent vars? How best to i/f? Meh.
Store as packed in, say ~/.zsh_globals. Copy to env at startup is easy,
but update seems not.


===Low priority===

* Rename 'tMsg' to 'warn'? make trace controllable?

* Should zerg_actions_re accept [-_] just to be forgiving?
--type store_true vs. --store-true....

* Option to exclude parent parser(s) from option list.
Or show as a single msg such as "Also supports the options of xxx."

* Switch is_argname to allow -q and also --?

* Should aa provide a way to find key(s) with given value?

* 'toggle' uses +x for short opts, so `is_argname` allows it.

* check parser compatibility with `zerg_parent`: add_help, case, ....

* `zerg_new` should clean up if it dies mid-construction

* Add `parser_new` option to set result dict name?

* Add option to pick which form to accept for `is_lang`. Perhaps also
check specific codes (or add types for ISO language and country codes)

* Make zerg use itself, mainly to get abbrevs.

* Check specific codes for `is_lang`? Add type for country, script?
Could do as below (though Language only seems to know the 2-letter forms):
    perl -e 'use Locale::Country; print code2country("US");'
    perl -e 'use Locale::Language; print code2language("EN");'
    perl -e 'use Locale::Script; print code2script("latn");'

* Implement `ignore-hyphens` parser option

* Add export to zsh case-statement form
For case form, maybe offer to expand matching for abbrs,
like (-h|-he|-hel|-help)....

* Allow changing the negation prefix?

* Support `quoting` setting for `sv_quote` and `aa_export`

* `aa-get` option to store vs. just parse?

* Decide which version(s) to use for `is_regex`

* Lose unneeded calls to `aa_get` and `aa_set` (for small speedup)

* Add array-to-assoc conversion

* Potential types:
    * Finish tensor shape support
    * [units] such as for *nix `units` command
    * [glob]
    * [host] numeric vs. named?
    * [user] numeric vs named
    * [group] numeric vs named
    * date portions, pos/neg/nonpos int?

* Maybe add `is_path` tests like [ugo][rwx], tests for fifos, whiteouts, etc.

* Add `--format` support? Integrate wth typeset

* Should aa_get offer choice of q/qq/qqq/qqqq and 'quoting'?

==TODO list for zerg==

===Known bugs and limitations===

* 'count' isn't.

* `zerg_to_argparse`: generate something for 'toggle' options

    add_argument("--ignore-case", "--ic", action="store_true",...)
    add_argument("--no-ignore-case", "--no-ic", action="store_falsee", dest=...)

* Finish --version

* Option to add `choices` to usage output

* Finish --nargs REMAINDER

* Finish support for short option bundling (optional)

* Allow dcls for positional args? In that case, rename their
parser option items in the parser assoc so they can't collide with plain
names.

* Finish `set_symmdiff`, rest of str functions

* Finish help and doc for [ar_accessors.sh] and [set_accessors.sh]

* Maybe add `prefix_chars` (e.g. for "+")


===Features===

* Add capability to give any number of argname:typename=defaultval items
at once on zerg_new!!! See zerg_compact.sh.
    parser_new MYPARSER -- \
    'quiet|q:store_true[Reduce messages]' \
    'format:choice(xml,json,yaml)[Output format]' \
    'out:path=foo.log[Where to write results]'

* Rename sv_type to zsh_type; zerg_types to lextype?

* Avoid redundant usage info for negated options

* Trigger `usage` display on certain errors

* zsh autocomplete file generation?
probably just add a 'zsh-completion' option to `zerg_add`, used only for this.

* Enhance req_zerg_type and is_objname to take specific class as suffix:
`req_zerg_type object.PARSER x`. Rename objname to just "object"?

* Finish type `packed`???

    * be able to pack an array or assoc into a string, and store that.
    * give easy way to unpack it back out into a variable.
    * perhaps same thing for int/float, so they know what they are
    * perhaps same thing for a varname, so it knows.
    * with object definitions, type could be known.
    * should there be a type-indicator prefix? what type(s)?
    * if a prefix, should it support the whole range of typeset stuff?
        Scope: local, global -g, export -x
        Type: int -i, float -F, array -a, assoc -A, undef, scalar, unique -U
        Final: readonly -r
        Visibility: hidden -H, hide/unspecial -h, hideval ?
        Display: base -in, exponential -En, signif digits -Fn,
                Justify: left -Ln, right_blanks -Rn, right_zeros -Zn
                lower -l, upper -u
        special, tag, unique
    * but what about just scalars? does packed


===Low priority===

* zerg_new should clean up if it dies mid-construction

* Add parser_new option to set result_dict name?

* Add option to pick which form to accept for is_lang. Perhaps also
check specific codes (or add types for ISO language and country codes)

* Check specific codes for is_lang? If Perl is around you can do as
below (though language, at least, only seems to know the 2-letter forms):
    perl -e 'use Locale::Country; print code2country("US");'
    perl -e 'use Locale::Language; print code2language("EN");'
    perl -e 'use Locale::Script; print code2script("latn");'

* Implement `ignore-hyphens` parser option

* Add export to zsh case-statement form
For case form, maybe offer to expand matching for abbrs,
like (-h|-he|-hel|-help)....

* Allow changing the negation prefix?

* Support `quoting` setting for `sv_quote` and `aa_export`

* aa-get option to store vs. just parse?

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
    * locale for date types?

* Maybe add `is_path` tests like [ugo][rwx], tests for fifos, whiteouts, etc.

* Add `--format` support? Integrate wth typeset

* Should aa_get offer choice of q/qq/qqq/qqqq and 'quoting'?

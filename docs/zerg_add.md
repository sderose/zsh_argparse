==Help for zerg_add.sh==

(part of the zsh_argparse library)

`zerg_add` is pretty closely modeled on
Python argparse [https://docs.python.org/3/library/argparse.html].
But the syntax, set of types, and so on are changed to fit zsh.

For example, here are a few typical uses (there is a more compact syntax
that allows you to add multiple simple options on the `parser_new` command.
See [zerg_compact.md] for details.


```
    source zerg_setup.zsh
    zerg_new OPTS --case-ignore
    ...
    zerg_add OPTS "--maxChar" --type int --default 65535 \
        --help "When displaying code points, skip any above this."
    zerg_add OPTS "---verbose -v" --action COUNT \
        --help "How verbose should I be? Repeatable."
    zerg_add OPTS "--quiet --silent -q" --action store_true \
        --help "Suppress most messages."
```

OPTS stands for the name of a zsh associative array where you want
the option definitions stored, somewhat like an Python argparse instance.

The next item gives at least one name for the option being defined.
In Python this could be several arguments. In zsh_argparser put all the
synonyms in one string, separate by whitespace. The first one listed
is the main or "reference" name.

This is also the key under which the option's value is stored when an associative
array of options is returned by parse_args, unless you say otherwise via
--destination. Additional synonyms for the options can be added, but they
need to go at the end, after any other of the options described next.

After the reference name come options (almost entirely) corresponding
to the keyword arguments of Python `argparse.add_argument`.

After all the options have been defined, use parse_args on the
command line arguments (typically `$*` or `$@` within a function),
and the resulting values will end up in an associative array called OPTS (or an error message will
be displayed and the script will stop):

```
    parse_args OPTS $@
```

==Treatment of re-definitions==

If you try to add an argument that is already defined in the specific parser,
the effect depends on the `--on-redefine` option on that parser.
See the help for `zerg_new` for details. The default is to quietly overwrite
any prior definition (whether it was done earlier within the same invocation
of the same shell function, in a prior invocation, or in a different function).


==Options for `zerg_add`==

The first 2 arguments to `zerg_add` are not really options. They must always
be:
    * The name of the parser (created by `zerg_new`) that owns the option; and
    * A space-separated list of names for the option.

```
    zerg_add OPTS "--verbose -v" --action count
```

By default, zerg parsers ignore case for option names. So
any of these (and many others) could be used to specify the option whose
reference name is "verbose" (assuming there are no
conflicting options, such as `--verify` which would rule out abbreviations
shorter than `--veri`):

    -v --ve --ver --VeR --VER --verify

The first name given in the list, is called the "reference" name,
and is the name under which a result value
is stored. However, you can choose a different key by setting `--destination`.

The most important options to `zerg_add` are `action`, `type`, `help`, and `default`,
which are discussed next. Other options follow them, in alphabetical order.

===zerg_add --action===

`--action` determines whether another token is read (from right after the option
name on the command line), and in either case, what to store or do.

Action names are lower-case with underscores, such as "store_true".
However, there is also shorthand: instead of `--action store_true`
you can just say `--store-true`. In that case, be careful to change
any internal underscores to hyphens, as are typical in option names.
Each action name except `help` is available as its own option this way.
`help` is *not* a shorthand for `--action help`, because that option name
is already taken (for specifying an option's help text).

The actions are mostly the same as for Python argparse. The first ones listed
are cases where no separate value follows the option name itself:

* `store_const` -- sets the option's value to that of the `--const`
option (which should also be specified on the same zerg_add call).

* `store_true` -- sets the option's value to 1.

* `store_false` -- sets the option's value to "" (zsh false).

* `toggle` -- for when you want
a flag option to turn something on and also a negated version to turn it off,
such as `--ignore-case` and `--no-ignore-case`.
Use add_arg with the non-negated name, and `--action TOGGLE` will ensure
that the negated options is also defined.
Use `--default` to set the initial value. `TOGGLE` does this in one step,
assuring that the negation prefix is consistent, that pairs share the same
`destination` variable, `help` text, `default`, etc.
 This is not present in Python argparse (well, not the standard one.
 Unsurprisingly, I have a subclass...).

* `count` -- increments the option's value (or sets it to one if it
does not yet exist). Typically used for *nix `-v` (verbosity) options.

* `help` -- specifies that this is the option to request help.
Typically used for `-h` and `--help`).
NOTE: Unlike other actions, this cannot be shorted from
`--action help` to `--help`, because there is already a `--help`
option that does something else.

* `version` -- specifies that this is the option to report that command's
version number (typically set for `--version`).

The following actions are for cases where the option requires a following value
(unlike the above):

* `store` -- this is the default action, which just stores the value expressed by
the token after the option name on the command line being parsed.
Often in this case you'll also specify `--type` (see next section).

* `append` -- adds the following value to the end of the option's value.
Ideally they would be an array, but in zsh, the members of an associative
array cannot be arrays of any kind. So instead, the value will be returned
as simply a space-separated string.

TODO: It is likely this behavior will be improved by putting the string in the
form `typeset -a` accepts for arrays so it is trivial to convert it to
an actual zsh array by passing it to `typeset` (see also [zerg_types.sh] and
the `packed` types).

* `append_const` -- like `append` but adds the value of `--const` instead of
taking the next token from the command line being parsed.

* `extend` -- like `append` but for multiple following tokens (see `nargs`).
I anticipate this just being the same as `append`, with both handling `nargs`.


===zerg_add --type===

`--type [name]` says what datatype the parsed value should be.
These are *not* the zsh types (array, assoc, etc.), but cover a much wider range
(though you can add your own in Python more easily than here).
For example, there are types for dates and times, identifiers, urls, paths,
integers in different bases,
variable names, command names, pids, etc.
zsh groups Most things under "scalar" (or "string").
By distinguishing them here zsh_argparse can provide much more thorough
value checking for what actually appears on command lines.

The type names are listed in as assoc named `\$zerg_types`, which is
defined in [zerg_setup.sh].
Each type also has a tester named "is_" plus the type name,
defined in [parse_args.sh]. A few of the testers have options, for example
enabling `is_path` to test permissions and `is_tensor` to check shapes.

When a value doesn't fit the type, a message is also printed
unless you gave the `-q` option (spelled only as -q or --quiet, sorry).

Note: zerg include [/lib/utils/zerg_types.py], which can be imported or
harvested for use in Python code. It provides a function named to match
each zerg type, which can be passed to Python `argparse.add_argument`'s
`type` parameter in the usual fashion. Some support options (see below for
the zerg equivalent), and Python lambda or partials can be used for those.

===Type-checkers===

Each zerg type has a corresponding shell function
that returns 0 if the value passed fits the datatype, or 1 if not.
For example:

```
    if is_int "$foo"; then...
    [[ is_tensor --shape "2 3" "( (-1 2 3) (4 5 6.02214076E+23) )" ]] || exit 99
```

Do not confuse *zerg* types with the built-in *zsh* types as set via `typeset`.
zsh knows `undef`, `scalar`, `integer`, `float`, `array`, and `assoc` (plus
many modifiers such as global/local, hidden, and so on).
zerg provides function to help with those:
`zsh_type [var-name]` returns one the applicable one of those 6 zsh types.
`is_of_zsh_type [type-name] [var-name]` tests whether the variable is of
the given type ("undef" can be tested just fine), and fails or succeeds.

There is no `zerg_type` function, because a given string might fit many types.
For example, "1" can be int, float, complex, or prob (not to mention
path, alias, pid, str, etc.).
zsh types are types of variables per se, as determined by `typeset`;
zerg types are about how strings (especially option values in command lines)
can be interpreted.

====Using type-checker options with --type====

A few type-checkers support sub-types or options. For example, `is_path` has
options that require the path to point to an existing file or directory, to an
object with certain permissions, etc. When testing a string via a type-checking
function, options are passed in the usual zsh fashion:
    is_path -d "$myPath" || return 99

To get this effect when defining an argument, just quote the options together
with the type name, like:

    zerg_add MYPARSER "--src-dir" --type "path -d"

Note: This syntax is parsed and accepted by `zerg_add`, but not yet
supported when parsing actual command lines with `zerg_parse`. It should
be added soon.

===Type Shorthand===

As with actions, argument types can be specified as options under their own name,
not just as values for `--type`. However, this is not allowed if you need
options to the type-checker (see above). For example, to require an
option's value to be an integer in any of decimal ("65"), octal ("0o101"),
hexadecimal ("0x0041"), use either of these:

```
    --type anyint
    --anyint
```

===Command-line syntax vs. internal datatype===

`--type` mainly constrains the string values given in actual
command lines when they are parsed. It has little to do with how the values
are stored in zsh. The values are stored unchanged, as zsh scalars/strings.
Thus, if an anyint option's value was entered as "0x41", that is what is
stored. If a string like "0x41" is in a variable `X`, get
the integer equivalent via `$((x))`.

One exception is that an argument definition can specify `--fold [upper|lower|none]` to cause the argument's value from the command line to
be case-folded before storage.


===zerg_add --help===

This provides a help string describing the option. Programs can display
it when you request help, use it to compose documentation, etc.

===zerg_add --default===

This provides a value for the option, if the option isn't specified at all in
a particular command line.


=Other options to add_argument=

As noted above, all of the actions and type values can be given as options to
`zerg_add` on their own, rather than as values for `--action` or `--type`.
This is purely for convenience, and they are not listed below.

[TODO Review the list below, a few are wrong or obsolete]

===zerg_add --flag===

This is just shorthand for `--type bool --action store_true`.

===zerg_add --required (or -r)===

This takes no value, and merely specifies that the given option
must always be provided.

===zerg_add --choices [idents] (or -c)===

This takes a string of space-separated tokens, from among which the option's
value must be selected. If `--ignore-case-choices` was set on the owning
parser, matching these values will
ignore case, though the value stored will be as given (not folded).
This is separate from the `--ignore-case-options` setting; both apply
to all of a parser's options, not particular ones.

===zerg_add --nargs [int]===

The number of following tokens to be consumed for the value.
This defaults to 0 or 1 depending on `--action`.
It also accepts other unsigned integer values, "*", "+", "?".
It does *not* (yet) support "REMAINDER" to take all remaining arguments.

===zerg_add --const [value] (or -k)===

A value to be stored when the action is `store_const` or `append_const`.

===zerg_add --dest [varname] (or -v)===

The name under which to store the option value. If not specified, the
option's reference name (the first value given in `refname`, but not including
leading hyphens, and with internal hyphens changed to underscores) is used.

===zerg_add --fold [lower|upper|none]===

Whether to convert the *value* to uniform case before storing.
Not to be confused with the zerg *parser* options `--ignore-case-options`
(for how option names themselves are matched)
and and `--ignore-case-choices` (for how values of `choices` arguments are matched).

===zerg_add --format [pct-string]===

This lets you specify a printf-style % code which may be used to display
the value, should the occasion arise.

===zerg_add --pattern [regex]===

This takes a zsh-style regular expression that the option value must match.
The match is checked using zsh's `=~` operator, and does not require
matching the *complete* value unless you include ^ and $ in the regex.

==Storage==

Each argument definition gets its own associative array, named
by the parser that defined it, "__", and the reference name of the argument.
For example, `MYPARSE__quiet`.  The parser's `export` option determines whether
these variables are local or exported; they are normally hidden.

The fields/items in that assoc may include those shown below (most of which
are the same as for Python `argparse.add_argument`).
Items with empty values may be omitted.

* `\uEDDA_CLASS` -- (the first character is U+EDDA) -- this
key is used to self-identify the assoc as an instance of a zerg object class,
in this case named "ZERG_ARG_DEF".
The key is availab le in `$ZERG_CLASS_KEY`, set in [zerg_objects.sh].
* `arg_names` -- the list of space-separated names for the argument.
* `action` -- a choice from `$zerg_actions` (see [zerg_add.md]).
* `choices` -- (since zsh cannot store arrays as data in assocs, the choices
are stored as a string of space-separated tokens)
* `const` -- a value to be stored by `store_const`, `append_const`, etc.
* default -- the value to store in the destination, if the option is
not explicitly specified.
* `dest` -- a name under which to store the option value. By default,
the destination name is derived from the option's reference name by
`zerg_opt_to_var` (from [zerg_setup.sh]), which removes leading hyphens
and converts internal hyphens to underscores.
* `fold` -- whether the value should be folded on reading (none, lower, or upper)
* `format` -- a printf-style % code fro the items preferred output format
* `help` -- a short description of the option
* `nargs` -- how many tokens to grab following the option name.
* `pattern` -- a regex that the argument's value must match.
* `required` -- this option must akways be specified.
* `type` -- a choice from `$zerg_types` (see [zerg_types.md].

==Help for add_argument.sh==

(part of the zsh_argparse library)

`add_argument` is pretty closely modeled on
Python argparse [https://docs.python.org/3/library/argparse.html].
But the syntax, set of types, and so on are changed to fit zsh.

For example, here are a few typical uses:

```
    source parser_args.sh
    ...
    add_argument OPTS "--maxChar" --type int --default 65535 \
        --help "When displaying code points, skip any above this."
    add_argument OPTS "---verbose -v" --action COUNT \
        --help "How verbose should I be? Repeatable."
    add_argument OPTS "--quiet --silent -q" --action store_true \
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
to the keyword arguments of Python argparse.add_argument.

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


==Options for `add_argument`==

The most important options are probably `action`, `type`, `help`, and `default`.
These and others are discussed below in alphabetical order.

===add_argument --action===

`--action` determines whether another token is read (from right after the option
name on the command line), and in either case, what to store or do.

Action names are lower-case with underscores. However, there is also shorthand.
Each action name is available as its own option, but
in lower-case and with hyphen separators instead of underscores.
So instead of `--action store_true` you can just say `--store-true` (note the
hyphen vs. underscore; a difference also familiar from Python argparse).

The actions are mostly the same as for Python argparse. The first ones listed
are cases where no separate value follows the option name itself:

* `store` -- this is the default action, and simply stores the following
token (or tokens, if `nargs` is involved).

* `store_const` -- sets the option's value to that of the `--const`
option (which should also be specified on the same add_argument call).

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
an actual zsh array by passing it to `typeset`; or possibly to use zsh's "paired"
feature to create a parallel string and array.

* `append_const` -- like `append` but adds the value of `--const` instead of
taking the next token from the command line being parsed.

* `extend` -- like `append` but for multiple following tokens (see `nargs`).
I anticipate this just being the same as `append`, with both handling `nargs`.


===add_argument --type===

`--type [name]` says what datatype the parsed value should be.
These are *not* just the zsh types, but cover a much wider range.
For example, there are types for dates and times, identifiers, urls, paths,
and so on -- even though zsh would group all those under "scalar" (or "string").
By distinguishing them here zsh_argparse can provide much more thorough
value checking (again like Python argparse).

There are more types provided than Python argparse provides (though you can
add your own there, more easily than here).
The specific argument type are described in [bootstrap_defs.md].

The type names are in `\$zerg_types`, which is defined in [zerg_setup.sh].
Each type also has a tester named "is_" plus the type name,
defined in [parse_args.sh] (because checking strings against the declared type
is part of parsing command lines).

Like actions, argument types can be specified as options under their own name,
not just as values for `--type`. For example, to require an option's
value to be an integer in any of decimal ("65"), octal ("0o101"),
hexadecimal ("0x0041"), use either of these:

```
    --type anyint
    --anyint
```

Recall that `--type` just constrains the string values given in actual
command lines when they are parsed. It has little to do with how the values
are stored in zsh. The values are stored unchanged, as zsh scalars/strings.
Thus, if an anyint option's value was entered as "0x41", that's what's
stored -- not the equivalent zsh integer value like `typeset -i x=65`.

TODO: I may add a `--destination-type` argument to enable casting in such
cases, but that has at least 2 problems: zsh associative arrays such as
what parse_args creates, cannot store non-string values; and some usages
may want to use the distinctions, such as allowing either hex or decimal values
for a given option, but treating them somehow differently (such as
printing some output in the same base that was used for the option).

Each argument type also has a corresponding shell function that returns 0 if the
value passed fits the datatype, or 1 if not. For example, you can say

```
    if is_int "$foo"; then...
```

When a value doesn't fit the type, a message is also printed
unless you gave the `-q` option (spelled only that way, sorry).

Do not confused this with the `sv_type` function, which returns the actual
zsh base type of a given shell variable, as determined by `typeset`.
"sv" in the function name is short for "shell variable",
since of course this function is not limited to associative arrays ("aa").
The value returned by `sv_type` is one of `undef`, `scalar`, `integer`, `float`, array, assoc -- which are zsh `typeset` types, not patterns for expressing
other types in command lines.


==add_argument --help==

This just provides a help string describing the option. Programs can display
it when you request help, or use it to compose rudimentary documentation, etc.


==add_argument --default==

This provides a value for the option, if the option isn't specified at all in
a particular command line.


==Other options to add_argu,ent==

As noted, all of the actions and type values can be given as options to
add_argument on their own, rather than as values for `--action` or `--type`.
This is purely for convenience, and they are not listed below.

[TODO Review the list below, a few are wrong or obsolete]

==add_argument refname==

(TODO not really an option (no "--"). A space-separated list of
names for the option. parse_args be default ignores case, ignores internal
underscores and hyphens, and accepts unique abbreviations. So given

```
    add_argument OPTS "--verbose -v" --action count
```

All of these (and many others) would be matched (assuming there are no
conflicting options such as `--verify`, which would rule out abbreviations
shorter than `--veri`):

    -v --ve --ver --VeR --VER --verify

The first name given in the list, is considered the "reference" name,
and is the key under which the result (or the value from `--default`)
is store. However, you can choose a different key by using `--destination`,
like in Python argparse.

==add_argument --reset==

==add_argument --flag==

TODO Check?

==add_argument --required (or -r)==

This takes no value, and merely specifies that the given option
must always be provided.

==add_argument --choices [idents] (or -c)==

This takes a string of (space-separated) tokens, from among which the option's
value must be selected. If `--fold` (see below) is also set, matching will
ignore case, though the value stored will be as given (not folded).

==add_argument --nargs [int]==

The number of following tokens to be consumed for the value.
This almost always defaults to 0 or 1 depending on `--action`.
It also accepts "remainder" to take all remaining arguments.

==add_argument --const [value] (or -k)==

A value to be stored when the action is `store_const` or `append_const`.

==add_argument --dest [varname] (or -v)==

The name under which to store the option value. If not specified, the
option's reference name (the first value given in `refname`, but not including
leading hyphens) is used.

==add_argument --fold [lower|upper|none]==

Whether to convert the value to uniform case before storing.
Not to be confused with the zerg *parser* options --ignore-case
and --ignore-case-enums, which control how option names themselves
and the value of `choices` arguments, are matched.

TODO: Update code and doc to support this.

TODO: Consider Unicode normalization and whitespace normalization, too.

==add_argument --format [pct-string]==

This lets you specify a printf-style % code which should be used to display
the value, should the occasion arise.

TODO: Finish

==add_argument --pattern [regex]==

This takes a zsh-style regular expression that the option value must match.

TODO: Basic, extended, or PCRE? Or choice? Or zsh setting?


==Storage==

Each argument definition gets its own exported associative array, named
by the parser that defined it, "__", and the reference name of the argument.
For example, `MYPARSE__quiet`.

The fields/items in that assoc may include those shown below (most of which
are the same as for Python `argparse.add_argument`):

* arg_names -- the list of space-separated names for the argument.
* action --
* choices -- (since zsh cannot store arrays as data in assocs, the choices
are stored as a string of space-separated tokens)
* const --
* default --
* dest --
* fold -- whether the value should be folded on reading (none, lower, or upper)
* format -- a printf-style % code fro the items preferred output format
* help --
* nargs --
* pattern -- a regex that the argument's value must match.
* required --
* type -- see zerg_types.

Items with empty values may be omitted.

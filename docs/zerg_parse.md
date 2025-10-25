=Information on zsh zerg_parse=

This is part of `zerg`, a zsh version of Python `argparse' library.
It helps with defining and parsing command line options for zsh functions.

This gives several benefits:

* Options are recognized even if abbreviated
* Alternate names / aliases can be defined
* Option values can be checked against a chosen type, including
dates and times, probabilities, identifiers, urls, and other handy things
* Options can each provide a help string
* The declarations are easy to read and write (even more so if you
already know Python `argparse`)

==Usage==

In your [.zprofile] or other setup file, do:

```
    source zerg_setup.sh
```

In a given shell function, create a zerg parser to store the argument
definitions (this is roughly like Python's `argparse` object):

```
    zerg_new PAR  --ignore-case-option --no-ignore-case-enum --enum-abbrevs $@
```

This will create a zsh associative array with relevant data.

Then add the desired options using `zerg_add`, giving the name of the parser
you're adding to, one or more names for the particular argument (the first name
given, minus leading hyphens, is considered the main or "reference" name, and
the others aliases to it), and options that specify how the argument operates.
The options are extremely similar to those of Python argparse, but of course
specified with zsh "--" syntax. For example:

```
    zerg_add PAR "--verbose -v" --action count
    zerg_add PAR "--encoding" --choices "UTF-8 CP1252 ASCII"
        --default "UTF-8" --help "Input character set to assume."
    zerg_add PAR "--source" --type url
    zerg_add PAR "--timeout" --type duration --default "10s"
```

Then use `zerg_parse` to actually parse the command line:

```
    zerg_parse PAR "$@"
```

This will parse the arguments that were passed to the zsh shell function.
In case of errors, an appropriate message will be displayed and the
shell function will exit.

If parsing is successful, the option values (including any
defaulted ones) are stored. You can choose whether they are stored as
individual variables, or as items in an associative array.
Each is stored under
the correct option reference name (or `destination` if specified),
regardless of whether the command line abbreviated it or used different
case (assuming `ignore-case-option` is in effect.

For lists created with actions such as APPEND, an actual zsh list
cannot be stored as an item in a zsh associative array, so the
members are placed end-to-end, separated by spaces.

Having parsed, the options can be used simply used, like:

    if [[ OPTS[verbose] -gt 2 ]]; then...

==Differences from Python argparse

* The syntax. Mainly, Python uses keyword arguments like `name=value`
in function calls, while uses shell option conventions like
`--name value`. The parser object's name is the first argument to
zerg functions, rather than being prefixed to the function with "."
as in Python.

* Zerg functions are not "owned" by a class or object, so they
are distinguished by a relevant names prefix, such as "zerg_"
for argument parser functions, `aa_` for functions that help
with associative arrays, `sv_` for general shell variable helpers, etc. They can be used apart from zerg.
For example, you can use `aa_keys name` on any zsh associative
array, much like `${(k)name}` (and you don't need `(P)` when
the name is itself in a variable).

* Types and actions can use their values as shorthand options.
For example, `--count` is a synonym for `--action count`. Most
names are unchange, but a few are shortened to be more zsh-like,
such as just `zerg_add` instead of `zerg_add_argument`.

* There are extra types in zerg (though you can add your own
easily in Python). These determine what can be typed in
as values for particular options, rather than being what the
argument is necessarily cast to (since zsh has few built-in
types and no simple way to create new ones).

* Python `argparse.ArgumentParser` has `parents`, `formatter_class`,
`prefix_chars`, `fromfile_prefix_chars`, `argument_default`,
`conflict_handler`, `add_help`, and `exit_on_error`, which zerg lacks.
Likewise features Python described under "Other utilities".

* Python `add_argument` uses separate positional arguments for
aliases, while `zerg_add` packs them into one space-separated string,
like "--quiet -q --silent".

* `zerg_use` lets you re-use prior definitions (so long as they're
still around in the environment), while a `--on-redefinition` option
to `zerg_new` lets you determine what happens if you try to redefine
already-existing parsers or arguments.

* In zerg, option names are less flexible. They must begin with
a digit, and then continue with only alphanumerics and hyphens
(and only ASCII, like shell variable names generally).
This does avoid Python's minor issue with names like `-1`.

* Positional arguments are not considered in zerg. In zsh, it is
fairly conventional that they are just "what's left" after handling
named options.

==Saving time==

Once an option is defined, you can re-use it in other parsers, by adding
it to them with zerg_use instead of zerg_add:

```
    zerg_new MYOTHERPARSER
    zerg_use PAR__verbose PAR__timeout
    zerg_parse "$@"
```

Also, you can just skip defining the parser on non-first uses:

```
    if ! [[ "$PAR" ]]; then
        zerg_new...
        zerg_add...
    fi
    zerg_parse PAR "$@"
```

The relevant shell variables such as \$PAR, \$PAR__verbose, etc. do hang
around. However, they are declared with typeset's -h flag, so they will not
be listed by `typeset -p` unless requested by specific name(s). This is simply
to avoid clutter, especially for users who may be using your shell functions,
but have no need to be aware of how you did the options.


=To Do=

* Add parser-level file ref and formatter
* Decide whether to return numerics as typeset -i and -F, or strings.
* Add TENSOR, possibly signed int types, ENUM
* Add way to copy a list of option defs from a given variable.
* Maybe really set local variables of given names, instead of returning
as an assoc. That also solves the APPEND problem.


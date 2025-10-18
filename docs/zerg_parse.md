=Information on zsh parse_args=

This is part of the zsh_argparse library, which is a slightly enhanced
port of Python's popular `argparse` library, for defining and parsing
command line options.

This gives several benefits:

* Options are recognized even if abbreviated
* Alternate names / aliases can be defined
* Option value can be checked against a chosen type, including
dates and times, probabilities, identifiers, URLs, and other handy things
* Options can each provide a help string
* The declarations are easy to read and write (even more so if you
already know Python `argparse`)

==Usage==

In your [.zprofile] or other setup file, do:

```
    source bootstrap_defs.sh
    source aa_accessors.sh
    source add_argument.sh
    source parse_args.sh
```

In a given shell function, create a zsh association array that
will store the option definitions (this is roughly like Python's
`argparse` object):

```
    typeset -A PAR=()
```

Then add the desired options using `add_argument`:

```
    add_argument PAR "--verbose" --action count
    add_argument PAR "--encoding" --choices "UTF-8 CP1252 ASCII"
        --default "UTF-8" --help "Input character set to assume."
    add_argument PAR "--source" --type URL
    add_argument PAR "--timeout" --type DURATION --default "10s"
```

Then use `parse_args` to actually parse the command line:

```
    parse_args PAR --ignore-case-option --no-ignore-case-enum --enum-abbrevs $@
```

This will parse the arguments that were passed to the zsh shell function.
In case of errors, an appropriate message will be displayed. and the
shell function will exit.

If parsing is successful, the option values (including any
defaulted ones) are stored in an associative array.
Each is stored under
the correct option reference name (or `destination` if specified),
regardless of whether the command line abbreviated it or used different
case (assuming `ignore-case-option` is in effect.

For lists created with actions such as APPEND, an actual zsh list
cannot be stored as an item in a zsh associative array, so the
members are placed end-to-end, separated by spaces.

Having parsed, the options can be used simply used, like:

    if [[ OPTS[verbose] -gt 2 ]]; then...


=To Do=

* Add parser-level file ref and formatter
* Decide whether to return numerics as typeset -i and -F, or strings.
* Add TENSOR, possibly signed int types, ENUM
* Add way to copy a list of option defs from a given variable.
* Maybe really set local variables of given names, instead of returning
as an assoc. That also solves the APPEND problem.


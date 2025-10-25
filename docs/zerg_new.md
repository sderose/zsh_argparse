==Help on [zerg_new.sh]==

Use this to create a new zsh argument parser, giving it a name.

Once you have created your new parser,
add your arguments using `zerg_add`, and then actually parse your shell
functions arguments with zerg_parse (see help on those for more details):

```
    myfunc() {
        zerg_new MYPARSER
        zerg_add MYPARSER "--quiet -q" --action store_true --help "Less messages."
        zerg_add MYPARSER "--encoding" --type IDENT --default 'utf-8'
            --help "Charset to use."
        zerg_parse MYPARSER "$@"
        [ $quiet ] || echo "Hi, I'm starting up."
        ...
    }
```

If desired, you can dispose of them afterward (or see "Re-use" below).
At the moment, re-creating a parser you've already created is an error,
so you may want to delete or test before creating. However, this is expected
to change so that you can just re-use what's there unless you specify
an option (`on-redefine`) to override.

```
    zerg_del MYPARSER
```

As in the example, the first argument gives one or more names for the option
being defined. It's good practice to quote it even if there's just one,
to remind the reader that it's the name, not a property. It is parsed separately,
so your options may be named the same as `zerg_add` options without conflict.
If multiple names are given, the first
is the "reference name", and the others are considered aliases for it.

There are several options you can use on `zerg_new` which apply to the
parser as a whole:

* --add-help            Automatically add a "--help -h" option
* --allow-abbrev        Allow abbreviated option names (default: on)
* --description TEXT    Description for help text
* --description-paras   Retain blank lines in `description`.
* --epilog TEXT         Show at end of help
* --help-file path      Path to help information
* --help-tool name      Name of a renderer for help information
* --ignore-case         Enable case-insensitive option matching
* --ic-choices          Ignore case on --choices values
* --on-redefine         Treat redefinitions in the specified way:
    * allow (the default): Quietly overwrite any old definition
    * ignore: keep the old definition
    * error: Issue a message and stop
    * warn: Issue a warning and overwrite any old definition
* --usage               Show shorter help, mainly list of options
* --var-style STYLE     How to store results: `separate` (default) or `assoc`.
With `separate`, they are stored as global variables named the same as the
reference names. With `assoc`, they're put in a global associative array
named `ZERGS`, keyed by those names. They are global because they have to
be visible to the shell function that called zerg functions.


==Storage==

The parser "object" is created as a zsh associative array with
the given name, such as MYPARSER in the example above.

Each added option definition is stored as another
associative array. Its name consists of the parser name, plus 2 underscores,
plus that argument's reference name.
So the example above will create 3 assocs, as listed below. However, note that
these will use the `typeset -h` option, so they will not be shown by regular
`typeset -p`. This is to keep them from cluttering up user's lists. You can
still see them by giving their full names.

```
    MYPARSER
    MYPARSER__quiet
    MYPARSER__encoding
```

Nearly all the options that `zerg_add` takes are the same as for Python
`argparse.add_argument`, and they're stored in the option's definition assoc
under those names. Types and actions can also
be given with their own names, not just under `--type` and `--action`, such as:

```
    zerg_add MYPARSER "--quiet -q" --store-true --help "Less messages."
    zerg_add MYPARSER "--encoding" --ident --default 'utf-8'
        --help "Charset to use."
```

All the argument names and aliases are also added as items in the
parser object. Each one's value there is the full name of the assoc for
that definition (such as `MYPARSER__quiet`).
Aliases all point to the same real definition.


==Re-use==

Individual arguments, and/or entire parsers, can be re-used.

To re-use one or more arguments in another parser, add them to a new
parser with `zerg_use` instead of `zerg add`, giving it (like zerg_add)
the name of the new parser you're creating, but followed by just
the full name for each from the parser(s) where they were already defined:

```
    myfunc() {
        zerg_new MYPARSER
        zerg_use MYPARSER OTHERP__quiet OTHERP__ OTHERP__ignore_case
        zerg_add MYPARSER "--encoding" --type IDENT --default 'utf-8'
            --help "Charset to use."
        zerg_parse MYPARSER "$@"
        [ $quiet ] || echo "Hi, I'm starting up."
        ...
    }
```

As you might expect, you can only do this if the prior parser(s) still
exist -- so don't do `zerg_del OTHERP`. `zerg_use` re-uses the very same
definition, directly from the very same shell variable holding its
original definition. Thus you can't change it -- you have to use it as-is.

For convenience, [zerg_setup.sh] sources [zerg_ZERG.sh] provides (well, soon will...) a parser also
named "ZERG", with commonplace argument definitions:

* ZERG__backup
* ZERG__dry_run
* ZERG__encoding
* ZERG__extended-regex
* ZERG__force
* ZERG__human-readable
* ZERG__ignore-case
* ZERG__long
* ZERG__no-clobber
* ZERG__output_encoding
* ZERG__quiet
* ZERG__recursive
* ZERG__verbose
* ZERG__version

==Provided arguments for CSV-ish file description==

I hold the (perhaps unlikely) hope that *nix's commands that deal with
will someday add compatibilty among themselves (looking at you,
cut, paste, colun, awk, join, and several newer sets). To facilitate this,
zerg_ZERG.sh also defines the following arguments, which are named
to match ones from Python's csv library
(re. kebab-case vs. closed forms, see `zerg_new --ignore-punc`):

* ZERG__delimiter (this should perhaps allow the reserved value "SPACES"
to handle the `awk` default behavior)
* ZERG__double-quote (escape quote-chars by using 2 adjacent quote-chars)
* ZERG__escape-char (commonly backslash)
* ZERG__line-terminator (\n, \r, \r\n; I think this should also accept
the mnemonics U, M, and D for applicable OS's, respectively)
* ZERG__quote-char (which should accept either a single character, or
an open/close pair)
* ZERG__quoting (which fields to quote on output; this should accept at least
NONE, ALL, MINIMAL, NONNUMERIC.
* ZERG__skip-initial-space
* ZERG__multi-delim (not in Python CSV, but indicates that multiple
adjacent delimiters should count as just one).
* ZERG__header_record (not in Python CSV, but indicates that the first
record should be a header with field names.

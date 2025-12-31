==README for zerg==

This is a port of Python's popular `argparse` library to zsh,
by Steven J. DeRose.

I wanted a fairly easy way for shell scripts to handle options more
like many other languages provide, such as:

* Ignoring case for option names
* Recognizing unique abbreviations and aliases
* Providing "help" messages for specific options and the tool as a whole
* Checking various value-types like ints in various bases, floats, paths, etc.
* Easier migration between zsh and Python (for users and developers!).

Of course, all this can be built in zsh; it's just not there for free.
Now it is.

===Usage Example===

1: Install zerg via ohmyzsh, or manually. For example (say, from your [.zshrc]
or similar file), do (see [zerg_setup.md] for details).

```
    source 'zerg_plugin.zsh'
```

2: Create a parser, giving it a name as the first argument.
This code would typically go at the top of a shell function definition.


```
    zerg_new MYPARSER --case-ignore-options
```

This creates an associative array with that name, which "is" the parser.
So don't name a parser "PATH" or "EDITOR" or other names
predictably used by other programs.

`zerg_new` also takes various options that
affect the parser as a whole, such as `--allow-abbrev`, `--allow-abbrev-choices`
(for abbreviating option values defined by `choices`), `--ignore-case`,
`--ignore-case-choices`, etc. There is also a `--description` option like
Python `argparse` offers for help, but you may prefer to use `--help-file` to
specify an external help file, and/or `--help-tool` to specify a command
to format and display it (default: the user's $EDITOR or `less`).

3: Add argument definitions:

```
    zerg_add MYPARSER "--quiet -q" --action store_true --help "Less messages."
    zerg_add MYPARSER "--verbose -v" --action count --help "More messages."
    zerg_add MYPARSER "--encoding" --type ident --default 'utf-8'
        --help "Charset to use."
    ...
```

The first argument is the parser name, and the second one is special:
It must be a space-separated list of names for the argument being
defined (unlike Python `argparse`, where each name is separate).
I always quote this argument, to emphasize that it's
not an option to `zerg_add`, but the name(s) of the option you're defining.

After the name(s) come options for the argument being created. These
are almost the same as in Python `argparse` (except for using
customary shell syntax). The most common ones
may be `type`, `action`, `default`, and `help`.

Each argument definition is stored as an associative array, named
by the parser that defined it, "__", and the argument's reference (first) name.
For example, the definition of the "--ignore-case" option would be stored
in `MYPARSER__ignore_case` (hyphens are not permitted in zsh variable names,
so they are changed to underscores).

3a: There is an (experimental) shorthand syntax for adding arguments, that may
be packed straight onto `zerg_new` (instead of using `zerg_add` separately
for each as just shown). It supports names and aliases, a type or action
(plus `choices` values), default, and help. If used, these shorthand
declarations should be placed after "--" to clearly separate them from `zerg_new`
options. Each should be quoted (lots of special characters in there).
Names and aliases don't include the leading hyphen (for single-character names)
or hyphens (for longer names). For example:

```
    parser_new MYPARSER -- \
      'max:int=10[Stop after this many errors]' \
      'out:path=foo.log[Where to write results]' \
      'quiet|q:store_true[Show fewer messages]' \
      'format:choices(xml,json,yaml)[Output format]'
```

4: Use the parser on the actual arguments.
Errors such as unrecognized option or a value not matching what is required
for a given option, are reported, and cause zerg_parse to return a
non-zero return code, which you may use to leave your function if desired:

```
    zerg_parse MYPARSER "$@" || return $?
```

5: Then go on with your shell function, using the arguments as needed.
The resulting values are stored in separate variables named for each option, or
in an associative array named for your parser name plus "__results"
(choose which way with
the `--var_style` option on `parse_new`). zsh can't store arrays or
assocs in other arrays or assocs, so with `--action append` multiple values
are joined into one strings in the assoc case.

    [ $MYPARSER__quiet ] ||  echo "Hi, I'm starting up."
  or
    [ $quiet ] || echo "Hi, I'm starting up."

6: If desired, you can dispose of the parser:
```
    zerg_del MYPARSER
```

*Note*: Zerg functions themselves do not (yet) benefit from zerg for things
like recognizing option abbreviations. For example, you can't say just
`zerg_add ... --descr`, etc.


==Zerg storage==

zerg creates shell variable(s) for the parser itself and each distinct argument.
These set typeset's -H (hidden) flag to avoid clutter.
Results from parsing actual command line arguments can be stored either in
one more associative array, or in separate scalar variables.

Because shell functions are executed within the same shell that invoked them
(rather than a new sub-shell), the storage stays around.
You can keep it around (say, for commands likely to be re-used)
and save time by re-using rather than re-creating it:

```
    if ! [ -v MYPARSER ]; then
        zerg_new MYPARSER...
        zerg_add MYPARSER...
    fi
    zerg_parse MYPARSER...
```
Argument definitions store the options from the zerg_add that defined them.
They can be re-used by other parsers as long as they're still around (see `zerg_use`).

```
    MYPARSER__quiet=(
        [action]=store_true
        [help]='Show fewer messages.'
    )
```


===The zerg type system===

Arguments can be defined as various *types*, such as integer, float,
etc. However, what they're really governing is what strings users can type
for the argument's value, not the conceptual/internal datatype. For example,
an integer might be typed with decimal digits (perhaps with a preceding sign),
or as "0x" plus hexadecimal digits. A path to a file is a string, but it's also
a special string with special constraints.

These sub-types are often important. For example, they define how autocompletion
should work, how typed values map to internal values, and how error-checking is done.

To make this more tractable, zerg provides a wide range of datatypes,
all of which can be used with `zerg_add --type`. See
[zerg_types.md] for details, or use `typeset -p zerg_types` or
`aa_export zerg_types` to see the list.
For example integer types include `int`, `hexint`, `octint`, `binint`, and
the catch-all `anyint` which accepts any of those four.

There are several math types: `float` (which includes exponential notation),
`complex`, `prob` (floats from 0.0 to 1.0), `logprob` (floats <= 0.0),
and `tensor` (which has an optional `shape` parameter).

Several types relate to system concepts, such as `varname`, `pid`, `cmdname`, `alias`, `zergtypename`, and `path`. `path` can be qualified by
permissions or other features.

There are also types for ISO date, time, datetime, duration, and epoch,
and for phenomena such as encoding, lang, locale, and url.

Every type has a test function, named
the same as the type but with "is_" on the front: is_complex, is_date, etc.
There is also [zerg_types.py], which provides a Python function for each type,
which can be used with Python `argparse`'s `type` parameter.


==Configuration==

There are a few settings available in [zerg_setup.sh]:

* ZERG_V sets the level of verbosity. You can either assign it in
zerg_setup.sh, or pass it as an option owhen sourcing zerg_setup.sh.

* ZERG_DEBUG should make zerg re-load dependencies each time.

* ZERG_STACK_LEVELS sets how many layers of stack trace are printed with
warn messages.

* zerg also provides a set of standard errors codes, defined in [zerg_setup.zsh].

A `warn` function is defined in [zerg_setup.sh], and is used to send
messages to stderr. It automatically filtes by level, adds a traceback,
and if the message begins with "====", puts in whitespace and a separator
line (for prominent messages such as headings).


==Aggregate libraries==

zerg includes support functions for shell associative arrays (`aa_accessors.sh`), that wrap or add most of the features
of Python dicts. Most of these have zsh equivalents (`aa_set` is a notable
exception, which in zsh requires using `eval`). Still, I find this package
often handy and readable.

The aa_accessors library also has functions to find items while
ignoring case for keys, for recognizing unique abbreviations, and for
appending to or inserting into string values in place.

`aa_export` and `str_escape` convert their targets to various useful representations,
such as Python, JSON, HTML tables or dls, zsh "qq" form, or pretty-printing. The
default is `-f view`" (pretty-printing), and with `-f view`, `--sort` also
defaults to on, so that's easy to get manually:

    `aa_export MYASSOC`

And finally, zerg provides `zerg_to_argparse`, which takes the named of
a parser created by zerg, and writes out near-equivalent Python argparse code.

Under [extras/] there are similar but unfinished libraries for
non-associative arrays (`ar_accessors.sh`),
sets stored as associative arrays (`set_accessors.sh`), and string functions
and constants (`str_accessors.sh`), such as `aa_values`, `set_union`,
`str_rfind`, etc. These can be used
with or without zerg's argparse-like features (they are not installed
by default, so must be sourced separately if desired).


==Notes==

* zerg argument parsing is very similar to Python argparse. But not identical.

* Most of zerg's shell functions accept `-h` or `--help` to provide a short
description. Most also take `-q` or `--quiet` to suppress
messages (however, messages reporting errors such as too few or unknown
arguments are still reported). As noted above, type test function are an exception.

* zerg functions generally return 0 for success, and a standardized error
code on failure. The error codes begin `ZERR_`, and are defined near the
top of [zerg_setup.sh].

* Yes, zerg is slower than writing straight zsh. If you like type-checking
for your options, abbreviation and case support, etc. you may like the
trade-off. Also, if you already know Python and are still learning zsh,
you may find zerg helps.
I rarely find performance becoming an issue. If it does,
(a) remember to dispose of parsers after you're done (`zerg_del MYPARSER`),
(b) replace calls to any offending function(s) with straight zsh code
(if needed, you can usually learn how just by looking at the zerg implementation).


==Error Codes==

Common errors use these names in the code, and generate the
indicated return code values (these variables are defined in `zerg_setup.sh`).

    * $ZERR_NOT_YET (249): Unimplemented feature
    * $ZERR_TEST_FAIL (248): [Used during testing/debugging]

    * $ZERR_EVAL_FAIL (99): An 'eval' failed.
    * $ZERR_ARGC (98): Wrong number of arguments
    * $ZERR_ZSH_TYPE (97): Value is not of required zsh/typeset type
    * $ZERR_ZTYPE_VALUE (96): Value does not match specified zerg type
    * $ZERR_BAD_OPTION (95): Unrecognized option name
    * $ZERR_ENUM (94): Value does not match the expected enum
    * $ZERR_NO_KEY (93): Key not found (generally in an assoc)
    * $ZERR_NO_INDEX (92): Index not found (in list or string)
    * $ZERR_UNDEF (91): Variable is not defined
    * $ZERR_BAD_NAME (90): String is not a valid identifier
    * $ZERR_DUPLICATE (89): Key or other thing already exists
    * $ZERR_NO_CLASS (79):
    * $ZERR_NO_CLASS_DEF (78):
    * $ZERR_CLASS_CHECK (77):


==See also==

There are individual `.md` files for each code file here,
giving more detail on its content and usage. Nearly all zerg
shell functions (except `is_xxx` tests unless they have options)
respond to `-h` with brief help, and many accept `-q` to suppress messages.

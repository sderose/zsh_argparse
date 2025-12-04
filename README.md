==README for zerg==

This is a port of Python's popular `argparse` library to zsh,
by Steven J. DeRose.

I wanted a fairly easy way for shell scripts to handle options more
like many other languages provide, such as:

* Ignoring case for option names
* Recognizing unique abbreviations and aliases
* Providing "help" messages for specific options and the tool as a whole
* Checking various value-types like ints in various bases, floats, dates, etc.
* Easier migration between zsh and Python (for users and developers!).

Of course, all this can be build in zsh; it's just not there for free.
Now it is.

===Example===

1: Do this first (say, from your [.zshrc] or similar file)
to set up zerg as a whole (see [zerg_setup.md] for details):

```
    source 'zerg_setup.sh'
```

2: Create a named parser.
Argument parsing code typically goes at the top of a shell function definition
(but if preferred, you can create parsers and/or argument definition ahead of
time and just use them).
Most things in zerg are named the same as in Python `argparse`,
and work basically the same (there are some differences; see [zerg_new.md],
[zerg_parse.md], etc. for details).

```
    zerg_new MYPARSER
```

This creates an associative array with that name, which "is" the parser.
So don't name a parser "PATH" or "EDITOR" or other names
predictably used by other programs. `zerg_new` takes various options that
affect the parser as a whole, such as `--allow-abbrev`, `--allow-abbrev-choices`
(for abbreviating option values defined by `choices`), `--ignore-case`,
`--ignore-case-choices`, etc. There is also a `--description` option like
Python `argparse` offers for help, but you may prefer to use `--help-file` to
specify an external help file, and.or `--help-tool` to specify a command
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
It must be a space-separated
list of names for the argument being defined (this is different from
Python `argparse`).
I always quote this argument, to emphasize that it's
not an option to `zerg_add`, but the name(s) of an option you're defining.

After the name(s) come options for the argument being created. These
are almost the same as in Python `argparse` (except for using
customary shell syntax). The most common ones
may be `type`, `action`, `default`, and `help`.

3a: There is an (experimental) shorthand syntax for adding arguments, that may
be packed straight onto `zerg_new` instead of using `zerg_add` separately for each
as just shown. It supports names and aliases, a type or action
(including choice values), defaults, and help strings. If used, these
declarations should be placed after "--" to clearly separate them from `zerg_new`
options. Each should be quoted (lots of special characters in there).
Names and aliases don't include the leading hyphen (for single-character names)
or hyphens (for longer names). For example:

```
    parser_new MYPARSER -- \
      'max:int=10[Stop after this many errors]' \
      'out:path=foo.log[Where to write results]' \
      'quiet|q:store_true[Show fewer messages]' \
      'format:choice(xml,json,yaml)[Output format]'
```

4: Apply the parser to the actual arguments. The resulting values are stored
in an associative array named for your parser name plus "__results",
or in separate variables named for each option (choose which way by
using the `--var_style` option on `parse_new`).
Errors such as unrecognized option or a value not matching what is required
for a given option, are reported, and cause zerg_parse to return a
non-zero return code, which you may use to leave your function if desired:

```
    zerg_parse MYPARSER "$@" || return $?
```

5: Then go on with your shell function, using the arguments as needed:

    [ $MYPARSER__quiet ] ||  echo "Hi, I'm starting up."
  or
    [ $quiet ] || echo "Hi, I'm starting up."

6: If desired, you can dispose of the parser:
```
    zerg_del MYPARSER
```

*Note*: Zerg functions themselves do not (yet) benefit from zerg for things
like recognizing option abbreviations. For example, you can't say just
`--descr`, etc.


==Zerg storage==

zerg creates shell variable(s) for the parser itself and each distinct argument,
These set typeset's -H (hidden) flag, so they
won't show up in a generic list of variables (such as from just `typeset -p`).
Results from parsing actual command line arguments can be stored either in
one more associative array, or in separate scalar variables.

Because shell functions are executed within the same shell that invoked them
(rather than a new sub-shell), the storage stays around.
You can dispose of a parser object and any argument
definitions it owns, with `zerg_del [parser_name]`.
Or you can keep it around (say, for commands likely to be re-used)
and save time by re-using rather than re-creating it:

```
    if ! [ -v MYPARSER ]; then
        zerg_new MYPARSER...
        zerg_add MYPARSER...
    fi
    zerg_parse MYPARSER...
```

===Parser and Argument definition storage===

A parser is stored as a zsh associative array with the given name
(`MYPARSER` in the examples above).

Each argument definition is also stored as an associative array, named
by the parser that defined it, "__", and the argument's reference (first) name.
For example, the definition of the "--ignore-case" option would be stored
in `MYPARSER__ignore_case` (hyphens are not permitted in zsh variable names).

`zerg_parse` stores results in one of two ways (chosen by the `--var-style`
option of zerg_new). First, as a separate local variable named for each
option's reference name (with leading hyphens removed and internal ones
changed to underscores). Or second, in another associative array, named by
the parser name plus "__results", which contains an item for each option,
named as just described. However, zsh can't store arrays or assocs in other
arrays or assocs, so with `--action append` multiple values are joined into
one strings, separated by spaces.

The associative arrays are created as global (`-g`) and hidden (`-H`).


===storage===

You add arguments to a parser with `zerg_add`, which is very like Python's
`parser.add_argument()`.

There are many more options for built-in types (see [zerg_types.md] for
details, or examine the actual list with `typeset -p zerg_types`. Most of these
just care what a string looks like (say, `int` consisting of just digits and
a possible leading sign, or `hexint` consisting of hexadecimal digits). But
some also have special semantics, such as `varname`, `zergtypename`,
and `pid` (which must exist).
A few offer sub-types, such as `path` which can be qualified by
permissions or other features. Every type has a test function, named
the same as the type but with "is_" on the front: is_complex, is_date, etc.

Command-line options do not all require a value in either Python or zsh. Those
that do not are commonly called "flag options", and get a value that
depends on `--default` or `--action`, just like in Python `argparse`.
True is stored as '1', and false as ''. Items whose value is '' may be omitted.

```
    MYPARSER__quiet=(
        [action]=store_true
        [help]='Show fewer messages.'
    )
```


==Configuration==

There are a few settings available in [zerg_setup.sh]:

* ZERG_V sets the level of verbosity. You can either assign it in
zerg_setup.sh, or pass it as an option owhen sourcing zerg_setup.sh.

* ZERG_DEBUG should make zerg re-load dependencies each time.

* ZERG_STACK_LEVELS sets how many layers of stack trace are printed with
warn messages (warn is also defined in [zerg_setup.sh]).


==zerg types==

* zerg provides quite a few types, mainly for use with the `--type` option
on argument definitions. The types include common ones such as int, float,
and str, but quite a few more. Remember that these are meant to constrain
acceptable values for typed values in command lines. Because of that, an
int specified in base 16 (like 0x2022) is a different thing than the same
quantity specified in decimal. zerg provides:

    * Integer subtypes: binint, octint, hexint, and anyint (which
      accepts any of the four).
    * More specific math types: complex, prob, logprob, and tensor.
    * ISO date and time: date, time, datetime, duration, and epoch.
    * OS-meaningful types: argname, cmdname, varname, builtin, reserved,
      alias, function, ident(s), uident(s) for Unicode names.
    * "world" types: encoding, lang, locale, pid, url
    * Others: zertypename, regex, objname, packed

* The types are listed in `zerg_types`. You can most easily view them with
`aa_export zerg_types`.

* Each type has a corresponding `is_xxx` test function (where `xxx` is
the zerg type). Most just check the lexical
form, but some also test semantics (such as `is_varname`),
and a few take options (such as `is_path`). See [zerg_types.md] for details.

* The test functions generally do not issue a message
if the value passed does not satisfy the type requirements, and do not
support `-h` or `-q`, They just
return 0 on success, or `$ZERR_NOT_OF_TYPE` on failure.However, the alternative
`is_of_zerg_type` does issue a message if the value does not match the type,
and does support `-h` and `-q`.

    `is_of_zerg_type [type] [value]`


==Aggregate libraries==

zerg also includes support functions for shell
associative arrays (`aa_accessors.sh`), that wrap or add most of the features
of Python dicts. Most of these have zsh equivalents, but I find this package
handy and readable. Under [extras] there are similar libraries for
non-associative arrays (`ar_accessors.sh`),
sets stored as associative arrays (`set_accessors.sh`), and string functions
and constants (`str_accessors.sh`), such as `aa_values`, `set_union`,
`str_rfind`, etc. These can be used
with or without zerg's argparse-like features (they are not installed
by `zerg_setup.sh`, so must be sourced separately if desired).

* The aa library also has functions to find items while
ignoring case for keys, for recognizing unique abbreviations, and for
appending to or inserting into string values in place.

* Similar libraries are included to help with zsh (non-associative) arrays
(`ar_xxx`), with string operations (`str_xxx`), and with set operations (`set_xxx`).

* `aa_export` and `str_escape` convert their targets to various useful representations,
such as Python, JSON, HTML tables or dls, zsh "qq" form, or pretty-printing. The
default is `-f view`" (pretty-printing), and with `-f view`, `--sort` also
defaults to on, so that's easy to get manually:

    `aa_export MYASSOC`


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

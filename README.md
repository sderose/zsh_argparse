==README for zerg==

This is a port of Python's popular `argparse` library to zsh,
by Steven J. DeRose.

I wanted a fairly easy way for shell scripts to handle options more
like many other languages, such as:

* Ignoring case for option names
* Recognizing unique abbreviations and aliases
* Providing "help" messages for specific options and the tool as a whole
* Checking various value-types like ints in various bases, floats, dates, etc.
* Easier migration between zsh and Python (for users and developers!).

The library also include support functions specifically for shell variables
that are arrays (`ar_accessors.sh`), associative arrays (`aa_accessors.sh`),
sets stored as associative arrays (`set_accessors.sh`), and string functions
and constants (`str_accessors.sh`). These provide
shell functions like most of the Python methods available for the corresponding
types. For example, `aa_values`, `set_union`, `str_rfind`, etc. These can be used
with or without zerg's argparse-like features.

===Example===

Argument parsing code typically goes at the top of a shell function definition.
Most of the options, constants, etc. are named the same as in Python `argparse`,
and work basically the same (there are some differences; see [zerg_new.md],
[zerg_parse.md], etc. for details).

zerg creates shell variable(s) for the parser itself, each distinct argument,
and for results. These set zsh's "hidden" flag, so they
won't show up in a generic list of variables (such as from just `typeset -p`).

1: Do this first (say, from your [.zshrc] or similar file)
to set up zerg as a whole (see [zerg_setup.md] for details):
This defines common functions and variables, such as standard error codes,
messaging functions, etc. and then source the remaining files.

```
    source 'zerg_setup.sh'
```

2: Create a named parser. This creates an associative array with
that name, which "is" the parser. Be careful not to tromp on other variables.
For example, you shouldn't name a parser "PATH" or "EDITOR" or other names
predictably used by other programs.

```
    zerg_new MYPARSER
```

To see the result, you can do something like:
    typeset -p MYPARSER
  or
    aa_export -f view MYPARSER

3: Add argument definitions as illustrated below. The *first* argument after
the parser name is special: It must be a space-separated (and typically quoted)
list of names for the argument being defined. This is slightly different from
Python `argparse`, for which each synonym/alias is given separately. You may
want to always quote this argument, to be most readable:

```
    zerg_add MYPARSER "--quiet -q" --action store_true --help "Less messages."
    zerg_add MYPARSER "--verbose -v" --action count --help "More messages."
    zerg_add MYPARSER "--encoding" --type ident --default 'utf-8'
        --help "Charset to use."
    ...
```

3a: There is an (experimental) shorthand syntax for adding arguments, that may
be packed straight onto zerg_new instead of using zerg_add separately for each
as just shown. It supports names and aliases, a type or action
(including choices values), defaults, and help strings. If used, these
declarations should be placed after "--" to clearly separate them from `zerg_new`
options. Each should be quoted (lots of special characters in there).
Names and aliases don't need the leading hyphen (for single-character names) or
hyphens (for longer names).

For example:

```
    parser_new MYPARSER -- \
      'quiet|q:store_true[Show fewer messages]' \
      'out:path=foo.log[Where to write results]' \
      'format:choice(xml,json,yaml)[Output format]'
```

4: Apply the parser to the actual arguments. The resulting values are stored
in an associative array named for your parser name plus "__results",
or in separate variables named for each option (choose which way by
using the `--var_style` option on `parse_new`).
Errors such as unrecognized option or a value not matching what's required
for a given option, are reported, and cause `zerg_parse` to return a
non-zero return code, which you may use to exit your function as shown.

```
    zerg_parse MYPARSER "$@" || return $?
```

5: Then go on with your shell function, using the arguments as needed:

    [ $MYPARSER__quiet ] ||  echo "Hi, I'm starting up."
  or
    [ $quiet ] || echo "Hi, I'm starting up."

6: If desired, you can dispose of the parser with:

```
    zerg_del MYPARSER
```

==Notes==

* zerg argument parsing is very similar to Python argparse. But not identical.

* Most of zerg's shell functions accept `-h` or `--help` to provide a short
description. Most also take `-q` or `--quiet` to suppress
messages (however, messages reporting errors such as too few or unknown
arguments are still reported).

* zerg functions generally return 0 for success, and a standardized error
code on failure (the codes are defined near the top of [zerg_setup.sh]).

* Most `is_xxx` tests (where `xxx` is any zerg type) do not
offer `-h` or `--help`. Most just test the lexical
form, but some also text semantics (such as `is_varname`, `is_pid`, etc),
and a few take options (such as `is_path`). See [zerg_types.md] for details.
`is_xxx` functions generally do not issue a message
if the value passed does not satisfy the type requirements; they just
return 0 on success, or `$ZERR_NOT_OF_TYPE` on failure. However, the alternative

    `is_of_zerg_type [type] [value]`

does issue a message on failure (unless you set `-q`).

* zerg stores parser objects, argument definition objects, etc. in zsh
associative arrays. These are normally created with `typeset -ghA`, so will
not show up with plain `typeset -p` (you have to name them specifically).
This is to avoid clutter. You can dispose of a parser object and any argument
definitions it owns, with `zerg_del [name]`.

* zerg includes a set of functions for operating on associative arrays,
closely modeled on Python's API for dicts. These functions can be used entirely
apart from zerg's argument parser support. The methods are prefixed with `aa_`.
Many of them can be accomplished with other zsh features, but the zerg
wrappers may be easier to learn/remember/read for users not yet completely fluent
in zsh idioms (or already fluent in Python idioms):

    local k=`aa_get MYASSOC $key`
    local k=${${(P)MYASSOC}[$key]}

    local -a keylist=`aa_keys --sort FOO`
    local -a keylist=(${(koqq)FOO})

* The aa library also has additions such as being able to find items while
ignoring case for keys, for recognizing unique abbreviations, and for
appending to or inserting into string values in place.

* Similar libraries are included to help with zsh (non-associative) arrays
(`ar_xxx`), with string operations (`str_xxx`), and with set operations (`set_xxx`).

* `aa_export` and `str_escape` convert their targets to various useful representations,
such as Python, JSON, HTML tables or dls, zsh "qq" form, or pretty-printing. The
default is `-f view`" (pretty-printing), and with `-f view`, `--sort` also
defaults to on, so that's easy to get manually:
    `aa_export MYASSOC`

* Yes, using all this is slightly slower than writing straight zsh. It's a
tradeoff vs. readability, standardized error messages and codes, and support
for features like type-checking, higher-end argument parsing, etc.
I rarely find performance becoming an issue. If it does,
(a) remember to dispose of parsers after you're done (`zerg_del MYPARSER`),
(b) replace calls to any offending function(s) with straight zsh code
(if needed, you can usually learn how just by looking at the zerg implementation).


==Parser storage==

A parser is stored as a zsh associative array with the given name
(`MYPARSER` in the example above). These are created as global (`-x`)
and hidden (`-H`). The associative array has 4 kinds of entries:

* An item identifying that the assoc represents zerg parser, under
a constant key available in `$ZERG_CLASS_KEY` (from [zerg_obects.sh]).
The value is ZERG_PARSER.
The first character is U+EDDA, a private-use Unicode character.
* Parser-level options (such as`--ignore-case`) are stored in the parser assoc,
under their names converted by removing leading hyphens and converting others
to underscores; similar to what Python does for storing argument values.)
* Arguments added to the parser have all their names as items in the parser assoc
(including hyphens). Each argument's definition is stored as a separate
associative array. That array's name consists of the name of the parser
that defined it, "__", and the argument's reference (first) name. For example,
the definition of the "quiet" option for MYPARSER would be stored in
`MYPARSER__quiet`. The name does not include leading hyphens, and any
internal hyphens are changed to "_".
* There are aslo reserved entries for space-separated lists of all attribute names;
for all the assocs for argument definitions; and for all required arguments.

An example is shown below with the types of entries grouped for readability:

MYPARSER=(
    [\uEDDA_CLASS]=ZERG_PARSER

    [add_help]=''
    [allow_abbrev]=1
    [allow_abbrev_choices]=1
    [description]=''
    [description_paras]=''
    [epilog]=''
    [help_file]='mycommand.md'
    [help_tool]='less'
    [ignore_case]=1
    [ignore_case_choices]=1
    [ignore_hyphens]=''
    [on_redefine]=allow
    [usage]=''
    [var_style]=separate

    [--quiet]=MYPARSER__quiet
    [--verbose]=MYPARSER__verbose
    [--ignore-case]=MYPARSER__ignore_case
    [-i]=MYPARSER__i
    [-v]=MYPARSER__verbose

    [all_arg_names]='--quiet --verbose -v --ignore-case -i '
    [all_def_names]='PARSER__quiet PARSER__verbose PARSER__ignore_case '
    [required_arg_names]=''
)

==Argument definition storage==

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


==Another Example==

```
myFunction() {
    zerg_new OPTS --case-insensitive

    zerg_add OPTS "--maxChar" --type int --default 65535 \
        --help "When displaying a range of code points, skip any above this."
    zerg_add OPTS "--minChar" --int --default 0 \
        --help "When displaying a range of code points, skip any below this."
    zerg_add OPTS "--nomac" --action "store_true" \
        --help "Suppress 'but on Mac' line for code points 128-255."
    zerg_add OPTS "--python" --store-true \
        --help "Make --cat write Python tuples, not just messages."
    zerg_add OPTS "--quiet -q --silent" --action "store_true" --dest shh \
        --help "Suppress most messages."
    zerg_use OPTS "--verbose -v" ZERG_OPTS__verbose

    zerg_parse OPTS "$*"
    ...
}
```

Once the arguments are all defined, do this to actually parse what
you were passed:

```
    zerg_parse OPTS "$@"
```

The resulting option values can be put either into separate variables
(the default),
or into a single associative array (see zerg_new's `--var-style` option
to control this).

See the doc files for each zerg file, or `-h` on most individual zerg functions,
for more information.


==Error Codes==

Common errors use these names in the code, and generate the
indicated return code values (these variables are defined in `zerg_setup.sh`).

    * $ZERR_NOT_YET (249): Unimplemented feature
    * $ZERR_TEST_FAIL (248): [Used during testing/debugging]

    * $ZERR_EVAL_FAIL (99): An 'eval' failed.
    * $ZERR_ARGC (98): Wrong number of arguments
    * $ZERR_SV_TYPE (97): Value is not of required zsh/typeset type
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

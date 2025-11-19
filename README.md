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
    zerg_unset MYPARSER
```


==Parser storage==

A parser is stored as a zsh associative array with the given name
(`MYPARSER` in the example above). These are created as global (-x)
and hidden (-H). The associative array has 4 kinds of entries:

* An item identifying that the assoc represents zerg parser, under
a constant key available in `$ZERG_CLASS_KEY` (from [zerg_obects.sh]).
The value is ZERG_PARSER.
The first character is U+EDDA, a private-use Unicode character.
* Parser-level options (such as`--ignore-case`) are stored in the parser assoc,
under their names converted by removing leading hyphens and converting others
to underscores; similar to what Python does for storing argument values.)
* Arguments added to the parser have all their names as items in the parser assoc
(including
hyphens), and each one's value is the name of a different associative array,
where that argument's definition is stored.
That array's name consists of the name of the parser
that defined it, "__", and the argument's reference (first) name. For example,
the definition of the "quiet" option for MYPARSER would be stored in
MYPARSER__quiet. The name does not include leading hyphens, and any
internal hyphens are changed to "_".
* Reserved entries for space-separated lists of all attribute names;
for all the assocs for argument definitions, and for all required arguments.

An example is shown below, with the types of entries
grouped for readability:

MYPARSER=(
    [\uEDDA_CLASS]=ZERG_PARSER

    [add_help]=''
    [allow_abbrev]=1
    [allow_abbrev_choices]=1
    [description]=''
    [description_paras]=''
    [epilog]=''
    [help_file]=''
    [help_tool]=''
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

You add arguments with `zerg_add`, which as mentioned is very like Python's
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
True is stored as '1', and false as ''. Items whose
value is '' (or false, which is stored as ''), may be omitted.

MYPARSER__quiet=(
    [action]=store_true
    [help]='Suppress messages.'
)


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

See the doc files for each zerg file, and -h on individual zerg functions,
for more information.

Zerg includes a package called `aa_accessors.sh`, which provide most of
the same methods for zsh associative arrays (hence the "aa_" prefix),
as Python provides for dicts. I find these easier to remember than
zsh's panoply of expansion tools, such as `${${(P)1}[$key]}`, and somewhat
less error-prone when switching languages frequently.


==Error Codes==

Common errors use these names in the code, and generate the
indicated return code values (these variables are defined in `zerg_setup.sh`).

* $ZERR_NOT_YET (999): Unimplemented feature
* $ZERR_EVAL_FAIL (998): An 'eval' failed.
* $ZERR_ARGC (98): Wrong number of arguments
* $ZERR_SV_TYPE (97): Value is not of required zsh/typeset type
(`is_type_name` given an unknown type names, returns $ZERR_ENUM)
* $ZERR_ZERG_TVALUE (96): Value does not match specified zerg type
* $ZERR_BAD_OPTION (95): Unrecognized option name
* $ZERR_ENUM (94): Value does not match the expected enum
* $ZERR_NO_KEY (93): Key not found (generally in an assoc)
* $ZERR_NO_INDEX (92): Index not found (in list or string)
* $ZERR_UNDEF (91): Variable is not defined
* $ZERR_BAD_NAME (90): String is not a valid identifier
* $ZERR_DUPLICATE (89): Key or other thing already exists
* $ZERR_TEST_FAIL (55): Case failed in a test suite


==See also==

There are individual `.md` files for each code file here,
giving more detail on its content and usage. Nearly all zerg
shell functions respond to `-h` with brief help, and many accept
`-q` to suppress messages.

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

Do this first (say, from your [.zshrc] or similar file)
to set up zerg as a whole (see [zerg_setup.md] for details):

```
    source 'zerg_setup.sh'
```

This will define common functions and variables, such as standard error codes,
messaging functions, etc. and then source the remaining files.

Then create a named parser, a set of argument definitions, and finally
parse your arguments. Like this:

```
    zerg_new MYPARSER

    zerg_add MYPARSER "--quiet -q" --action store_true --help "Less messages."
    zerg_add MYPARSER "--encoding" --type ident --default 'utf-8'
        --help "Charset to use."
    ...

    zerg_parse MYPARSER "$@"

    [ $quiet ] || echo "Hi, I'm starting up."
    ...
```

The resulting values by default go into variables named the same as their
reference name. It seems to be hard to make those local to your function
that is calling zerg, so they are exported/global. They also use the zsh
hidden flag so they don't show up in a generic list of variable (such as
from just `typeset -p`).

Be careful not to tromp on other variables. For example, you shouldn't name
a parser "PATH".

This code would typically go at the top of your own shell function definition.
Most of the options, constants, etc. are named the same as in Python `argparse`.
The set of types includes many common basic ones as in Python
argparse, but has additions for convenience.

I don't think Python `argparse` is perfect, but it's
pretty capable and its popularity means modeling this directly on it lets
many users re-apply knowledge of names, behaviors, etc. in either direction.

There is also a function included (`zerg_to_argparse`) that converts a zerg
parser definition to corresponding Python.


==Parser storage==

A parser is stored in a zsh associative array with the given name
(`MYPARSER` in this example). These are created as global (-x)
and hidden (-H). The associative array has 4 kinds of entries:

* An item identifying that the assoc represents zerg parser, under
a constant key available in `$EDDA_CLASS_KEY` (from [edda_classes.sh]).
The first character is U+EDDA, a private-use Unicode character.
* Parser-level options (such as`ignore-case`) are stored in the parser assoc,
under their names not including leading hyphens)
* Arguments added to the parser have all their names as items in the parser assoc
(including
hyphens), and each one's value is the name of a different associative array,
where that argument's
definition is stored. That array's name consists of the name of the parser
that defined it, "__", and the argument's reference (first) name. For example,
the definition of the "quiet" option for MYPARSER would be stored in
MYPARSER__quiet. The name does not include leading hyphens, and any
internal hyphens are changed to "_".
* Reserved entries for space-separated lists of attribute names
including their hyphens (to ease later checking): one for
all the arguments' reference names, and one for all *required attributes*.

An example is shown below, with the types of entries
separated by blank lines for readability:

MYPARSER=(
    [\uEDDA.TYPE]=ZERG_PARSER

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

    [all_arg_names]='--quiet --verbose -i -v --ignore-case'
    [required_arg_names]=''
)

==Argument definition storage==

You add arguments with `zerg_add`, which is very like Python's
`parser.add_argument()`. You can just define arguments at the top of
a shell function as shown below. Or you can re-use arguments from a
previously-defined parser via `zerg_use` (zerg includes a parser named `ZERG`,
which provides several commplace option definitions such as quiet, verbose,
encoding, recursive, etc.


Command-line options do not all require a value in either Python or zsh. Those
that do not, get a value that depends on `--default` or `--action` just like
in Python `argparse`. True is stored as '1', and false as ''. Items whose
value is '' (or false, which is stored as ''), may be omitted:

MYPARSER__quiet=(
    [action]=store_true
    [help]='Suppress messages.'
)


==Example==

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

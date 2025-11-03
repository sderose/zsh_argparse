==README for zerg==

This is a port of Python's popular `argparse` library to zsh,
by Steven J. DeRose.

I wanted a fairly easy way for shell scripts to handle options more
like many other languages, such as:

* Ignoring case for option names
* Recognizing unique abbreviations
* Handling various value-types like ints in various bases, floats, dates, and enums
* Providing "help" messages for specific options and the tool as a whole
* Easier migration between zsh and Python (for users and developers!).

The library also include support functions specifically for shell variables
that are arrays (`ar_accessors.sh`), associative arrays (`aa_accessors.sh`),
and sets stored as associative arrays (`set_accessors.sh`). These provide
shell functions like most of the Python methods available for the corrsponding
types. For example, `aa_values`, `set_union`, etc.

===Example===

Do this first (say, from your [.zshrc] or similar file)
to set up zerg as a whole (see [zerg_setup.md] for details)_:

```
    source 'zerg_setup.sh'
```

This will define common functions and variables, such as
Then create a named parser and a set of argument definitions, and finally
parse your argument. Like this:

```
    zerg_new MYPARSER
    zerg_add MYPARSER "--quiet -q" --action store_true --help "Less messages."
    zerg_add MYPARSER "--encoding" --type ident --default 'utf-8'
        --help "Charset to use."
    zerg_parse MYPARSER "$@"
    [ $quiet ] || echo "Hi, I'm starting up."
    ...
```

The resulting values by default go into variables named the same as their
reference name (it seems to be hard to make those local to your function
that is calling zerg, so they are exported/global. Be careful not to tromp
on other variables.

This code would typically go at the top of your own shell function definition.
Most of the options, constants, etc. are named the same as in Python argparse.
The set of types includes the most common basic ones as in Python
argparse, but has additions for convenience.

I don't think Python argparse is perfect, but it's
pretty capable, and its popularity means modeling this directly on it lets
many users re-apply knowledge of names, behaviors, etc. in either direction.

There is also a function included (`zerg_to_argparse`) that converts a zerg
parser definition to corresponding Python.


==Parser storage==

A parser is stored in a zsh associative array with the given name
(`MYPARSER` in this example). These are created as global (-x)
and hidden (-H). The associative array has 3 kinds of entries:

* `parser_new` options (such as`ignore-case`) are stored under their names,
not including leading hyphens)
* Arguments added to the parser are listed under all their names (including
hyphens), and each one's value is the associative array in which that argument's
definition is stored. Normally this consist of the name of the parser
that defined it, "__", and the argument name (minus leading hyphens, and with
internal hyphens changed to "_" so they're legit zsh variable names).
* A reserved `refnames` entry, which contains a space-separated list
of all the arguments' reference names, including leading hyphens.

The three types are separated by blank lines for readability in this example:

MYPARSER=(
    [abbrev_enums]=1
    [add_help]=''
    [allow_abbrev]=1
    [description]=''
    [description_paras]=''
    [epilog]=''
    [help_file]=''
    [help_tool]=''
    [ic_choices]=''
    [ignore_case]=1
    [ignore_hyphens]=''
    [on_redefine]=error
    [usage]=''
    [var_style]=separate

    [--quiet]=PARSER__quiet
    [--verbose]=PARSER__verbose
    [--ignore-case]=PARSER__ignore_case
    [-i]=PARSER__i
    [-v]=PARSER__verbose

    [refnames]='--quiet --verbose -i -v --ignore-case'
)

==Argument definition storage==

You add arguments with `zerg_add`, which is very like Python's
`parser.add_argument()`. You can set them up in advance (see `zerg_use`),
or just at the top of a shell function as shown below.

Each added argument definition is stored
in its own associative array, named like `MYPARSER__quiet`, etc.

Each argument definition is stored in its own associative array, whose name
includes the parser name, two underscores, and the argument's reference
name. For example, `OPTS__quiet`.

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

The resulting options values can be put either into separate variables,
or into a single associative array.
However, in an assoc any array values (such as created with `--action append`)
are joined into a single string. This is because zsh does not support having
arrays as members of other arrays.

See the doc files for each zerg file, and -h on individual zerg functions,
for more information.

Zerg includes a package called `aa_accessors.sh`, which provide most of
the same methods for zsh associative arrays (hence the "aa_" prefix),
as Python provides for dicts. I find these easier to remember than
zsh's panoply of expansion tools, such as `${${(P)1}[$key]`, and somewhat
less error-prone when switching languages frequently.


==Error Codes==

Common errors case use these names in the code, and generate the
indicated return code values (they are defined in `zerg_setup.sh`).

* ZERR_NOT_YET (999): Unimplemented feature
* ZERR_EVAL_FAIL (998): An 'eval' failed.
* ZERR_ARGC (98): Wrong number of arguments
* ZERR_SV_TYPE (97): Value is not of required zsh/typeset type
(`is_type_name` given an unknown type names, returns ZERR_ENUM)
* ZERR_ZERG_TVALUE (96): Value does not match specified zerg type
* ZERR_BAD_OPTION (95): Unrecognized option name
* ZERR_ENUM (94): Value does not match the expected enum/choices
* ZERR_NO_KEY (93): Key not found (generally in an assoc)
* ZERR_NO_INDEX (92): Index not found (in list or string)
* ZERR_UNDEF (91): Variable is not defined
* ZERR_BAD_NAME (90): String is not a valid identifier
* ZERR_DUPLICATE (89): Key or other thing already exists
* ZERR_TEST_FAIL (55): Case failed in a test suite



==See also==

There are individual `.md` files for each code file here,
giving more detail on its content and usage. Nearly all
shell functions here respond to `-h` with brief help.


==To Do==

* Option `--ignore-hyphens` to ignore internal underscores
and hyphens (for example, "--ignore-case",
"--ignore_case", "--ignorecase" are considered the same)

* Revise zerg_new to re-use existing args if found (blockable by some option)

* Add --pattern to give a regex the value has to match (if nargs >1, regex
should assume one space between?)

* Lots of testing

* Add metavar, usage, and help generation; support external help and formatter

* Finish added types, normalized strings.

* Maybe add 'parents', 'prefix_chars' (e.g. for "+")

* Option to not hide all the assoc variables?

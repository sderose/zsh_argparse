==Help on [zerg_new.sh]==

Use `zerg_new` to create a new zsh argument parser, giving it a name.

Once you have created your new zerg parser,
add argument definitions using `zerg_add`, and then parse your shell
function's actually arguments with `zerg_parse` (see help on those for more details):

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

`zerg` works a lot like Python's `argparse` so if you know either then
learning the other should be pretty easy. But zerg is all zsh.

A nice way to display a parser, argdef, or other assoc, is:
    aa_export assocname

`aa_export` also has a `-f` or `--format` option with several choices
(the default choice is `view`, which makes a 2-column, sorted layout).

If desired, you can dispose of the parser afterward (or see "Re-use" below).
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
parser as a whole. One marked "(and negative)" below can be turned
off instead of on, by prefixing the name with `no-`. For example,
`--no-ignore-case`.

* --add-help
Automatically add a "--help -h" option

* --allow-abbrev OR --abbrev (and negative)

Allow abbreviated option names (default: on)

* --allow-abbrev-choices OR --abbrevc (and negative)
Allow abbreviated values for --choices (default: on)

* --description [text]
Description for help text

* --description-paras OR --dparas
Retain blank lines in `description`.

* --epilog [text]
Show at end of help

* --help-file [path]
Path to a help information file.

* --help-tool [name]
Name of a renderer executable for help information (default: $PAGER)

* --ignore-case OR --ic (and negative)
Enable case-insensitive option matching

* --ignore-case-choices OR --icc (and negative)
Ignore case on --choices values.

* --ignore-hyphens OR --ih (and negative)
Ignore internal hyphens in option names

* --on-redefine OR --redef [what]
Treat redefinitions in the specified way:

    * allow (the default): Quietly overwrite any old definition
    * ignore: Keep the old definition
    * warn: Issue a warning and overwrite any old definition
    * error: Issue a message and stop

If the parser name given is already defined, but it not a zerg parser,
that is always an error (so zerg doesn't overwrite stuff it doesn't own).

* --usage [text]
Show shorter help, mainly list of options

* --var-style [how]
How to store results: `separate` (default) or `assoc`.
With `separate`, they are stored as global variables named the same as the
reference names. With `assoc`, they're put in an associative array
named by the parser name, two underscores, and "results", keyed by those names.
Thus, you can't have an option with refname "results" if you're using
`--var-style assoc` for that parser (though "results" could be a non-refname
(aka alias).


==Storage==

The parser "object" is stored in a zsh associative array with
the given name, such as MYPARSER in the example above.

Each argument definition is also stored as an associative array, named
by the parser that defined it, "__", and the argument's reference (first) name.
For example, the definition of the "--quiet" option for MYPARSER goes in
`MYPARSER__quiet`.

Because hyphens are ubiquitous for options but not permitted in zsh variable
names, option names are often converted
by dropping leading hyphens and changing internal hyphens to underscores.
This can be done via `zerg_opt_to_var`. This is done for naming argument
definitions, so MYPARSER's definition for an "--ignore-case" option would
be stored in `MYPARSER__ignore_case`. Note that the `--ignore-case` option
to `parser_new` has nothing to do with like-named options which might be
defined in a specific zerg parser(s).

The assoc for a parser has 4 kinds of entries:

* An item identifying that the assoc represents a zerg parser. This uses
a reserved key (available in `$ZERG_CLASS_KEY`, from [zerg_obects.sh]).
The value is "ZERG_PARSER".

* The values of parser-level options (such as`--ignore-case`),
under their names (as converted by `zerg_opt_to_var`).

* Each name/alias for an argument gets an item in the parser's associative
array, named exactly as the option (including hyphens). The corresponding
value is the name of the applicable argument definition.

* There are a few special entries for space-separated lists of all attribute
names; all the argument definitions; and all required arguments.

An example is shown below with the types of entries grouped for readability.
You can of course display such as assoc once created, using `typeset -p`,
`aa_export`, etc.

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
    [-v]=MYPARSER__verbose
    [--ignore-case]=MYPARSER__ignore_case
    [-i]=MYPARSER__i

    [all_arg_names]='--quiet --verbose -v --ignore-case -i '
    [all_def_names]='PARSER__quiet PARSER__verbose PARSER__ignore_case '
    [required_arg_names]=''
)

Option definitions are similar but simpler. The EDDA_CLASS value is
"ZERG_ARG_DEF" instead of "ZERG_PARSER", and the other entries are just
the relevant options from `zerg_add`. The argument's names/aliases are not
speifically listed; they are available by examining the parser object as
described above.

assoc 'PARSER__quiet':
  \\uEDDA_CLASS         ZERG_ARG_DEF
  action                store_true
  arg_names             "--quiet -q --silent"
  help                  "Less chatty."

Argument definition can be re-used by other parsers (see `zerg_use` and
the `--parent` option of `zerg_new`). In such cases, the re-using parser
has entries for the names, but they point to the original definition (which,
therefore, should not be deleted). The argument definitions are not redundantly
copied.


==Re-use==

Individual arguments, and/or entire parsers, can be re-used.

To re-use one or more arguments in another parser, add them to a new
parser with `zerg_use` instead of `zerg_add`, giving it
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

For convenience, [zerg_setup.sh] sources [zerg_ZERG.zsh] provides (well, soon will...) a parser also
named "ZERG", with commonplace argument definitions ("help" is already covered
by the `zerg_new --add-help` option).

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

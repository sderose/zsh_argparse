==Help on `zerg_new.sh`==

Use this to create a new zsh argument parser, giving it a name.

Once you have created your new parser,
add your arguments using `zerg_add`, and then actually parse your shell
functions arguments with zerg_parse (see help on those for more details):

```
    myfunc() {
        zerg_new MYPARSER
        zerg_add MYPARSER "--quiet -q" --action STORE_TRUE --help "Less messages."
        zerg_add MYPARSER "--encoding" --type IDENT --default 'utf-8'
            --help "Charset to use."
        zerg_parse MYPARSER "$@"
        [ $quiet ] || echo "Hi, I'm starting up."
        ...
    }
```

As in the example, the first argument gives one or more names for the option
being defined. It's good practice to quote it even if there's just one,
to remind the reader that it's the name, not a property. It is parsed separately,
so you options may be named the same as any zerg_add option without conflict.
If multiple names are given, the first
is the main reference name, and the others are aliases for it.

There are several options you can use on zerg_new, which apply to the
parser as a whole:

* --description TEXT    Description for help text
* --ignore-case         Enable case-insensitive option matching
* --allow-abbrev        Allow abbreviated option names (default: on)
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


==Option re-use==

Because the value stored for an option or alias is the full name, not just
the reference name,
definitions can be referenced from a different parser object to be re-used.
This is a great way to re-use definitions for consistency, and a bunch of
typical options are provided in `ZERG_ARGS`. They are listed in the help
for `zerg_add`.

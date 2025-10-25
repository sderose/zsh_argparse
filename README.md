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

===Example===

You need to do this to set up zerg as a whole (say, from your
[.zshrc] or similar):

```
    source 'zerg_setup.sh'
```

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
argpare, but has additions for convenience.

I don't think Python argparse is perfect by a long shot, but it's
very popular and pretty capable so modeling this directly on it
lets users re-apply much of their knowledge of names, behaviors, etc. either way.

There are also additions coming that translate between the Python and zsh
usage, so you can move back and forth if you want.


==Variables==

The parser is stored in a zsh associative array with the given name
(`MYPARSER` in this example). Each added argument definition is stored
in its own associative array, named like `MYPARSER__quiet`, etc.

You add arguments with `zerg_add`, which is very like Python's
`parser.add_argument()`. You can set them up in advance (see `zerg_use`),
or just at the top of a shell function as shown below.

Each definition is stored in its own assoc, named like `OPTS__macChar`, etc.

Unlike Python function arguments, command-line options
do not all require a value in either Python or zsh. Those
that do not, get a value that depends on `--default` or `--action`, just like
in Python `argparse`.

```
myFunction() {
    zerg_new OPTS --case-insensitive
    zerg_add OPTS "--maxChar" --type int --default sys.maxunicode \
        --help "When displaying a range of code points \ skip any above this."
    zerg_add OPTS "--minChar" --type int --default 0 \
        --help "When displaying a range of code points \ skip any below this."
    zerg_add OPTS "--nomac" --action "store_true" \
        --help "Suppress 'but on Mac' line for ccode points 128-255."
    zerg_add OPTS "--python" --action "store_true" \
        --help "Make --cat write Python tuples \ not just messages."
    zerg_add OPTS "--quiet" \ "-q" --action "store_true" \
        --help "Suppress most messages."
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

==README for zerg==

This is a port of Python's popular `argparse` library for zsh,
by Steven J. DeRose.

I wanted a fairly easy way for shell scripts to handle options more
like many other languages, such as:

* Ignoring case for option names
* Recognizing unique abbreviations
* Handling various value-types like ints, floats, dates, and enums
* Providing "help" messages for specific options and the tool as a whole
* ...

I don't think Python argparse is perfect by a long shot (I'm especially not
fond of its formatter, for which I offer a replacement at
[https://github.com/sderose/PYTHONLIBS/blob/master/argparsePP.py]), but it's
very popular and pretty capable, so modeling this directly on it
lets users re-apply most of their knowledge of names, behaviors, etc. either way.

There are also additions coming that translate between the Python and zsh
usage, so you can move back and forth if you want.

===Example===

A set of argument definitions is created and used like this:

```
    zerg_new MYPARSER
    zerg_add MYPARSER "--quiet -q" --action STORE_TRUE --help "Less messages."
    zerg_add MYPARSER "--encoding" --type IDENT --default 'utf-8'
        --help "Charset to use."
    zerg_parse MYPARSER "$@"
    [ $quiet ] || echo "Hi, I'm starting up."
    ...
```

This would typically go at the top of your own shell function definition.

The parser is stored in a zsh associative array with the given name
(`MYPARSER` in this example). Each added argument definition is stored
in its own associative array, name like `MYPARSER__quiet`, etc.

Then you add arguments with `zerg_add`, which is very like Python's
`parser.add_argument()`:


You can set them up in advance (handy for re-use), or just at
the top of a shell function as shown below.

Each argument is defined by calling `zerg_add`, with its first argument
being the name of the shell associative array (`OPTS` in this example).
Of course the call is in zsh syntax, so options to zerg_add use `--x` rather than `x="`.

```
myFunction() {
    zerg_new OPTS
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

Each definition is stored in its own assoc, named like `OPTS__macChar`, etc.

Unlike Python function arguments, command-line options
do not all require a value in either Python or zsh. Those
that do not, get a value that depends on `--default` or `--action`, just like
in Python `argparse`.

Once the arguments are all defined, you do this to actually parse what
you were passed:

```
    parse_args OPTS
```

The values can be put either into separate variables, or into a single assoc.
However in an assoc, array values such as created with `--action append` are
joined into a single string.


==Setup==

At the moment, you need to do this to set up (say, from your
[.zshrc] or similar):

```
    source 'zerg_add.sh'
    source 'aa_accessors.sh'
    source 'bootstrap_defs.sh'
    source 'parse_args.sh'
```


==To Do==

* Lots of testing

* Add metavar and help generation

* Options for help file and viewer

* Warn about non-identifier option names

* Finsh TOGGLE, TENSOR, normalized strings

* Should "+" like in set and shopt be supported?


==See also==

There are individual `.md` files for each code file here, giving more detail on
its content and usage. Nearly all shell function also respond to `-h` with
brief help.

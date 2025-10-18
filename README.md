==README for zsh_argparse==

This is a port of Python's popular `argparse` library for zsh.

I want my shell scripts to handle options more like many other languages,
such as:

* Ignoring case for option names
* Recognizing unique abbreviations
* Handling various value-types like ints, floats, dates, and enums
* Providing "help" messages
* ...

I don't think Python argparse is perfect by a long shot (I'm especially not
fond of its formatter, for which I offer a replacement at
[https://github.com/sderose/PYTHONLIBS/blob/master/argparsePP.py]), but it's
very popular and pretty capable, so modeling `zsh_argparse` directly on it
lets users re-apply most of their knowledge of names, behaviors, etc. either way.

There are also scripts coming that translate between the Python and zsh
usage, so you can move back and forth if you want.

===Example===

A set of argument definitions is stored in a zsh associative array,
each under its full name (pretty similar to Python's object).
You can set them up in advance (handy for re-use), or just at
the top of a shell function as shown below.

Each argument is defined by calling `add_argument`, with its first argument
being the name of the shell associative array (`OPTS` in this example).
Of course the call is in zsh syntax, so options to add_argument use `--x` rather than `x="`.

```
myFunction() {
    add_argument OPTS "--maxChar" --type int --default sys.maxunicode \
        --help "When displaying a range of code points \ skip any above this."
    add_argument OPTS "--minChar" --type int --default 0 \
        --help "When displaying a range of code points \ skip any below this."
    add_argument OPTS "--nomac" --action "store_true" \
        --help "Suppress 'but on Mac' line for ccode points 128-255."
    add_argument OPTS "--python" --action "store_true" \
        --help "Make --cat write Python tuples \ not just messages."
    add_argument OPTS "--quiet" \ "-q" --action "store_true" \
        --help "Suppress most messages."
}
```

Each definition is stored in its own assoc, named like `OPTS__macChar`, etc.

Unlike Python function arguments, zsh options do not all require a value. Those
that do not, get a value that depends on `--default` or `--action`, just like
in Python `argparse`.

Once the arguments are all defined, you do this to actually parse what
you were passed:

    parse_args OPTS

The values can be put either into locals, or into a single assoc.
However in an assoc, array values such as created with `--action append` are
joined into a single string.


==Setup==

At the moment, you need to do this to set up (say, from your
.zshrc or similar):

```
    source 'add_argument.sh'
    source 'aa_accessors.sh'
    source 'bootstrap_defs.sh'
    source 'parse_args.sh'
```


==To Do==

* Lots of testing

* Add destination, metavar, nargs, choices

* Support multiple names

* At least warn about non-identifier option names

* Add convenience functions for non-associative zsh arrays?

* Finsh TOGGLE, TENSOR

* Make case-ignoring switchable

* Should "+" like in set and shopt be supported?

* Case-folded, space-normalized, and unicode normalized strings

* Type for lang codes?


==See also==

There are individual `.md` files for each code file here, giving more detail on
its content and usage. Nearly all shell function also respond to `-h` with
brief help.

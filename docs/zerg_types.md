==Help on types in zerg==

This is mainly help for the values of the `--type` argument of `zerg_add`.
These types govern the strings users can specify on the command line,
for options of that particular type.
Other types may be added. See [TODO.md].

All this is set up via [zerg_types.sh] (which is one of the things called
by the more general [zerg_setup.sh]).

zerg's types serve the same purpose as values for the `type` argument of
Python's `argparse.add_argument`. They mean that a given string
*can be interpreted as* the given type.
So in argument parsing (whether in zsh or Python), saying `type=int` means the command line items must be a string that amounts to a decimal
integer, such as "64". zerg provides `--type int` with that same meaning.

Zerg also adds types
such as `hexint` for a base-16 expression such as "0xA0". argparse could have
done this by using `int(arg, 0)` instead of just `int(arg)` internally,
but it doesn't (as of this writing). I consider
it common enough to just provide off-the-shelf (batteries, y'know).
There are also `octint` for base-8 values like "0o100",
`binint` like "0b10110111", and `anyint` for allowing any of the 4 bases.

There are convenience types for dates, times,
urls, pids, and some important mathematical types such as `prob`, `logprob`,
and `complex`. Tensors have rudimentary support, represented as whitespace
separated sequences of floats, "(", and ")".

The types are listed in a zsh associative array named `zerg_types`, which is
created by `zerg_setup.sh`. Each has its name (all lower case) as the key,
and the value is a near-equivalent Python type. The Python type is used
mainly by `zerg_to_argparser()`. "zergtypename" is itself a zerg type.

==Type-related functions==

Each type has a tester named `is_` plus the (lower case) type name, such as
`is_int`. These return code 0 (success) if the string passed fits the type. If
the string does not match the type, return code 1 is returned and a
message is printed (unless the function was given the `-q` option (for quiet).
A few of the is_xxx functions offer options, such as is_pid checking whether
a process not only exists, but is signalable, or path checking permissions.

Other functions provided by `zerg_types.sh`:

* `is_of_type [name] [string]` -- this is just another way to run the `is_`
function for the given zerg type name.

* `zerg_ord [char]` returns the numeric code point for the character

* `zerg_chr [int]` returns the literal Unicode character corresponding to a code point


==The types==


===Integer types===

* `int` -- a decimal integer, optionally signed.

* `hexint` -- a hexadecimal integer like 0xFE01.

* `octint` -- an octal integer like 0o777.

* `binint` -- a binary integer like 0b10111110.

* `anyint` -- an int in any of those forms.

* `unsigned` -- a decimal integer with no sign prefix.

* `pid` -- an active process ID. The `is_pid` test can also take
a `-a`- or `--active` option, to accept only active (signalable) processes.

The letters indicating base (b, o, and x) are recognized regardless of case.


===Boolean type===

* `bool` -- This type is not commonly used, because True/False options are
often implemented via `action="store_true"` and/or `action="store_false"`
(or in zerg, `action=toggle` which creates both in one step).
However, if you specify type `bool`, a few conventional values are
recognized. zsh's conventional "False" value is the empty string: "", and
that counts as false (as it does if you specify `type=bool` for Python argparse).
For Python argparse, it seems that anything else counts as True.
For zerg, however, only these values are accepted:
   For True: 1 true yes on y
   For False: 0 false no off n ""

===Floating-point types===

* `float` -- A floating-point decimal value, allowing exponential notation.
Specials such as NaN, Inf, etc. are not supported.

* `prob` -- A `float` in the range from 0.0 to 1.0 (inclusive), as for a probability.

* `logprob` -- A non-positive `float`, as for the logarithm of a probability.

* `complex` -- A complex number in a form such as -3.14+1.618i.
The trailing `i` can be any of [iIjJ].

* `tensor` -- Tensor is a type that expects a string consisting of one
or more whitespace
separated floats. The floats may also be grouped by parentheses, which
may or may not also be whitespace separated.
Parentheses are checked for balance but not for uniform cardinalities,
unless the `--shape` option is specified for is_tensor (see below).
For example:

( ( 1E-10 2 3 ) ( 4 5 6 ) ( 7 -8 9 ) )

or

( ( 0.110001 0.1234567891011 0.235711131719 0.412454033 )
  ( 0.57721 0.6180338 0.91596 1.839 )
  ( 1.3247 1.20205 1.6180338 2.502 )
  ( 2.685 2.71828 3.14159 4.669 6.28318) )

If specified, the experimental `--shape` option must have a value
consisting of one or more space separated
tokens, each of which must be a positive integer or "*". `is_tensor` will
count the number of items at each () nesting level, and report if any does not
match the declared size (except, of course, for sizes of "*").


===String types===

"string" very often is used as a catch-all for other types, leaving important
constraints aside. In zsh, most variables are technically strings even when
more accurate types are available; it's slightly easier to type `local n=1`
even when `local -i n=1` would be slightly safer and more precise.
There are also many cases like variable names, dates, language codes, and
countless "enums" that are highly constrained, not merely generic "strings".

Strings often also want special treatment such as case-folding, whitespace
normalization, and having to match a given regular expression.
zerg provides several subtypes of string, and the zerg argument parser
can be set up to handle case, pattern-matching, and so on.

* `str` -- any string.

* `char` -- a single character. Unicode characters beyond ASCII count correctly
as single characters, and combining characters do not count extra. For example,
LATIN SMALL LETTER E WITH ACUTE (U+e9) counts as a single character,
and so does the combination of LATIN SMALL LETTER E (U+65)
and COMBINING ACUTE ACCENT (U+301). The latter is accomplished via `wc -m`.

* `ident` -- a zsh identifier (not necessarily already in use; see `varname`).
Identifiers must start with an ASCII letter or underscore,
and may continue with more letters, digits, and/or underscores.

* `idents` -- one or more `ident` items, separated by whitespace.

* `uident` -- a Unicode identifier token. The intent is to resemble
identifiers as in programming languages that support Unicode names,
but the rules are fairly loose.

* `uidents` -- one or more `uident` items, separated by whitespace.

* `argname` -- a typical command-line argument (option) name.
Either a hyphen plus one letter; or two hyphens, a letter,
and perhaps continuing with more letters, digits, and/or underscores.
This does not currently acknowledge bundled single-character options (TODO).

Both in Python argparse and in zerg, such names are converted for
use as destination variable names by dropping the leading hyphen(s)
and changing internal hyphens to underscores. `zerg_opt_to_var` does this.
In zerg, actual argument definitions are stored in assocs named by
the parser that created them, 2 underscores, and the argument's reference name
as transformed via `zerg_opt_to_var`.
See `zerg_new` and `zerg_add` for more details.

* `cmdname` -- the name of a currently-available command. This includes
executables along PATH, aliases, builtins, and shell functions.

* `varname` -- the name of a currently-available shell variable.
If a second argument is given it should be the name of a zsh variable type,
and the variable will be tested for whether it's of that type
(namely undef, scalar, integer, float, array, or assoc -- see `sv_type`).

* `zergtypename` -- the name of a zerg-defined datatype.

* `regex` -- an actual regex expression. Not to be confused with
a string *that matches* a particular expression.

* `path` -- a file, directory, or similar path as appropriate to the
file system in effect. Checking is fairly loose. There are not
named sub-types to distinguish paths that would match
zsh file-tests such as `-d -e -f -r -w -x -N`. However, the `is_path` function
does have these and a few others as options.

* `url` -- loose checking.

* `lang` -- a language code. Currently this accepts either the form defined
by ISO 639 and several RFCs (used in HTML, XML, and other places),
such as "en-us`" or the form seen in locale's `LANG`, such as "en_US.UTF-8".
Specific country, language, and character set names are not checked.

* `encoding` -- a character encoding scheme. This is checked via `iconv -l`,
which has a wide selection of names. All the names there consist of
uppercase ASCII letters, ASCII digits, hyphen, underscore, and occasional
[:.()+].

* `format` -- a single %-initial format code as understood by zsh `printf`.
There's a lot to these, and they're not quite the same as in C or Python.


===Enumerations===

There is no enum type in zerg. Enumerations are handled as string.
For particular argument definitions, the definition can use --choices
to constrain the value to a list of `idents`.
There are options to ignore case and/or to recognize abbreviations for these.


===Date and time types===

* time -- a time in ISO 8601 form: hh:mm:ss.
Leading zeroes are not required.
Fractional seconds can be appended as .nnn.
A time zone offset can be addeded as "Z" (for UTC) or as a plus or minus
sign followed by hh:mm.

```
    12:01:59
    12:01:59Z
    23:59:59-5:00
```

* date -- a date in ISO 8601 form: yyyy-mm-dd.
The usual truncations, such as "2025-09", are supported.

* datetime -- a date and time in ISO 8601 form (joined by a "T"), such as
`2025-10-19T00:00:00.000-5:00`.

* duration -- an amount of time. For the moment, this is merely a number
followed by one of s, m, h, or d for units. I expect to fix this to
support full ISO 8601 duration values, which start with `P` and then
continue with one or more number+unit parts, in descending order of size
(and with "T" to separate date-sized vs. time-sized parts):

    P[n]Y[n]M[n]DT[n]H[n]M[n]S

* epoch -- this is for a *nix "Epoch time", the number of seconds since
the start of 1970. Syntactically, this is just a `float`, so can represent
sub-second precision and dates prior to 1970 (although other issues arise
ranging from leap-seconds to the Gregorian calendar reform).

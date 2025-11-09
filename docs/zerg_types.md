==Help on types in zerg==

This is mainly help for the values of the `--type` argument of `zerg_add`.
These types govern the strings users can specify on the command line,
for options of that particular type.

All this is set up via [zerg_types.sh] (which is one of the things called
by the more general [zerg_setup.sh]).

zerg's types serve the same purpose as values for the `type` argument of
Python's `argparse.add_argument`. They mean that a given string
*can be interpreted as* the given type.
So in argument parsing (whether in zsh or Python), saying "type=int` means the command line items must be a string that amounts to a decimal
integer, such as "64" (in ASCII, Unicode, or whatever encoding your terminal
and Python are using).

zerg provides `--type int`, with that same meaning but it also provides for
other conventions, such as `hexint` which requires
a base-16 expression such as "0xA0". While this also typically  represent
an integer value to be stored, what it actually constrains (like Python argparse's `type`) is what strings the user can use to express that type.
Similarly, zerg's `octint` requires a base-8 value such as "0100"
(also equal to decimal 64), and `anyint` allows any of 999, 0777, 0xFFFF,
or 0b10110111.

In addition, there are convenience types for things like dates, times,
urls, and some important mathematical types such as `prob`, `logprob`,
and `complex`. Tensors are not (yet) supported.

The types are listed in a zsh associative array named `zerg_types`, which is
created by `zerg_setup.sh`. Each has its name (all lower case) as the key,
and the value is a near-equivalent Python type. The Python type is used
mainly by `zerg_to_argparser()`.

==Type-related functions==

Each type has a tester named `is_` plus the (lower case) type name, such as
`is_int`.
These return code 0 (success) if the string passed fits the type. If
the string does not match the type, return code 1 is returned and a
message is printed (unless the function was given the `-q` option (for quiet).

Other functions provided by `zerg_types.sh`:

* `is_type_name [name]` -- succeeds if `name` is a know type name

* `is_of_type [name] [string]` -- this is just another way to run the `is_`
function for the given type name

* `zerg_ord [char]` returns the numeric code point for the character

* `zerg_chr [int]` returns the literal Unicode character corresponding to a code point


==The types==


===Integer types===

* `int` -- a decimal integer, optionally signed

* `hexint` -- a decimal integer like 0xFE01

* `octint` -- an octal integer like 0o777

* `binint` -- a binary integer like 0b10111110

* `anyint` -- an int in any of those forms

* `pid` -- an active process ID

===Boolean type===

* `bool` -- This type is not commonly used, because True/False options are
often implemented via `action="store_true"` and/or `action="store_false"`
(or in zerg, `action=toggle` which creates both in one step).
However, if you specify type `bool`, a few conventional values are
recognized.  zsh's conventional "False" value is the empty string: "", and
that counts as false (as it does if you specify type=bool for Python argparse).
For Python argparse, it seems that anything else counts as True.
For zerg, however, only these values are accepted:
   For True: 1 true yes on y
   For False: 0 false no off n ""

The `is_bool` function, unlike others, can take an additional parameter after
(the possible -q option and) the string to test. If that parameter is not
present then only 1 and "" are accepted; otherwise the additional values
just listed are also accepted. This will probably become a `--alts` option,
which seems cleaner.

===Floating-point types===

* `float` -- A floating-point decimal value, allowing exponential notation

* `prob` -- A `float` in the range from 0.0 to 1.0 (inclusive), as for a probability

* `logprob` -- A non-positive `float`, as for the logarithm of a probability


===String types===

Strings can also be affected by case-folding, whitespace normalization,
and having to match a given regular expression. Tests here tend to be loose,
so that only serious violations of the syntax are flagged (sometimes it would
be time-consuming to do much more). The distinct types are still useful for
making argument definitions more readable, and for being clear about the
intent. For example, `epoch` times are syntactically just floats, but
the intention communicated by declaraing it is quite distinct.

* `str` -- any string

* `char` -- a single character. Unicode characters beyond ASCII count correctly
as single characters, and combining characters do not count extra. For example,
LATIN SMALL LETTER E WITH ACUTE (U+e9) counts as a single character,
and so does the combination of LATIN SMALL LETTER E (U+65)
and COMBINING ACUTE ACCENT (U+301). The latter is accomplished via `wc -m`.

* `ident` -- a zsh identifier (not necessarily already in use).
Identifiers must start with an ASCII letter or underscore,
and may continue with more letters, digits, and/or underscores.

* `idents` -- one or more `ident` items, separated by whitespace.

* `argname` -- a typical command-line argument (option) name,
either a hyphen plus one letter, or two hyphens, a letter,
and perhaps continuing with more letters, digits, and/or underscores.
Both in Python argparse and in zerg, such names are converted for
use as destination variable names by dropping the leading hyphen(s)
and changing internal hyphens to underscores (in zerg, that result
is prefixed by the name of the parser that created them and "__" to
make the name of the associative array created to store the argument
definition (which, in turn, may be pointed to from multiple alias names
in one or more parsers).  See also `zerg_new` options `ignore-case`,
`ignore-hyphens`, `allow-abbrev`; and functions `zerg_add` and `zerg_use`.

* `cmdname` -- the name of a currently-available command. This includes
executables along PATH, aliases, builtins, and shell functions.

* `uident` -- a Unicode identifier token. The intent is to resemble
identifiers as in a programming language that support Unicode names,
but the rules are fairly loose.  TODO

* `uidents` -- one or more `utoken` items, separated by whitespace.  TODO

* `regex` -- an actual regex expression. Not to be confused with
a string *that matches* a particular expression.

* `path` -- a file, directory, or similar path as approriate to the
file system in effect. Checking is fairly loose. There are not
yet sub-types to distinguish the equivalent of paths that would match
zsh file-tests such as `-d -e -f -r -w -x`, or the useful case of
a file that may or may not exist, but could be written.

* `url` -- loose checking.

* `lang` -- a language code such as `en-us` (codes are
defined by ISO 639 and several RFCs, but not specifically checked here).

* `encoding` -- a character encoding scheme. This is checked via `iconv -l`,
which has a wide selection of names. All the names there consist of
uppercase ASCII letters, ASCII digits, hyphen, underscore, and occasional
[:.()+].

* `format` -- a single %-initial format code as understood by zsh `printf`.
There's a lot to these, and they're not quite the same as in C or Python.


===Enumerations===

Enumerations are handled as strings, with the values constrained to be
`token`s chosen from a list given on the `--choices` option to `add_argument`.
There are options to ignore case and/or to recognize abbreviations for these.


===Date and time types===

* time -- a time in ISO 8601 form: hh:mm:ss.
Leading zeroes are not required.
Fractional seconds can be added as .nnn.
A time zone offset can be addeded as "Z" (for UTC), or as a plus or minus
sign followed by hh:mm.

* date -- a date in ISO 8601 form: yyyy-mm-dd.

* datetime -- a date and time in ISO 8601 form (joimed by a "T").

* duration -- an amount of time. For the moment, this is merely a number
followed by one of s, m, h, or d for units. I expect to fix this to
support full ISO 8601 duration values, which start with `P` and then
continue with one or more number+unit parts, in descending order of size
(and with "T" to separate date-sized vs. time-sized parts):

    P[n]Y[n]M[n]DT[n]H[n]M[n]S

* epoch -- this is for a *nix "Epoch time", the number of seconds since
the start of 1970. Syntactically, this is just a `float`, so can represent
sub-second precision and dates prior to 1970 (although other issues arise
ranging from leap-seconds to the Gregorian calendar reform)_/


===Futures===

Other types may be added, such as the following (which could be useful for
helping with zsh auto-completion and Unicode among other things):

* [glob] -- a string that specifies a number of file-system objects, such as
`*/*.sh`.

* [command] -- the name of an existing executable command (including shell functions,
aliases, builtins, etc).

* [function] -- the name of an existing shell functions.

* [tensor] -- a tensor, as a list of `float`s to be grouped according to
a particular `shape`, which would also need to be specified.

* [complex] -- a complex number, in a form such as 3.14+1.618i (or perhaps "j"
on the end like Python).

* [pid] live?

* [host] numeric vs. named?

* [user] numeric vs named

* [group] numeric vs named

* [encoding] -- cf `iconv -l`

* [anychar], takes literal char or U+ codepoint or entity/char name

* xsd types? date portions, pos/neg/nonpos/nonneg int


==================================================== Earlier doc

There are types for integers in particular bases,
floats that must be valid probabilities or log probabilities;
strings with various constraints such as being single tokens, urls, etc.;
dates and times; and so on:

===Integers===
* `anyint`: Any of `int`, `hexint`, `octint`, or `binint`
* `binint`: A binary integer, like 0b00001111
* `hexint`: A hexdecimal integer, like 0xBEEF
* `int`: A decimal integer, such as 99 or -1. Leading zeros are permitted,
unlike with `octint`, where that's how it chooses octal vs. decimal.
* `octint`: An octal integer with a leading zero, like 0777.
The leading zero is required in hope of being less visualluy confusing.

===Non-integer numbers===
* `float`: A non-integer such as -3.14 or 6.0223E+23.
* `prob`: A probability value (from 0 to 1, inclusive)
* `logprob`: A log of a probability (from -1 to 0, inclusive)
* [`complex`]: Using syntax like -1.1+1.0i
* [`tensor`] is an expected addition, parameterized by a numpy-like "shape"
such as --type tensor(2,3).  TODO

The values in the tensor are (for the moment) taken to be floats.
The value is a single shell argument, but in fairly free
form (similar to numpy), such as any of these:
    --mat '[ [ 1 2 3], [ 4, 5, 6 ] ]'
    --mat '1 2 3; 4 5 6'
    --mat '1 2 3 4 5 6'
    --mat 1,2,3,4,5,6

===Booleans===
* `bool`: This accepts an explicit Boolean value following the option name as
the command line is parsed. It is more common to use the actions `store_true`
and `store_false` (and here, `toggle`) and options that require no following
value token.

The `is_bool` checker rejects any other values than:
    1|true|yes|on|y
    0|false|no|off|n|""

===Strings===
* `char`: A single Unicode character. Combining chars in Unicode don't count extra.
* `str`: Any string.
* `ident`: A series of one or more ASCII "word" characters (alphanumerics and _),
starting with a non-digit.
* [uident]: A Unicode `ident`, defined the same as XML's "NMtoken" type.  TODO
* `idents`: A series of one or more whitespace-separated `ident`s.
* [`uidents`]: A series of one or more whitespace-separated `UIDENT`s. TODO
* `path`: A *nix syntax path. This is pretty forgiving, so you can have .., ~,
paths to directories or files, existing or not, writable or not, etc.
This has options similar to zsh file-test flags (-d, -e, etc).
* `url`: Any url. The checking is pretty loose.
* `regex`: A regular expression per se (this is not for ensuring that the
value matches a particular regex; for that see the `pattern` option to `zerg_add`).


===Dates and times===

* `time`: An ISO 8601 standard time such as:

```
    12:01:59
    12:01:59Z
    23:59:59-5:00
```

Time+precision is not (yet) supported, such as ISO 8601 defines:

```
    [time]±[hh]:[mm]:[ss].[sss]
    [time]±[n]H[n]M[n]S
```

Suffixes such as "Z" and "-5:00" indicate time zones.

* `date`: An ISO 8601 standard date such as `2025-12-31`
The usual truncations, such as "2025-09", are supported.

* `datetime`: An ISO 8601 standard date and/or time, such as
`2025-10-19T00:00:00.000-5:00`.
The ISO 8601 formats are accepted by most software, and have the advantage
of easy sorting.

* [epoch]: A *nix-style "epoch" time (number of seconds since the start of 1970).
This is really just an float (usually positive, but no reason it has to be). The
special datatype is just there so you can be semantically clearer.

* [duration]: An amount of time, rather than a postion in time. This can
either be a raw number of seconds (such as the difference between 2 epoch times),
or the ISO 8601 format (which begins with "P" for "period"):

```
    P[n]Y[n]M[n]DT[n]H[n]M[n]S
```


===Unicode issues===

At present, identifiers are limited to zsh variable names: ASCII letters, digits, and underscore. `is_ident` checks for that (as `is_idents` checks for a
whitespace-separated list of such idents).

The values for `choices` options are limited the same way.

Options names are, too, except that it is permissible (and typical) to use
hyphen insted of underscore. Hyphens are changed to underscores to make
the (default) variable name under which an option definition is stored,
and the assoc key or variable name under which a parsed (or defaults) option value is stored.

There are separate parser options to control case treatment and abbreviation
support for options, and for choices values.

I expect to add a `uident` type for Unicode-inclusive identifiers, and
likely will support them for option and choices names too.

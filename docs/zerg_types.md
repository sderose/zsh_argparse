==Help on types in zerg==

This is mainly help for the values of the `--type` argument of `zerg_add`.
These types govern the strings users can specify on the command line,
for options of that particular type.

All this is set up via [zerg_types.sh] (which is one of the things called
by the more general [zerg_setup.sh]).

zerg's types serve the same purpose as values for the `type` argument of
Python's `argparse.add_argument`. They mean that a given string
*can be interpreted as* the given type.
So in argument parsing (whether in zsh or Python), saying `type=int` means the command line items must be a string that amounts to a decimal
integer, such as "64". zerg provides `--type int` with that same meaning.

Zerg also adds types that distinguish *string representation* of values,
such as `hexint` for a base-16 expression such as "0xA0". argparse could have
done this by using `int(arg, 0)` instead of just `int(arg)` internally,
but it doesn't (as of this writing). I consider
it common enough to just provide off-the-shelf (batteries, y'know).
Likewise, zerg's `octint` requires a base-8 value such as "0o100"
`binint` like "0b10110111", and `anyint` which allows any of the 4 bases.

In addition, there are convenience types for things like dates, times,
urls, pids, and some important mathematical types such as `prob`, `logprob`,
and `complex`. Tensors have rudimentary support, represented as whitespace
separated sequences of "(", ")", and floats.

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
a process not only exists, but is signalable.

Other functions provided by `zerg_types.sh`:

* `is_of_type [name] [string]` -- this is just another way to run the `is_`
function for the given zerg type name. Very handy if you have a type name
in a variable (such as in an EDDA object definition).

* `zerg_ord [char]` returns the numeric code point for the character

* `zerg_chr [int]` returns the literal Unicode character corresponding to a code point


==The types==


===Integer types===

* `int` -- a decimal integer, optionally signed

* `hexint` -- a hexadecimal integer like 0xFE01

* `octint` -- an octal integer like 0o777

* `binint` -- a binary integer like 0b10111110

* `anyint` -- an int in any of those forms

* `unsigned` -- a decimal integer with no sign prefix

* `pid` -- an active process ID. The `is_pid` test can also take
a `-a`- or `--active` option, to accept only active (signalable) processes.

The letters indicating base (b, o, and x) are recognized regardless of case.


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

* `complex` -- A complex number in a form such as -3.14+1.618i.
The trailing `i` can be any of [iIjJ].

* `tensor` -- Tensor is a recognized type, but specific shapes are not
checked. The type expects a string consisting of one or more whitespace
separated floats. The floats may also be grouped by parentheses, which
must (for now) also be whitespace separated.
The parentheses are checked for balance but not for uniform cardinalities.
For example:

( ( 1E-10 2 3 ) ( 4 5 6 ) ( 7 -8 9 ) )

or

( ( 0.110001 0.1234567891011 0.235711131719 0.412454033 )
  ( 0.57721 0.6180338 0.91596 1.839 )
  ( 1.3247 1.20205 1.6180338 2.502 )
  ( 2.685 2.71828 3.14159 4.669 6.28318) )


===String types===

"string" very often is used as a catch-all for other types, leaving important
constraints ignored. In zsh, most variables are technically strings even when
more accurate types are available; it's slightly easier to type `local n=1`
even when `local -i n=1` would be slightly safer and more precise. And
there are many cases like variable names, dates, language codes, and
countless "enums" that are highly constrained, not merely generic "strings".

Strings often also want special treatment such as case-folding, whitespace
normalization, and having to match a given regular expression.
zerg provides several subtypes of string, and the zerg argument parser
can be set up to handle case, pattern-matching, and so on.

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

* `uident` -- a Unicode identifier token. The intent is to resemble
identifiers as in a programming language that support Unicode names,
but the rules are fairly loose.

* `uidents` -- one or more `utoken` items, separated by whitespace.

* `argname` -- a typical command-line argument (option) name,
either a hyphen plus one letter; or two hyphens, a letter,
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
(namely undef, scalar, integer, float, array, or assoc -- see sv_type).

* `zergtypename` -- the name of a zerg-defined datatype.

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
identifier tokens chosen from a list given on the `--choices` option to `add_argument`.
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
ranging from leap-seconds to the Gregorian calendar reform).


===Futures===

(see also [TODO.md])

Other types may be added, such as the following (which could be useful for
helping with zsh auto-completion and Unicode among other things):

* units such as for *nix `units` command

* [glob] -- a string that specifies a number of file-system objects, such as
`*/*.sh`.

* [function] -- the name of an existing shell functions.

* [host] numeric vs. named?

* [user] numeric vs named

* [group] numeric vs named

* xsd types? date portions, pos/neg/nonpos int


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

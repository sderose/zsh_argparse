
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
* [`tensor`] is an expected addition, parameterized by a numpy-like "shape" such as
    --type tensor(2,3)
* [`complex`]: Using syntax like -1.1+1.0i

The values in the tensor are (for the moment) taken to be floats.
The value is a single shell argument, but in fairly free
form, such as any of these:
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
* `char`: A single Unicode character.
TODO: Do modifiers count?
* `str`: Any string.
* `ident`: A series of one or more ASCII "word" characters (alphanumerics and _),
starting with a non-digit.
* [uident]: A Unicode `ident`, defined the same as XML's "NMtoken" type.
* `idents`: A series of one or more whitespace-separated `ident`s.
* [`uidents`]: A series of one or more whitespace-separated `UIDENT`s.
* `path`: A *nix syntax path. This is pretty forgiving, so you can have .., ~,
paths to directories or files, existing or not, writable or not, etc.
* `url`: Any url. The checking is pretty loose.
* `regex`: A regular expression per se (this is not for ensuring that the
value matches a particular regex; forthat see the `pattern` option to `add_argument`).

    ** TODO: Exactly which version? Should there be types for glob, basic, and PCRE?

===Dates and times===

* `time`: An ISO 8601 standard time such as ("Z" and "-5:00" indicate time zones):

```
    12:01:59
    12:01:59Z
    23:59:59-5:00
```

* `date`: ISO 8601 standard date such as `2025-12-31`

* `datetime`: ISO 8601 standard date and/or time, such as
`2025-10-19T00:00:00.000-5:00`.
The ISO 8601 formats are accepted by most software, and have the advantage
of easy sorting.

* [epoch]: A *nix-style "epoch" time (number of seconds since the start of 1970).
This is really just an int (usually positive, but no reason it has to be). The
special datatype is just there so you can be semantically clearer.

* [duration]: An amount of time rather than a postion in time. This can
either be a raw number of seconds (such as the difference between 2 epoch times),
or the ISO 8601 format (which begins with "P" for "period"):

```
    P[n]Y[n]M[n]DT[n]H[n]M[n]S
```

The usual truncations, such as "2025-09", are supported.

Time+precision is not (yet) supported, such as ISO 8601 defines:

```
    [time]±[hh]:[mm]:[ss].[sss]
    [time]±[n]H[n]M[n]S
```

===Enums===

I expect to add `--choices "c1 c2 c3..."`, for values which are `uident`s.
I think they'll regard or ignore case in accord with how option names do,
or have a separate option of their own.

==Information on [zerg_setup.sh]==

zerg_setup provides some general functions needed by other parts of the
zerg library. It also defines several named return codes and their values.

===Trace and message support===

warn [n] [message] -- display the message to stderr if the message level (stored
in $ZERG_V) is at least as high as n. Also, it fills in a partial
traceback at the start of the message, for as many levels as $ZERG_TR.
If the message begins with "===", it will remove that but print a blank line,
a separator line, then the remainder of the message.

===General functions on shell variables ===

zsh_type [varname] -- echo the zsh datatype of the named shell variable,
as one of: undef, scalar, integer, float, array, assoc.
See also:  ${(t)name} or ${(tP)name}, which return a hyphen-separated list of
properties of a given variable. Typical use:
    if [[ `zsh_type path` == "undef" ]]; then...

zsh_quote [varname] --
echo the value of the named shell variable, escaped and quoted. Quoting
depends on the type

* undefined variable:
A message is displayed and RC is 1.

* integer and float variable, or string that passes is_int or is_float:
No quotes added.

* array:
Treat each member separately, quoting all strings (including ''),
but not numerics, and separating them by single spaces.
Parentheses are not added.

* associative array:
Like zsh, extract just the values (not the keys), in undefined order,
and treat them like an array (see above).

* scalar/string:
Put it in single quotes (unless it's a single token).
Backslash any internal single quotes and backslashes.

This uses zsh ${(qq)...}; zsh has ${(q)name} (and qq, qqq, and qqqq).


zsh_pack [varname] -- this is essentially the same as `typeset -p [varname]`.

str_escape [-f formatname] string
Escape the string as needed for the given format (default: html).
Options:
    -q | --quiet: Suppress error messages
    -f html: < to &lt;, & to &amp;, " to &quot;, and ]]> to ]]&gt;.
        This should suffice in content and in attribute values.
    -f xml: same as --html
    -f json: dquotes, backslashes, \n\r\t
    -f python: dquotes, backslashes, \n\r\t
    -f zsh: Use ${(q)}
    -f url: Various characters to UTF-8 and %xx encoding
    -- Mark end of options (say, if string to escape may start with "-")


===The "req_argc" test===

req_argc [min] [max] [have] -- used to test whether the number of
arguments to a shell function (typically passed as the [have] parameter
via "$#"), is at least [min] and at most [max].

It also prints a message unless given the `-q` option.
Typical use:

    req_argc 1 2 $# || return ZERR_ARGC


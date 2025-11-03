[aa_accessors.sh]

This file provides shell functions to help manage zsh associative arrays
when the array name is itself in a variable. This is possible in zsh without
these convenience functions, for example getting the value with ${(P)name}.
But not all operations are easy, some seem to require eval, and the
syntax required may not be the easiest to remember or predict. Therefore,
these functions, which largely mirror the methods on Python dicts:

* aa_set [varname] [membername] [value]

Sets the given member to the given value, in the associated array
named by `varname`.

* aa_get [-d default] [varname] [membername]

Retrieves the given member and echoes it to stdout. If the key is not
present in the associative array, but a default value is supplied via `-d`,
the default value is returned. See also `aa_get_abbrev`.

* aa_has [varname] [membername]

Returns code 0 if the member is in the associative array, else 1.

* aa_keys [varname]

Writes a space-separated list of keys to stdout.
TODO: Need to adding quoting for values that aren't single tokens.

* aa_values [varname]

Writes a space-separated list of values to stdout.
TODO: Need to adding quoting for values that aren't single tokens.

* aa_unset [varname] [membername]

Removes the given member via `unset`.

* aa_init [varname]

Create the named associative array if it doesn't exist already.
This does not clear data if the associative array already exists; for
that see `aa_clear`.

* aa_clear [varname]

Removes all items from the named associative array.

* aa_find_key [varname] [abbrev]

TODO: Don't like the return codes and global.

Searches the associative array for items whose names begin with `abbrev`.
If exactly one is found, its full name is saved in `_argparse_matched_key`
and the function returns with error code 1.
If none are found, returns code 0.
If more than one is found, the abbreviation is not unique, and it returns code 2.

* aa_get_abbrev [-d default] [varname] [abbrev]

Essentially like `aa_find_key`, but if a unique key is found it is sent to
stdout rather than stored in `_argparse_matched_key`. If no matching key is
present in the associative array, but a default value is supplied via `-d`,
the default value is returned. On failure such as an ambiguous key or a key
that is not found and there is not default,
an error message goes to stderr.

* aa_copy source_array target_array

Make `target_array` be an exact copy of `source_array`. `target_array` is created
or cleared if needed.

* aa_update target_array source_array

Copy values from the `source_array` to the `target_array`, whether they are
already there or not. Leave other members of `target_array` unchanged

* aa_setdefault [varname] [membername] [dftvalue]

Like `aa_set`, but only acts if the specified member does not already exist.
If it already exists it is left unchanged.

* aa_equals [varname1] [varname1]

Test whether the two associative arrays are equal. At least for now, this
test for exact equality; so if one array has an abbreviated key that they
other doesn't abbreviate the same, they don't match.

* aa_export -f [formatname] [varname]

Convert the named associative array to the specified alternate format, which
must be one of:

* `python` Python dict syntax: {'key': 'value', ...}

* `json` JSON object syntax: {"key": "value", ...}

* `html-table` HTML table with key/value columns

* `html-dl` HTML definition list

* `zsh` Form that can be passed to zsh "typeset", as produced by
${(q)key} and ${(qq)value}. For example

```
    ( [key]="value" [key2]="value2" )
```

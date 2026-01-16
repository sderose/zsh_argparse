[aa_accessors.sh]

This file provides shell functions to help manage zsh associative arrays
when the assoc name is itself in a variable. This is possible in zsh without
these convenience functions, for example getting the value with ${(P)name}.
But not all operations are easy, some seem to require eval, and the
syntax required may not be the easiest to remember or predict. Therefore,
these functions, which largely mirror the methods on Python dicts:

* aa_init [varname]

Create the named associative array if it doesn't exist already.
This does not clear data if the associative array already exists; for
that see `aa_clear`.

* aa_clear [varname]

Removes all items from the named associative array.

* aa_from_keys [--value v] dest_assoc_name source_array_name

Create an associative array with keys drawn from a regular array.
All keys get the value given on `--value` (default: 1), unless `--value '*'` is
specified, in which case each value will be set the same as its key.

* aa_from_string [--value v] [--sep s] dest_assoc_name string

Create an associative array with keys parsed from the string, by
splitting it on sep (default ' ') using ${(ps:$sep)$string}.
All keys get the value given on `-d`(default: 1), unless `-d '*'` is
specified, in which case each value will be set the same as its key.

* aa_set [varname] [key] [value]

Sets item with the given key to the given value, in the associated array
named by `varname`.

* aa_get [-d default] [varname] [key]

Retrieves the given key and echoes it to stdout. If the key is not
present in the associative array, but a default value is supplied via `-d`,
the default value is returned. See also `aa_get_abbrev`.

* aa_has [varname] [key]

Returns code 0 if the key is in the associative array, else 1.

* aa_keys [varname]

Writes a space-separated list of keys to stdout.

* aa_values [varname]

Writes a space-separated list of values to stdout.

* aa_unset [varname] [key]

Removes the item with the given via `unset`.

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

* aa_find_keys_by_value [options] [assoc_name] [val]

Find all keys in the named associative array whose value is val.
Return all such keys, separated by the --sep (default: space).

Options:
    -i|--ignore-case: case insensitive
    -q|--quiet: suppress messages
    --sep s: Separator in returned list.

* aa_copy source_assoc target_assoc

Make `target_assoc` be an exact copy of `source_assoc`. `target_assoc` is created
or cleared if needed.

* aa_update target_assoc source_assoc

Copy values from the `source_assoc` to the `target_assoc`, whether they are
already there or not. Leave other items of `target_assoc` unchanged.

* aa_setdefault [varname] [key] [dftvalue]

Like `aa_set`, but only acts if the specified item does not already exist.
If it already exists it is left unchanged.

* aa_equals [varname1] [varname1]

Test whether the two associative arrays are equal. At least for now, this
test for exact equality; so if one assoc has an abbreviated key that they
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

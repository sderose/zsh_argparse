==Information on compact syntax for defining zerg arguments==

The full syntax for zerg options uses `zerg_add` once for each argument,
and offers many features.

Simpler options can instead be declared directly in the `parser_new` command
that creates the parser.  For example:

```
    parser_new MYPARSER -- \
      'quiet|q:store_true[Reduce messages]' \
      'format:choice(xml,json,yaml)[Output format]' \
      'out:path=foo.log[Where to write results]'
```

Each declaration consists of:

* An "|"-separate list of names for the option. Hyphens are omitted; a single
hyphen is assumed for single-character names, and two hyphens for longer names.
As with a full declaration, the first name is considered the reference name.

* A colon followed by a zerg type or action, or by the keyword "choice" plus
a parenthesized , comma-separated list of identifier tokens as choices.

* Optionally, an equal-sign followed by a default value.

* Optionally, a square-bracketed help string.

* The whole argument should be quoted unless it happens to have no blanks
or other characters special to zsh.

The short syntax cannot specify options such as dest, fold, const, format,
metavar, nargs, pattern, or required.

Additional arguments can still be defined via the full `zerg_add`.

The short syntax is still experimental.


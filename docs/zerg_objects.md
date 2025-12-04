In zerg, an "object" is a zsh associative array with a non-empty value for
a particular "magic" key name. The value stored under that key should always
be a valid zsh identifier (see `is_ident`), and is the name of the class to
which that object belongs.

This is mainly useful so you can trivially identify such objects.

The magic key name is U+EDDA plus "_CLASS". It is available in variable
`$ZERG_CLASS_KEY`, or you can
set/get it using `zerg_set_class` and `zerg_get_class`.

Much like for zsh and zerg types, you can test whether a particular variable
is of a given object class:
    is_of_zsh_type assoc myVar
    is_of_zerg_type path -w myVar
    is_of_zerg_class PARSER myVar

Zerg does not impose any requirements for objects beyond that.
However, by convention:

* class names should be all upper case
* any keys beginning with the character U+EDDA (available as $'\uEDDA' or
in `$ZERG_CLASS_CHAR` are reserved for use by zerg (that should rarely be a pain).

zsh itself does not do anything special for "magic" items. If you
view or retrieve items from an assoc, they are just items like any
others (though you can easily filter them out by checking the first character).

If you wish, you can create a class definition for such a class.
It defines what keys may be used in objects of that class, and their types
and default values. This informs aa_set, aa_get, and other functions. As you
might expect, the class definition

    * is another zerg object
    * is of class 'CLASS_DEF'
    * is conventionally named `__CLASS__` plus the classname  (this is not required,
      but is probably useful for clarity).

A class definition contains an item for each permitted key, named the same
as the item it constrains.

The values of these items:

* must begin with a zerg typename
* may have following tokens for:
    * "?" for optional
    * "=" [value] for a default value
    * "=~" [regex] for a pattern values must match. enums may be achieved
      by giving a pattern like `(foo|bar|baz)`.
    * "<", "<=", ">", and/or ">=" followed by a numeric vake to constrain range
    * "U", "L", "W" to specify that the value should be folded to upper or lower
      case, or whitespace-normalized on storage (options for Unicode
      normalization may be added as well).
    * "%" [value] to give a %-string or command to format the value.
    * "!" to mean "final" -- once set, the value is not to be changed.
    * "@" the value should be localized (??? by adding "@" plus the locale name
      and returning that value when the item is retrieved)

Possible features:
    * Custom check functions
    * Repetition indicators
    * Parameterized types (like is_xxx with options -- pid, path, ...)
    * meta-keys like globs?

This is all unfinished.

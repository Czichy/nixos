# --- lib/misc.nix
#
# Author:  czichy <christian@czichy.com>
# URL:     https://github.com/czichy/tensorfiles
# License: MIT
#
# 888                                                .d888 d8b 888
# 888                                               d88P"  Y8P 888
# 888                                               888        888
# 888888 .d88b.  88888b.  .d8888b   .d88b.  888d888 888888 888 888  .d88b.  .d8888b
# 888   d8P  Y8b 888 "88b 88K      d88""88b 888P"   888    888 888 d8P  Y8b 88K
# 888   88888888 888  888 "Y8888b. 888  888 888     888    888 888 88888888 "Y8888b.
# Y88b. Y8b.     888  888      X88 Y88..88P 888     888    888 888 Y8b.          X88
#  "Y888 "Y8888  888  888  88888P'  "Y88P"  888     888    888 888  "Y8888   88888P'
{lib, ...}:
with lib;
with builtins;
with types; {
  # Counts how often each element occurrs in xs.
  # Elements must be strings.
  countOccurrences =
    foldl'
    (acc: x: acc // {${x} = (acc.${x} or 0) + 1;})
    {};

  # Returns all elements in xs that occur at least twice
  duplicates = xs: let
    occurrences = countOccurrences xs;
  in
    unique (filter (x: occurrences.${x} > 1) xs);

  # Concatenates all given attrsets as if calling a // b in order.
  concatAttrs = foldl' mergeAttrs {};

  # True if the path or string starts with /
  isAbsolutePath = x: substring 0 1 x == "/";

  # Merges all given attributes from the given attrsets using mkMerge.
  # Useful to merge several top-level configs in a module.
  mergeToplevelConfigs = keys: attrs:
    genAttrs keys (attr: mkMerge (map (x: x.${attr} or {}) attrs));

  # Calculates base^exp, but careful, this overflows for results > 2^62
  pow = base: exp: foldl' (a: x: x * a) 1 (genList (_: base) exp);

  hexLiteralValues = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
    "A" = 10;
    "B" = 11;
    "C" = 12;
    "D" = 13;
    "E" = 14;
    "F" = 15;
  };

  # Converts the given hex string to an integer. Only reliable for inputs in [0, 2^63),
  # after that the sign bit will overflow.
  hexToDec = v: foldl' (acc: x: acc * 16 + hexLiteralValues.${x}) 0 (stringToCharacters v);
}

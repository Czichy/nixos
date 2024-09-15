{lib, ...}:
with lib; let
  inherit (lib) lists mapAttrsToList filterAttrs hasSuffix;

  # filter files that have the .nix suffix
  filterNixFiles = k: v: v == "regular" && hasSuffix ".nix" k;

  # import files that are selected by filterNixFiles
  importNixFiles = path:
    (lists.forEach (mapAttrsToList (name: _: path + ("/" + name))
        (filterAttrs filterNixFiles (builtins.readDir path))))
    import;

  # return an int (1/0) based on boolean value
  # `boolToNum true` -> 1
  boolToNum = bool:
    if bool
    then 1
    else 0;

  # convert a list of integers to a list of string
  # `intListToStringList [1 2 3]` -> ["1" "2" "3"]
  intListToStringList = list: map (toString list);

  # a basic function to fetch a specified user's public keys from github .keys url
  # `fetchKeys "username` -> "ssh-rsa AAAA...== username@hostname"
  fetchKeys = username: (builtins.fetchurl "https://github.com/${username}.keys");

  # a helper function that checks if a list contains a list of given strings
  # `containsStrings { targetStrings = ["foo" "bar"]; list = ["foo" "bar" "baz"]; }` -> true
  containsStrings = {
    list,
    targetStrings,
  }:
    builtins.all (s: builtins.any (x: x == s) list) targetStrings;

  # indexOf is a function that returns the index of an element in a list
  # `indexOf ["foo" "bar" "baz"] "bar"` -> 1
  indexOf = list: elem: let
    f = f: i:
      if i == (builtins.length list)
      then null
      else if (builtins.elemAt list i) == elem
      then i
      else f f (i + 1);
  in
    f f 0;

  # Counts how often each element occurrs in xs.
  # Elements must be strings.
  countOccurrences =
    builtins.foldl'
    (acc: x: acc // {${x} = (acc.${x} or 0) + 1;})
    {};

  # Returns all elements in xs that occur at least twice
  duplicates = xs: let
    occurrences = countOccurrences xs;
  in
    unique (filter (x: occurrences.${x} > 1) xs);

  # Concatenates all given attrsets as if calling a // b in order.
  concatAttrs = builtins.foldl' mergeAttrs {};

  # True if the path or string starts with /
  isAbsolutePath = x: substring 0 1 x == "/";

  # Merges all given attributes from the given attrsets using mkMerge.
  # Useful to merge several top-level configs in a module.
  mergeToplevelConfigs = keys: attrs:
    genAttrs keys (attr: mkMerge (map (x: x.${attr} or {}) attrs));

  # Calculates base^exp, but careful, this overflows for results > 2^62
  pow = base: exp: builtins.foldl' (a: x: x * a) 1 (genList (_: base) exp);

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
  hexToDec = v: builtins.foldl' (acc: x: acc * 16 + hexLiteralValues.${x}) 0 (stringToCharacters v);
in {
  inherit filterNixFiles importNixFiles boolToNum fetchKeys containsStrings indexOf intListToStringList countOccurrences concatAttrs isAbsolutePath mergeToplevelConfigs pow hexLiteralValues hexToDec duplicates;
}

# --- lib/types.nix
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
  email = addCheck str (str: match "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+.[a-zA-Z]{2,}" str != null);

  # https://gist.github.com/duairc/5c9bb3c922e5d501a1edb9e7b3b845ba
  # Checks whether the value is a lazy value without causing
  # it's value to be evaluated
  isLazyValue = x: isAttrs x && x ? _lazyValue;
  # Constructs a lazy value holding the given value.
  lazyValue = value: {_lazyValue = value;};

  # Represents a lazy value of the given type, which
  # holds the actual value as an attrset like { _lazyValue = <actual value>; }.
  # This allows the option to be defined and filtered from a defintion
  # list without evaluating the value.
  lazyValueOf = type:
    mkOptionType rec {
      name = "lazyValueOf ${type.name}";
      inherit (type) description descriptionClass emptyValue getSubOptions getSubModules;
      check = isLazyValue;
      merge = loc: defs:
        assert assertMsg
        (all (x: type.check x._lazyValue) defs)
        "The option `${showOption loc}` is defined with a lazy value holding an invalid type";
          types.mergeOneOption loc defs;
      substSubModules = m: types.uniq (type.substSubModules m);
      functor = (types.defaultFunctor name) // {wrapped = type;};
      nestedTypes.elemType = type;
    };

  # Represents a value or lazy value of the given type that will
  # automatically be coerced to the given type when merged.
  lazyOf = type: types.coercedTo (lazyValueOf type) (x: x._lazyValue) type;
}

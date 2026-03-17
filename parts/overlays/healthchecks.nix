# Fix: healthchecks 4.0 + Django 5.2 – ping endpoint returns 500
#
# After `self.save()` with `F("n_pings") + 1`, self.n_pings is still an
# unresolved F-expression. Assigning it to `ping.n` (a different model)
# causes Django to try resolving "n_pings" in api_ping, which fails with
# FieldError → 500 on every ping.
#
# Fix: refresh_from_db to get the actual integer before creating the Ping.
# Upstream issue: https://github.com/healthchecks/healthchecks/issues/...
final: prev: {
  healthchecks = prev.healthchecks.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./patches/healthchecks-fix-n-pings.patch
    ];
  });
}

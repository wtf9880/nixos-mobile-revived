#
# “convenient” entry-point to refer to when needing a Nixpkgs.
#
# This is used both as a way to keep the existing code as-is,
# but also to ensure the trace for using the pinned Nixpkgs is used.
#
# The pinning is managed by `flake.lock`. Keeping this file means that
# `nix-build`, `nix-shell`, and existing `NIX_PATH` users keep working without
# having to evaluate the flake.
#
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  nixpkgs = lock.nodes.nixpkgs.locked;
  inherit (nixpkgs) owner repo rev narHash;

  channelName = lock.nodes.nixpkgs.original.ref or "nixpkgs";

  # Prefer `fetchTree` when it is available. It uses the same fetcher as the
  # flake input, which avoids cloning the entire Nixpkgs repository. Older Nix
  # versions (or evaluations without the `fetch-tree` feature) fall back to
  # `fetchGit`, which is slower on a cold cache but works without flakes.
  source =
    if builtins ? fetchTree then
      builtins.fetchTree nixpkgs
    else
      builtins.fetchGit {
        url = "https://github.com/${owner}/${repo}";
        inherit rev narHash;
      };

  sourcePath =
    if builtins.isAttrs source then source.outPath else source;
in
builtins.trace
  "(Using flake.lock Nixpkgs; ${channelName} @ ${builtins.substring 0 12 rev})"
  (import sourcePath)

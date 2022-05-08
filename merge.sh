#!/usr/bin/env bash

pushd "$(dirname "${0}")" || exit 1

registry_dir="$(pwd)"
registry_file=$registry_dir/flake-registry.json
registry_temp=$registry_dir/registry.json

curl -L https://github.com/NixOS/flake-registry/raw/master/flake-registry.json \
     > "$registry_file"

pushd .. || exit 1

jq --slurp '
   def is_github: .value.locked?.type == "github";
   def is_tarball: .value.locked?.type == "tarball";
   def from($id): { from: { $id, type: "indirect" } };
   def is_flake: .value?.flake != false;
   def is_owner($who): .value.locked?.owner == $who;
   def to_f4s: { to: { owner: "calbrecht", repo: "f4s", type: "github"} };
   def to_github: { to: (.value.locked | { owner, repo, type }
                  + (if has("dir") then { dir } else {} end ) )};
   def to_tarball: { to: (.value.locked | { url, type } )};
   ([.[0].locks.nodes | to_entries[]
    | select(is_flake and ((is_github and is_owner("calbrecht")) or is_tarball))
    | from("f4s-\(.key)")
      + (if is_github then to_github
         else if is_tarball then to_tarball else empty end
         end)
    ] + [ from("f4s") + to_f4s ]) as $flakes |
   .[1].flakes += $flakes |
   .[1]
' <(nix flake metadata ./ --json) "$registry_file" \
   > "$registry_temp" && mv "$registry_temp" "$registry_file"

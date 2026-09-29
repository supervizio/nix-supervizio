#!/usr/bin/env bash
# Mirror one supervizio channel from supervizio.github.io into this repository.
#
# Usage: .github/sync.sh <gentoo|nix> [--tag]
#
# supervizio's release pipeline publishes, at
# https://supervizio.github.io/agent/channels/, the Gentoo overlay and the Nix
# flake of the newest release its E2E installed through them: index.json names
# each channel's release tag, archive and sha256. This makes the checked-out
# repository hold exactly that archive's tree -- every file but .git and .github
# is replaced -- commits it as "chore(release): supervizio <tag>" and pushes.
# With --tag it also tags the commit <tag> (never moving an existing tag).
#
# Nothing published yet, a release that carries no such channel, or a tree
# already current: no commit, exit 0. An archive that does not match its
# sha256 (a deployment still propagating) fails, and the next run retries.
#
# Env: SUPERVIZIO_CHANNELS_URL overrides the base URL (tests).
set -euo pipefail

channel="${1:?usage: sync.sh <gentoo|nix> [--tag]}"
want_tag="${2:-}"
case "$channel" in gentoo|nix) ;; *) echo "::error::unknown channel '$channel'"; exit 2 ;; esac
case "$want_tag" in ''|--tag) ;; *) echo "::error::unknown option '$want_tag'"; exit 2 ;; esac
base="${SUPERVIZIO_CHANNELS_URL:-https://supervizio.github.io/agent/channels}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

code="$(curl -sS -L --retry 3 -o "$tmp/index.json" -w '%{http_code}' "$base/index.json")"
case "$code" in
  200) ;;
  404) echo "$base/index.json: not published yet, nothing to mirror"; exit 0 ;;
  *) echo "::error::$base/index.json answered HTTP $code"; exit 1 ;;
esac

tag="$(jq -r --arg c "$channel" '.[$c].tag // empty' "$tmp/index.json")"
if [ -z "$tag" ]; then
  echo "the published release carries no $channel channel: nothing to mirror"
  exit 0
fi
archive="$(jq -r --arg c "$channel" '.[$c].archive // empty' "$tmp/index.json")"
sum="$(jq -r --arg c "$channel" '.[$c].sha256 // empty' "$tmp/index.json")"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || { echo "::error::index.json: '$tag' is not a release tag"; exit 1; }
[[ "$archive" =~ ^[a-z0-9][a-z0-9.-]*\.tar\.gz$ ]] || { echo "::error::index.json: '$archive' is not an archive name"; exit 1; }
[[ "$sum" =~ ^[0-9a-f]{64}$ ]] || { echo "::error::index.json: '$sum' is not a sha256"; exit 1; }

curl -fsSL --retry 3 -o "$tmp/$archive" "$base/$archive"
if ! echo "$sum  $tmp/$archive" | sha256sum -c - >/dev/null 2>&1; then
  echo "::error::$archive does not match index.json's sha256 -- a deployment still propagating? The next run retries."
  exit 1
fi
mkdir "$tmp/tree"
tar -xzf "$tmp/$archive" -C "$tmp/tree"
if [ -e "$tmp/tree/.git" ] || [ -e "$tmp/tree/.github" ]; then
  echo "::error::$archive carries .git or .github, which are this repository's own"
  exit 1
fi

find . -mindepth 1 -maxdepth 1 ! -name .git ! -name .github -exec rm -rf {} +
cp -R "$tmp/tree/." .
git add --all

if git diff --cached --quiet; then
  echo "main already holds $tag's $channel channel"
else
  git -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit --quiet -m "chore(release): supervizio $tag"
  git push --quiet origin HEAD:refs/heads/main
  echo "main is now $tag ($(git rev-parse --short HEAD))"
fi

if [ "$want_tag" = --tag ]; then
  if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
    echo "tag $tag exists already, left where it is"
  else
    git tag "$tag"
    git push --quiet origin "refs/tags/$tag"
    echo "tagged $tag"
  fi
fi

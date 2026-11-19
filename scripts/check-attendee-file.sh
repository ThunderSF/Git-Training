#!/usr/bin/env bash
# Validates a workshop pull request.
#
# Usage: check-attendee-file.sh <base-sha> [head-ref]
#   base-sha  commit the pull request branches from (the diff base)
#   head-ref  what to check (default: HEAD)
#
# A pull request passes if it either:
#   1. changes only team-tips.md and leaves no merge conflict markers (conflict lab), or
#   2. adds exactly one properly named, fully filled-in file under attendees/.
set -euo pipefail

BASE="${1:?usage: check-attendee-file.sh <base-sha> [head-ref]}"
HEAD_REF="${2:-HEAD}"

fail() {
  echo "::error::$1"
  echo "FAILED: $1"
  exit 1
}

mapfile -d '' -t files < <(git diff -z --name-only --no-renames "$BASE" "$HEAD_REF")

[ "${#files[@]}" -gt 0 ] || fail "This pull request does not change any files."

# --- Conflict lab: team-tips.md only -------------------------------------
if [ "${#files[@]}" -eq 1 ] && [ "${files[0]}" = "team-tips.md" ]; then
  git cat-file -e "$HEAD_REF:team-tips.md" 2>/dev/null || fail "team-tips.md was deleted. Please restore it."
  if git show "$HEAD_REF:team-tips.md" | tr -d '\r' | grep -qE '^(<<<<<<<|=======|>>>>>>>)'; then
    fail "team-tips.md still contains merge conflict markers (<<<<<<<, =======, >>>>>>>). Resolve the conflict, then commit and push again."
  fi
  echo "OK: team-tips.md updated with no conflict markers."
  exit 0
fi

# --- First-contribution lab: exactly one attendee file --------------------
#if [ "${#files[@]}" -ne 1 ]; then
#  fail "Change exactly one file: your attendees/<your-name>.md profile. This pull request changes ${#files[@]} files: ${files[*]}"
#fi

file="${files[0]}"

[[ "$file" =~ ^attendees/[a-z0-9]+(-[a-z0-9]+)*\.md$ ]] \
  || fail "File '$file' must be named attendees/<first-last>.md using lowercase letters, numbers and hyphens (example: attendees/jane-doe.md)."

[ "$file" != "attendees/_template.md" ] \
  || fail "Do not edit the template. Copy it to attendees/<first-last>.md and edit your copy."

git cat-file -e "$HEAD_REF:$file" 2>/dev/null || fail "'$file' was deleted. This pull request should add a profile, not remove one."

# Strip Windows line endings so heading matches work for everyone.
content="$(git show "$HEAD_REF:$file" | tr -d '\r')"

for heading in "## Name" "## Role" "## Fun fact"; do
  grep -qxF "$heading" <<<"$content" || fail "'$file' is missing the heading '$heading'. Keep all three headings from the template."
done

if grep -q 'TODO' <<<"$content"; then
  fail "'$file' still contains TODO. Replace every TODO with your own text."
fi

echo "OK: $file looks good."

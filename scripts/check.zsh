#!/usr/bin/env zsh
# Validate the gwzcs completion collection.
#
# Usage:
#   zsh scripts/check.zsh
#
# The repository is intentionally zsh-only: no node, python, or other
# interpreter is used to inspect the completion files.

emulate -L zsh
setopt extendedglob nullglob

typeset -g ROOT=${0:A:h:h}
typeset -g FILES=$ROOT/files
typeset -g REG=$ROOT/registry.tsv
typeset -i failed=0
typeset -a entries
typeset -A meta
typeset -A registered

__fail() {
  print -r -- "FAIL: $*"
  failed=1
}

__ok() {
  print -r -- "ok: $*"
}

if [[ ! -d $FILES ]]; then
  __fail "missing files/ directory"
else
  typeset f base
  for f in "$FILES"/*(DN); do
    base=${f:t}
    [[ $base == .* ]] && continue
    if [[ -d $f ]]; then
      __fail "files/ must be flat; found directory: $base"
    elif [[ $base != _* ]]; then
      __fail "unexpected file in files/: $base"
    fi
  done
  __ok "files/ is flat"

  entries=( "$FILES"/_*(N) )
  for f in $entries; do
    base=${f:t}
    typeset cmd=${base#_}
    typeset first
    read -r first < "$f" || first=''

    if [[ $first != '#compdef '* ]]; then
      __fail "$base: first line is not #compdef"
    elif [[ " $first " != *" $cmd "* ]]; then
      __fail "$base: #compdef does not contain $cmd"
    fi

    zsh -n "$f" || __fail "$base: zsh -n failed"

    meta=()
    typeset key count
    for key in Schema Program Program-Version Completion-Source; do
      count=$(grep -cE "^# GWZCS-$key: " "$f")
      if (( count != 1 )); then
        __fail "$base: GWZCS-$key must appear exactly once (found $count)"
        continue
      fi
      meta[$key]=$(sed -nE "s/^# GWZCS-$key: (.*)$/\1/p" "$f")
    done

    if [[ ${meta[Schema]} != 1 ]]; then
      __fail "$base: GWZCS-Schema must be 1"
    fi
    if [[ ${meta[Program]} != $cmd ]]; then
      __fail "$base: GWZCS-Program must be $cmd"
    fi

    typeset version=${meta[Program-Version]}
    if [[ $version != (n/a|unknown) ]] &&
       ! print -r -- "$version" | grep -qE '^[A-Za-z0-9][A-Za-z0-9.+~_-]*$'; then
      __fail "$base: GWZCS-Program-Version must be one token, n/a, or unknown"
    fi

    case ${meta[Completion-Source]} in
      (ai)
        ;;
      (upstream)
        [[ $version == unknown ]] &&
          __fail "$base: upstream needs a concrete version or n/a"
        ;;
      (*)
        __fail "$base: GWZCS-Completion-Source must be ai or upstream"
        ;;
    esac

    if grep -qF "'\*" "$f"; then
      __fail "$base: escaped repeatable star; use '*--opt[...]'"
    fi

    if grep -nE '(_call_program[^#]*|\$\(|`)[[:space:]]*(node|python3?|perl|ruby|php|jq|deno|bun)([[:space:]]|$)' "$f" >/dev/null; then
      __fail "$base: interpreter dependency; use native zsh"
    fi
  done
fi

if [[ ! -f $REG ]]; then
  __fail "missing registry.tsv"
else
  typeset header=1
  while IFS=$'\t' read -r command source version level updated file; do
    if (( header )); then
      header=0
      continue
    fi
    [[ -z $command || $command == \#* ]] && continue

    if [[ -z $file ]]; then
      __fail "registry: missing file for '$command'"
      continue
    fi
    if [[ $file != ${file:t} || $file != _* ]]; then
      __fail "registry: file must be a flat _cmd name: $file"
      continue
    fi
    if [[ ! -f $FILES/$file ]]; then
      __fail "registry: no such file: files/$file"
      continue
    fi
    if [[ $file != _$command ]]; then
      __fail "registry: file '$file' does not match command '$command'"
    fi
    case $source in
      (ai|upstream)
        ;;
      (*)
        __fail "registry: source must be ai or upstream for '$command'"
        ;;
    esac
    registered[$file]=1
  done < "$REG"

  for f in $entries; do
    [[ -n ${registered[${f:t}]} ]] ||
      __fail "registry: missing row for ${f:t}"
  done
fi

if (( failed )); then
  print -r -- 'FAILED'
  exit 1
fi

print -r -- "OK: ${#entries} completion(s)"

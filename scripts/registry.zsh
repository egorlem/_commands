#!/usr/bin/env zsh
# Rebuild registry.tsv from the GWZCS metadata in files/_*.
#
# Usage:
#   zsh scripts/registry.zsh [--dry-run]
#
# Columns:
#   command  source  version  updated  file
#
# `updated` is preserved when command/source/version are unchanged; otherwise
# it is set to today. Rows for files that no longer exist are removed.

emulate -L zsh
setopt extendedglob nullglob

typeset -g SCRIPT_NAME=${0:t}
typeset -g ROOT=${0:A:h:h}
typeset -g FILES=$ROOT/files
typeset -g REG=$ROOT/registry.tsv
typeset -g TODAY=$(date +%F)
typeset -i dry=0
typeset -i failed=0
typeset -i added=0
typeset -i updated=0
typeset -i unchanged=0
typeset -i removed=0

typeset -A meta
typeset -A old_present old_command old_source old_version old_updated
typeset -A new_present
typeset -a files rows
typeset -a header cols

__usage() {
  print -u2 "usage: $SCRIPT_NAME [--dry-run]"
  print -u2 ""
  print -u2 "Rebuild registry.tsv from files/_* GWZCS metadata."
  print -u2 "  --dry-run   print the result instead of writing the file"
  return 2
}

__fail() {
  print -u2 "FAIL: $*"
  failed=1
}

while (( $# )); do
  case $1 in
    (--dry-run)
      dry=1
      ;;
    (-h|--help)
      __usage
      exit 0
      ;;
    (*)
      print -u2 "unknown option: $1"
      __usage
      exit 2
      ;;
  esac
  shift
done

if [[ ! -d $FILES ]]; then
  __fail "missing files/ directory"
  exit 1
fi

files=( "$FILES"/_*(N) )

# Read the existing registry so unchanged rows can keep their `updated` date.
# Both the old 6-column layout (with `level`) and the current 5-column layout
# are accepted; `level` is ignored on input and never written back.
if [[ -f $REG ]]; then
  IFS=$'\t' read -r -A header < "$REG" || header=()
  typeset -i i_command=0 i_source=0 i_version=0 i_updated=0 i_file=0 i
  for (( i = 1; i <= ${#header}; i++ )); do
    case ${header[i]} in
      (command) i_command=$i ;;
      (source) i_source=$i ;;
      (version) i_version=$i ;;
      (updated) i_updated=$i ;;
      (file) i_file=$i ;;
    esac
  done

  if (( !i_command || !i_source || !i_version || !i_updated || !i_file )); then
    __fail "registry.tsv: missing one of command/source/version/updated/file"
  else
    typeset -i first=1
    while IFS=$'\t' read -r -A cols; do
      if (( first )); then
        first=0
        continue
      fi
      (( ${#cols} == 0 )) && continue
      local_file=${cols[i_file]:-}
      [[ -z $local_file ]] && continue
      old_present[$local_file]=1
      old_command[$local_file]=${cols[i_command]:-}
      old_source[$local_file]=${cols[i_source]:-}
      old_version[$local_file]=${cols[i_version]:-}
      old_updated[$local_file]=${cols[i_updated]:-}
    done < "$REG"
  fi
fi

for f in $files; do
  base=${f:t}
  cmd=${base#_}
  typeset first_line
  read -r first_line < "$f" || first_line=''

  if [[ $first_line != '#compdef '* ]]; then
    __fail "$base: first line is not #compdef"
  elif [[ " $first_line " != *" $cmd "* ]]; then
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

  [[ ${meta[Schema]} == 1 ]] ||
    __fail "$base: GWZCS-Schema must be 1"
  [[ ${meta[Program]} == $cmd ]] ||
    __fail "$base: GWZCS-Program must be $cmd"

  source=${meta[Completion-Source]}
  version=${meta[Program-Version]}
  if [[ $version != (n/a|unknown) ]] &&
     ! print -r -- "$version" | grep -qE '^[A-Za-z0-9][A-Za-z0-9.+~_-]*$'; then
    __fail "$base: GWZCS-Program-Version must be one token, n/a, or unknown"
  fi
  case $source in
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

  typeset updated_date=$TODAY
  if [[ -n ${old_present[$base]:-} ]]; then
    if [[ ${old_command[$base]:-} == $cmd &&
          ${old_source[$base]:-} == $source &&
          ${old_version[$base]:-} == $version &&
          -n ${old_updated[$base]:-} ]]; then
      updated_date=${old_updated[$base]}
      (( unchanged++ ))
    else
      (( updated++ ))
    fi
  else
    (( added++ ))
  fi

  new_present[$base]=1
  rows+=( "$cmd"$'\t'"$source"$'\t'"$version"$'\t'"$updated_date"$'\t'"$base" )
done

for base in ${(k)old_present}; do
  [[ -n ${new_present[$base]:-} ]] || (( removed++ ))
done

if (( failed )); then
  print -u2 'FAILED'
  exit 1
fi

rows=( "${(@o)rows}" )

__print_registry() {
  print -r -- $'command\tsource\tversion\tupdated\tfile'
  (( ${#rows} )) && print -r -- "${rows[@]}"
}

if (( dry )); then
  __print_registry
else
  typeset tmp="$REG.tmp.$$"
  trap 'rm -f -- "$tmp"' EXIT
  __print_registry > "$tmp"
  mv -- "$tmp" "$REG"
  trap - EXIT
fi

print -u2 "registry: ${#rows} completion(s), +$added ~$updated =$unchanged -$removed"

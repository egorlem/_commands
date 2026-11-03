# gwzcs

Personal, public collection of native zsh completion functions (`_command`)
for CLI tools.

Generated and reviewed with
[gwz-zsh-completions](https://github.com/egorlem/gwz-agent-skills/tree/master/gwz-zsh-completions).

## Install

```zsh
git clone https://github.com/egorlem/gwzcs ~/.zsh/gwzcs
fpath=(~/.zsh/gwzcs/files $fpath)
autoload -Uz compinit && compinit
```

`files/` is a flat `fpath` entry. `compinit` does not recurse into
subdirectories, so every `_cmd` file must sit directly in `files/`.

`files/.gitkeep` only keeps the empty directory in Git; zsh ignores it.

## Layout

```text
gwzcs/
├── files/          # fpath target: only flat _cmd completion functions
├── registry.tsv    # command, source, version, updated, file
├── scripts/
│   ├── check.zsh   # zsh-only validation
│   └── registry.zsh # rebuild registry.tsv from artifacts
├── .github/workflows/validate.yml
├── README.md
└── LICENSE
```

## Add a completion

1. Put `_cmd` into `files/`.
2. Rebuild the index:

   ```zsh
   zsh scripts/registry.zsh
   ```

3. Check:

   ```zsh
   zsh scripts/check.zsh
   ```

4. Commit only after the check passes.

## Registry

`registry.tsv` is tab-separated:

```text
command	source	version	updated	file
```

- `command` — CLI name;
- `source` — `ai` or `upstream`;
- `version` — CLI version (`unknown`/`n/a` allowed);
- `updated` — `YYYY-MM-DD`;
- `file` — file in `files/`.

`scripts/registry.zsh` rebuilds this file from the `GWZCS-*` headers. It keeps
`updated` for unchanged rows, sets today's date when source/version change, and
drops rows whose file is gone. `--dry-run` prints the result without writing.

## Validation

`scripts/check.zsh` checks:

- `files/` is flat and contains only `_cmd` files;
- `#compdef` matches the file name;
- `zsh -n` passes;
- `GWZCS-*` metadata is present and consistent;
- no escaped repeatable `\*`;
- no interpreter invocation (`node`, `python`, `jq`, …);
- every completion has a registry row and vice versa;
- registry source/version match the artifact metadata.

CI runs the same script on every push and pull request.

## License

WTFPL, see [LICENSE](LICENSE).

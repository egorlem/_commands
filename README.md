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
├── registry.tsv    # command, source, version, level, updated, file
├── scripts/
│   └── check.zsh   # zsh-only validation
├── .github/workflows/validate.yml
├── README.md
└── LICENSE
```

## Add a completion

1. Put `_cmd` into `files/`.
2. Add a row to `registry.tsv`.
3. Run:

   ```zsh
   zsh scripts/check.zsh
   ```

4. Commit only after the check passes.

## Registry

`registry.tsv` is tab-separated:

```text
command	source	version	level	updated	file
```

- `command` — CLI name;
- `source` — `ai` or `upstream`;
- `version` — CLI version (`unknown`/`n/a` allowed);
- `level` — verification level reached (`l1-l2` or `l1-l2-l3`);
- `updated` — `YYYY-MM-DD`;
- `file` — file in `files/`.

## Validation

`scripts/check.zsh` checks:

- `files/` is flat and contains only `_cmd` files;
- `#compdef` matches the file name;
- `zsh -n` passes;
- `GWZCS-*` metadata is present and consistent;
- no escaped repeatable `\*`;
- no interpreter invocation (`node`, `python`, `jq`, …);
- every completion has a registry row and vice versa.

CI runs the same script on every push and pull request.

## License

WTFPL, see [LICENSE](LICENSE).

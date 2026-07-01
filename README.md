This repository contains pre-commit hooks for running `just --fmt` on any
discovered [just](https://github.com/casey/just) files.

Two hooks are provided:

- `format-justfile` — auto-formats justfiles in place (and fails so pre-commit
  reports the change).
- `check-justfile` — verifies justfiles are formatted and valid without
  modifying them, failing with `just`'s own error (e.g. a formatting diff or a
  parse error such as "Extraneous attribute"). Prefer this in CI or when you'd
  rather be told what's wrong than have files rewritten mid-commit.

## Usage

You must have `just` installed on your system for these hooks to work. If it
isn't found, the hooks no-op so they don't block commits on machines without
`just`.

```yaml
- repo: https://github.com/instrumentl/pre-commit-just
  rev: 'main'
  hooks:
    - id: check-justfile
    # or, to auto-format instead of failing:
    # - id: format-justfile
```

## License

This work is licensed under the ISC license, a copy of which can be found at [LICENSE.txt](LICENSE.txt).

`just` itself is licensed under the CC0 license.

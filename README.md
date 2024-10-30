This repository contains a pre-commit config for running `just --fmt` on any
discovered [just](https://github.com/casey/just) files. It will auto-fix the
files.

## Usage

You must have `just` installed on your system for this hook to work.

```yaml
- repo: https://github.com/instrumentl/pre-commit-just.git
  rev: 'main'
  hooks:
    - id: format-justfile
```

## License

This work is licensed under the ISC license, a copy of which can be found at [LICENSE.txt](LICENSE.txt).

`just` itself is licensed under the CC0 license.

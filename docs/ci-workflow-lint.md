# CI workflow static lint — transcript

`.github/workflows/R-CMD-check.yaml` was committed on 2026-07-31 without ever running, because
the repository has had no reachable remote since 2026-07-20. **Checked with actionlint 1.7.12 on
2026-07-31: zero problems, exit status 0.** The three judgement calls actionlint cannot make were
then resolved against the `r-lib/actions` sources rather than from memory, and **all three are
correct as written — no change was made to the workflow.** This is static evidence only. It says
the workflow is well-formed and that its inputs mean what the file assumes they mean; it does not
say a run will pass.

## `http-user-agent` on only the r-devel row

The matrix sets `http-user-agent: 'release'` on the `ubuntu-latest` / `devel` row and omits the key
on the other five, while the `setup-r` step passes `http-user-agent: ${{ matrix.config.http-user-agent }}`
unconditionally. On the five rows without the key that expression evaluates to the empty string.
`setup-r`'s own input documentation covers exactly that case: it says the value is used `'If
"default" or "", sets the HTTPUserAgent option to e.g. for R 3.6.3 running on macOS Catalina […]'`,
with `default: 'default'`. So `""` and `"default"` are documented as the same behavior, and it does
not matter whether the runner supplies the declared default or the empty string — both land on the
same branch. The key is optional, not required, and an empty value is handled rather than tolerated
by accident.

This is also not a local invention. `r-lib/actions`' own `examples/check-standard.yaml` uses the
identical shape, with `http-user-agent: 'release'` present on the `devel` row alone and the same
unconditional `${{ matrix.config.http-user-agent }}` reference.

## `needs: lint` in the verify job

`setup-r-dependencies` composes `needs` into DESCRIPTION field names. Its `README.md` describes the
input as "`Config/Needs` fields to install from the DESCRIPTION, the `Config/Needs/` prefix will be
automatically included", and the action's Query-dependencies step does that literally:

```r
needs <- sprintf("Config/Needs/%s", strsplit("${{ inputs.needs }}", "[[:space:],]+")[[1]])
if (length(needs) == 0L) needs <- NULL
pak::lockfile_create(c(deps, extra_deps), dependencies = c(needs, (${{ inputs.dependencies }})), ...)
```

`raddr`'s DESCRIPTION carries only `Config/testthat/edition` and `Config/roxygen2/version`, so
`needs: lint` expands to a `Config/Needs/lint` field that does not exist and contributes no
packages. It is inert. It is kept because it is the canonical shape: `r-lib/actions`'
`examples/lint.yaml` pairs `extra-packages: any::lintr, local::.` with `needs: lint` for a package
that need not declare the field either.

What actually installs the two packages is the other half of the step. `extra-packages: any::lintr,
any::spelling` names both explicitly, and the `dependencies` input defaults to `"all"`, which
pkgdepends documents as being "replaced by all hard and soft dependency" types — so spelling would
arrive from `Suggests` even if it were not named. The spelling-in-`Suggests` question is answered by
that default, not by `needs`. The verify job also omits the `local::.` reference the canonical lint
example carries; that is deliberate, since `lintr::lint_package()` and
`spelling::spell_check_package()` both read the source tree and neither requires `raddr` itself to
be installed.

## `--no-manual` in CI but not in the local hook

The pre-push hook runs `rcmdcheck::rcmdcheck(args = "--as-cran", error_on = "warning")`, while the
workflow passes `args: 'c("--no-manual", "--as-cran")'`. The difference is deliberate and it is not
even a local choice: `c("--no-manual", "--as-cran")` is `check-r-package`'s own declared default for
`args`, and its `build_args` default is `"--no-manual"` as well. Writing it out makes the value
visible instead of implied.

The reason is the usual one. The GitHub-hosted runners carry no LaTeX toolchain, so building the PDF
reference manual would need one installed on all six matrix rows to check typesetting this package
does not depend on. The coverage lost is a strict subset and it is covered twice over elsewhere: the
local gate does build the manual, and CRAN's incoming checks build it too. The R 4.0.0 floor
transcript in `docs/r-floor-check.md` records the same `--no-manual --as-cran` options for the same
reason, so this is the project's established position rather than a new one.

## Invocation

```
$ actionlint --version
1.7.12
installed from Homebrew
built with go1.26.3 compiler for darwin/arm64

$ actionlint .github/workflows/R-CMD-check.yaml
$ echo $?
0
```

actionlint prints one line per problem and nothing at all when there are none, so the empty output
above is the result.

## Environment

```
R version 4.0.0 (2020-04-24)
platform: x86_64-pc-linux-gnu
base image:   raddr-rfloor:4.0.0
vctrs target: 0.7.0  (the floor DESCRIPTION declares)

Both the R version and the vctrs version sit at their declared floors, so
a failure below does not attribute to either one alone. See the header of
data-raw/check-dep-floor.sh for the fallback run that separates them.

base64enc 0.1-3
BH 1.87.0-1
bignum 0.3.2
bit 4.6.0
bit64 4.6.0-1
brio 1.1.5
bslib 0.9.0
cachem 1.1.0
callr 3.7.6
cli 3.6.5
commonmark 2.0.0
cpp11 0.5.2
crayon 1.5.3
desc 1.4.3
diffobj 0.3.6
digest 0.6.37
docopt 0.6.1
evaluate 1.0.5
fastmap 1.2.0
fontawesome 0.5.3
fs 1.6.6
glue 1.8.0
hedgehog 0.1
highr 0.11
htmltools 0.5.8.1
hunspell 3.0.6
jquerylib 0.1.4
jsonlite 2.0.0
knitr 1.50
lifecycle 1.0.4
littler 0.3.10
magrittr 2.0.4
memoise 2.0.1
mime 0.13
pkgbuild 1.4.8
pkgload 1.4.1
praise 1.0.0
processx 3.8.6
ps 1.9.1
R6 2.6.1
rappdirs 0.3.3
Rcpp 1.1.0
rlang 1.1.7
rmarkdown 2.30
rprojroot 2.1.1
sass 0.4.10
spelling 2.3.2
testthat 3.2.3
tinytex 0.57
vctrs 0.7.0
waldo 0.6.2
withr 3.0.2
xfun 0.54
xml2 1.4.1
yaml 2.3.10
```

## What the declared floors actually resolve to

```
vctrs installed:      0.7.0
vctrs Imports:        cli (>= 3.4.0), glue, lifecycle (>= 1.0.3), rlang (>= 1.1.7)
vctrs Depends:        R (>= 4.0.0)
rlang installed:      1.1.7

raddr imports from rlang: abort, arg_match0, is_string (NAMESPACE).
raddr DESCRIPTION declares no rlang floor, so the number above is
inherited from vctrs rather than asserted by raddr.
```

## R CMD build

```
* checking for file ‘./DESCRIPTION’ ... OK
* preparing ‘raddr’:
* checking DESCRIPTION meta-information ... OK
* installing the package to build vignettes
* creating vignettes ... OK
* checking for LF line-endings in source and make files and shell scripts
* checking for empty or unneeded directories
Removed empty directory ‘raddr/tests/testthat/_snaps’
* looking to see if a ‘data/datalist’ file should be added
* building ‘raddr_0.1.1.tar.gz’

```

## R CMD check --as-cran

```
* using log directory ‘/work/raddr.Rcheck’
* using R version 4.0.0 (2020-04-24)
* using platform: x86_64-pc-linux-gnu (64-bit)
* using session charset: UTF-8
* using options ‘--no-manual --as-cran’
* checking for file ‘raddr/DESCRIPTION’ ... OK
* checking extension type ... Package
* this is package ‘raddr’ version ‘0.1.1’
* package encoding: UTF-8
* checking package namespace information ... OK
* checking package dependencies ... OK
* checking if this is a source package ... OK
* checking if there is a namespace ... OK
* checking for executable files ... OK
* checking for hidden files and directories ... OK
* checking for portable file names ... OK
* checking for sufficient/correct file permissions ... OK
* checking whether package ‘raddr’ can be installed ... OK
* checking installed package size ... OK
* checking package directory ... OK
* checking for future file timestamps ... OK
* checking ‘build’ directory ... OK
* checking DESCRIPTION meta-information ... OK
* checking top-level files ... OK
* checking for left-over files ... OK
* checking index information ... OK
* checking package subdirectories ... OK
* checking R files for non-ASCII characters ... OK
* checking R files for syntax errors ... OK
* checking whether the package can be loaded ... OK
* checking whether the package can be loaded with stated dependencies ... OK
* checking whether the package can be unloaded cleanly ... OK
* checking whether the namespace can be loaded with stated dependencies ... OK
* checking whether the namespace can be unloaded cleanly ... OK
* checking loading without being on the library search path ... OK
* checking dependencies in R code ... OK
* checking S3 generic/method consistency ... OK
* checking replacement functions ... OK
* checking foreign function calls ... OK
* checking R code for possible problems ... OK
* checking Rd files ... OK
* checking Rd metadata ... OK
* checking Rd line widths ... OK
* checking Rd cross-references ... OK
* checking for missing documentation entries ... OK
* checking for code/documentation mismatches ... OK
* checking Rd \usage sections ... OK
* checking Rd contents ... OK
* checking for unstated dependencies in examples ... OK
* checking R/sysdata.rda ... OK
* checking installed files from ‘inst/doc’ ... OK
* checking files in ‘vignettes’ ... OK
* checking examples ... OK
* checking for unstated dependencies in ‘tests’ ... OK
* checking tests ...
  Running ‘spelling.R’
  Running ‘testthat.R’ [25s/22s]
 OK
* checking for unstated dependencies in vignettes ... OK
* checking package vignettes in ‘inst/doc’ ... OK
* checking re-building of vignette outputs ... OK
* checking for non-standard things in the check directory ... OK
* checking for detritus in the temp directory ... OK
* DONE

Status: OK

```

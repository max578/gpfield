
<!-- README.md is generated from README.Rmd. Please edit that file. -->

# gpfield

`gpfield` is the spatial member of an agricultural-analytics R-package
orchestra. It does change-of-support Gaussian-process regression for
field and multi-environment-trial (MET) data: it smooths a noisy field
surface, predicts at a support different from the one observed (a point
process predicted as paddock-scale block averages, with the predictive
variance propagated through the support map), and – the part that
matters in practice – abstains honestly when the data support or the
estimated spatial range cannot bear the requested prediction resolution,
rather than returning a confident wrong surface.

The Gaussian process is a self-contained exact solver in base R, so the
package takes no heavy external GP dependency and installs and checks
anywhere.

## Installation

``` r
# install.packages("remotes")
remotes::install_github("max578/gpfield")
```

## What it does

- **Fit** an exact spatial (or spatio-temporal) GP with a
  squared-exponential or `Matern` covariance, hyperparameters estimated
  by marginal likelihood.
- **Change of support** – predict block (areal) averages from point
  observations, with within-block correlation propagated into the
  predictive variance, not averaged away.
- **Honest abstention** – a typed refusal with a machine-readable reason
  when the range or support cannot bear the request.
- **MET smoothing** – one call from a row-column trial layout to a
  smoothed surface.
- **Orchestra manifest** – emit a result in the federation’s shared,
  versioned, integrity-hashed contract so it composes with the other
  members.

## A minimal example

``` r
library(gpfield)

# A noisy field on a 10 x 10 plot grid.
set.seed(1L)
field <- expand.grid(row = seq_len(10L), col = seq_len(10L))
field$yield <- 3 + 0.3 * field$row + sin(field$col / 2) +
  rnorm(nrow(field), 0, 0.2)

# Fit the GP.
fit <- gp_fit(gpfield_spec(c("row", "col"), "yield"), field, seed = 1L)
fit
#> <gpfield_fit>
#>   kernel:      matern
#>   n training:  100
#>   length-scale (standardised): 4.34
#>   marginal var / noise var:    3.317 / 0.02171
#>   range (raw units):           12.53
#>   log marginal likelihood:     10.6

# Predict two paddock-scale block averages (change of support).
blocks <- block_support(
  lower = rbind(c(1, 1), c(6, 6)),
  upper = rbind(c(5, 5), c(10, 10))
)
gp_predict(fit, support = "block", blocks = blocks, seed = 1L)
#> <gpfield_prediction>
#>   support:   block
#>   locations: 2
#>   mean range: [4.732, 4.784]
#>   sd range:   [0.04048, 0.04168]

# Ask for a resolution the field cannot support: gpfield abstains.
gp_predict(fit, data.frame(row = c(1, 60), col = c(1, 60)))
#> $reason
#> [1] "range_too_short"
#> 
#> $detail
#> [1] "query spacing 83.44 exceeds 1 x the estimated range 12.53; the field cannot be resolved this finely"
#> 
#> $scope
#> [1] "gp_predict"
#> 
#> $diagnostics
#> $diagnostics$spacing
#> [1] 83.4386
#> 
#> $diagnostics$range
#> [1] 12.52809
#> 
#> $diagnostics$spacing_tol
#> [1] 1
#> 
#> 
#> $abstained
#> [1] TRUE
#> 
#> attr(,"class")
#> [1] "gpfield_abstention"
```

## Licence

MIT (c) 2026 Max Moldovan. The orchestra is open-source across the
board.

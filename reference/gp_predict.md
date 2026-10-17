# Predict a gpfield surface, optionally at a different support

The package's central verb. Given a fitted GP, predicts the latent field
at the requested locations and, critically, at the requested support.
With `support = "point"` (default) the result is the GP posterior mean
and standard deviation at each query point. With `support = "block"` the
result is the change-of-support prediction: each block's value is the
integral of the latent field over the block, and its predictive standard
deviation is computed from the full within-block posterior covariance so
spatial correlation is propagated, not averaged away.

## Usage

``` r
gp_predict(
  fit,
  newdata = NULL,
  support = c("point", "block"),
  blocks = NULL,
  min_support_ranges = 1,
  spacing_tol = 1,
  seed = NULL
)
```

## Arguments

- fit:

  A `gpfield_fit` from
  [`gp_fit()`](https://max578.github.io/gpfield/reference/gp_fit.md).

- newdata:

  For point support, a `data.frame` of query coordinates with the fit's
  coordinate (and time) columns. Ignored when `support = "block"`.

- support:

  Character: `"point"` (default) or `"block"`. Block support requires
  `blocks`.

- blocks:

  A `gpfield_block_support` from
  [`block_support()`](https://max578.github.io/gpfield/reference/block_support.md),
  required when `support = "block"`.

- min_support_ranges:

  Numeric, block support only: a block must have at least one training
  observation within this many correlation ranges of its footprint, else
  the verb abstains. Default `1`. Ignored (with a warning) at point
  support.

- spacing_tol:

  Numeric, point support only: the point grid's spacing may be at most
  this multiple of the estimated range before the verb abstains with
  `"range_too_short"`. Default `1` (spacing may not exceed the range).
  Ignored (with a warning) at block support.

- seed:

  Retained for backward compatibility. Block quadrature is now
  deterministic (a tensor grid, not Monte-Carlo draws), so a block
  prediction is reproducible without a seed and never perturbs the
  caller's random stream; this argument no longer affects the result.

## Value

A `gpfield_prediction` S7 object on success, or a
[`gpfield_abstention()`](https://max578.github.io/gpfield/reference/gpfield_abstention.md)
when the support cannot bear the request.

## Details

Honest abstention runs before any value is returned. If the estimated
correlation range is shorter than the requested point spacing – so the
query grid asks the GP to interpolate between effectively independent
observations – the verb returns a
[`gpfield_abstention()`](https://max578.github.io/gpfield/reference/gpfield_abstention.md)
with reason `"range_too_short"`. If a requested block has no training
observation within one correlation range of its footprint, the verb
abstains with reason `"support_gap"`. An empty query abstains with
`"empty_query"`. The rule errs toward refusing a confident wrong surface
over emitting one.

## See also

[`gp_fit()`](https://max578.github.io/gpfield/reference/gp_fit.md),
[`block_support()`](https://max578.github.io/gpfield/reference/block_support.md),
[`gp_field_smooth()`](https://max578.github.io/gpfield/reference/gp_field_smooth.md)

## Examples

``` r
set.seed(1L)
grid <- expand.grid(x = seq_len(10L), y = seq_len(10L))
grid$yield <- 2 + 0.25 * grid$x + 0.1 * grid$y +
  stats::rnorm(nrow(grid), 0, 0.2)
fit <- gp_fit(gpfield_spec(c("x", "y"), "yield"), grid, seed = 1L)

# Point prediction on a fine grid.
q <- expand.grid(x = seq(1, 10, by = 1), y = seq(1, 10, by = 1))
pt <- gp_predict(fit, q)

# Change of support: two paddock-scale block averages.
bl <- block_support(lower = rbind(c(1, 1), c(6, 6)),
                    upper = rbind(c(5, 5), c(10, 10)))
blk <- gp_predict(fit, support = "block", blocks = bl, seed = 1L)
blk
#> <gpfield_prediction>
#>   support:   block
#>   locations: 2
#>   mean range: [3.06, 4.804]
#>   sd range:   [0.03273, 0.03273]
```

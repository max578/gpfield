# Describe a block (areal) support for change-of-support prediction

Defines one or more blocks over which the latent field is to be
integrated to a block average – the paddock-scale change-of-support
target. Blocks are axis-aligned rectangles (a row of lower / upper
bounds per coordinate axis); irregular or polygonal footprints are a
planned extension, not supported here. The prediction integrates the GP
posterior over each block by deterministic quadrature and propagates the
full within-block covariance into the block average's predictive
variance.

## Usage

``` r
block_support(lower, upper, ids = NULL, n_quad = 200L)
```

## Arguments

- lower:

  Numeric matrix or data frame, one row per block, columns aligned to
  the fit's spatial coordinate axes, holding each block's lower bounds.

- upper:

  As `lower`, holding the upper bounds.

- ids:

  Optional character block identifiers (default `"block1"`, ...).

- n_quad:

  Integer target number of quadrature points per block (default `200`),
  realised as the nearest tensor grid of axis midpoints.

## Value

A `gpfield_block_support` classed list consumed by
[`gp_predict()`](https://max578.github.io/gpfield/reference/gp_predict.md).

## See also

[`gp_predict()`](https://max578.github.io/gpfield/reference/gp_predict.md)

## Examples

``` r
blocks <- block_support(
  lower = rbind(c(0, 0), c(4, 4)),
  upper = rbind(c(4, 4), c(8, 8))
)
blocks
#> <gpfield_block_support>
#>   blocks:  2
#>   n_quad:  200 per block
```

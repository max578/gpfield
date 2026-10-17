# Construct a typed gpfield abstention

Returns a small classed object signalling that the data cannot support a
prediction, with a machine-readable reason code and human-readable
detail. Used in place of a confident-but-wrong prediction so that
callers can branch on a refusal rather than trust an unsupported
surface.

## Usage

``` r
gpfield_abstention(
  reason,
  detail = NA_character_,
  scope = "gp_predict",
  diagnostics = list()
)
```

## Arguments

- reason:

  Character scalar reason code. One of `"range_too_short"` (the
  estimated correlation range is shorter than the requested prediction
  spacing, so interpolation would be unsupported extrapolation between
  effectively independent points), `"support_gap"` (a requested block
  has too few – or no – observations within its own footprint or one
  correlation range of it), `"degenerate_fit"` (the marginal-likelihood
  optimisation did not yield a usable hyperparameter set), or
  `"empty_query"` (the prediction grid contained no rows).

- detail:

  Character scalar human-readable detail, or `NA`.

- scope:

  Character scalar naming what was refused (default `"gp_predict"`).

- diagnostics:

  Optional named list of the numbers behind the refusal (for example the
  estimated range and the requested spacing) so the caller can act on
  the margin, not just the verdict.

## Value

An object of class `"gpfield_abstention"`: a list with `reason`,
`detail`, `scope`, `diagnostics` and `abstained = TRUE`.

## Examples

``` r
a <- gpfield_abstention(
  "range_too_short",
  "estimated range 2.1 m < requested spacing 10 m"
)
is_gpfield_abstention(a)
#> [1] TRUE
```

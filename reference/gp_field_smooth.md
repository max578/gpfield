# Smooth a row-column field or trial layout

One call from a multi-environment-trial (or any row-column field) data
frame to a smoothed surface. Fits a gpfield Gaussian process over the
row and column coordinates and predicts the latent trait surface back
onto a plot grid – the observed grid by default, or a finer grid through
`refine`. The abstention of
[`gp_predict()`](https://max578.github.io/gpfield/reference/gp_predict.md)
is inherited: refining only inserts points strictly between the
*observed* row-column locations, so if the observed grid's own spacing
is already coarser than the estimated correlation range can resolve,
`gp_field_smooth()` returns a
[`gpfield_abstention()`](https://max578.github.io/gpfield/reference/gpfield_abstention.md)
at every `refine` level rather than an over-confident surface – refining
a grid the range cannot support does not manufacture support.

## Usage

``` r
gp_field_smooth(
  data,
  response,
  row = "row",
  col = "col",
  kernel = "matern",
  nu = 1.5,
  refine = 1L,
  seed = NULL
)
```

## Arguments

- data:

  A `data.frame` with the row, column and response columns.

- response:

  Character scalar naming the trait column to smooth.

- row, col:

  Character scalars naming the row and column coordinate columns
  (default `"row"` and `"col"`).

- kernel:

  Character covariance kernel passed to
  [`gpfield_spec()`](https://max578.github.io/gpfield/reference/gpfield_spec.md):
  `"matern"` (default) or `"se"`.

- nu:

  Matern smoothness (default `1.5`); ignored for `"se"`.

- refine:

  Positive integer grid-refinement factor. `1` (default) predicts on the
  observed plot grid; `2` predicts on a grid twice as fine on each axis,
  and so on. Refining never itself escapes an abstention: the observed
  grid's own spacing is checked against the estimated correlation range
  before any refinement is applied, so an unsupported observed grid
  stays unsupported at every `refine` level.

- seed:

  Optional integer seed recorded with the fit.

## Value

A `gpfield_smooth` S7 object carrying the `@fit` (a `gpfield_fit`) and
the `@prediction` (a `gpfield_prediction`), or a
[`gpfield_abstention()`](https://max578.github.io/gpfield/reference/gpfield_abstention.md)
when the fit or the prediction cannot be supported.

## See also

[`gp_fit()`](https://max578.github.io/gpfield/reference/gp_fit.md),
[`gp_predict()`](https://max578.github.io/gpfield/reference/gp_predict.md),
[`gp_field_plot()`](https://max578.github.io/gpfield/reference/gp_field_plot.md)

## Examples

``` r
set.seed(1L)
field <- expand.grid(row = seq_len(10L), col = seq_len(10L))
field$yield <- 3 + 0.2 * field$row - 0.1 * field$col +
  stats::rnorm(nrow(field), 0, 0.3)
sm <- gp_field_smooth(field, response = "yield", seed = 1L)
sm@prediction
#> <gpfield_prediction>
#>   support:   point
#>   locations: 100
#>   mean range: [2.369, 4.992]
#>   sd range:   [0.273, 0.2901]
```

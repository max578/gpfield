# Specify a gpfield Gaussian-process model

Builds the configuration consumed by
[`gp_fit()`](https://max578.github.io/gpfield/reference/gp_fit.md). A
specification fixes the covariance kernel and (for `"matern"`) its
smoothness, names the spatial coordinate columns in the data frame the
fit will read, optionally names a time column for a spatio-temporal
model, and sets the diagonal jitter used to condition the kernel.
Nothing is fitted here; the specification is a small, inspectable object
so the model is declared before any data are touched.

## Usage

``` r
gpfield_spec(
  coords,
  response,
  kernel = "matern",
  nu = 1.5,
  time = NA_character_,
  nugget = 1e-06,
  anisotropic = FALSE,
  solver = c("exact", "lowrank"),
  n_inducing = 200L
)
```

## Arguments

- coords:

  Character vector naming the spatial coordinate columns (one for a
  transect, two for a field, three or more if the caller has projected
  additional spatial axes). When a `time` column is also given, it is
  appended to the coordinate set as an extra, separately-scaled axis.

- response:

  Character scalar naming the response column to smooth.

- kernel:

  Character covariance kernel: `"matern"` (default) or `"se"`
  (squared-exponential).

- nu:

  Matern smoothness; one of `0.5`, `1.5` (default) or `2.5`. Ignored for
  the squared-exponential kernel.

- time:

  Optional character scalar naming a time column for a spatio-temporal
  fit, or `NA` (default) for a purely spatial model. When a time axis is
  present the fit is anisotropic by necessity – a unit of space and a
  unit of time are not exchangeable, so time is given its own
  length-scale even if `anisotropic` is left at its default `FALSE`.

- nugget:

  Positive numeric jitter added to the kernel diagonal for numerical
  conditioning. Distinct from the estimated observation-noise variance,
  which is a fitted hyperparameter.

- anisotropic:

  Logical. If `TRUE` and there are at least two coordinate axes, fit one
  length-scale per axis (automatic relevance determination) rather than
  a single isotropic length-scale. The kernel stays isotropic in a
  per-axis-rescaled coordinate space, so each axis gets its own
  correlation range – the right model when a field varies on different
  scales along different directions (an east-west tillage gradient
  versus a north-south slope, or space versus a time axis). Default
  `FALSE` (a single length-scale, the original behaviour).

- solver:

  Character: `"exact"` (default) fits the exact GP by a full Cholesky
  factorisation, cubic in the number of observations. `"lowrank"` fits a
  Deterministic Training Conditional (DTC) sparse GP on `n_inducing`
  space-filling inducing points – cost `O(n * n_inducing^2)` – for
  fields too large for the exact solver. The low-rank solver is
  isotropic (a single length-scale) and falls back to the exact solver
  when the data have no more rows than `n_inducing`.

- n_inducing:

  Integer number of inducing points for `solver = "lowrank"` (default
  `200`, minimum `3`); ignored for the exact solver.

## Value

A `gpfield_spec` S7 object.

## Details

The default kernel is the `"matern"` family at `nu = 1.5`, the usual
choice for field data: it is once-differentiable rather than the
squared-exponential's infinite smoothness, which avoids the
over-smoothing that the squared exponential imposes across real
agronomic gradients.

## See also

[`gp_fit()`](https://max578.github.io/gpfield/reference/gp_fit.md),
[`gp_predict()`](https://max578.github.io/gpfield/reference/gp_predict.md)

## Examples

``` r
spec <- gpfield_spec(coords = c("x", "y"), response = "yield")
spec
#> <gpfield_spec>
#>   kernel:   matern (nu = 1.5)
#>   coords:   x, y
#>   response: yield

# An anisotropic field: a separate length-scale per axis.
aniso <- gpfield_spec(c("x", "y"), "yield", anisotropic = TRUE)
aniso
#> <gpfield_spec>
#>   kernel:   matern (nu = 1.5) (anisotropic)
#>   coords:   x, y
#>   response: yield

# A large field: the low-rank sparse solver on 150 inducing points.
big <- gpfield_spec(c("x", "y"), "yield", solver = "lowrank",
                    n_inducing = 150L)
big
#> <gpfield_spec>
#>   kernel:   matern (nu = 1.5)
#>   coords:   x, y
#>   response: yield
#>   solver:   low-rank (DTC, 150 inducing points)

# A spatio-temporal specification with the squared-exponential kernel.
st <- gpfield_spec(
  coords = c("x", "y"), response = "ndvi", kernel = "se", time = "doy"
)
st
#> <gpfield_spec>
#>   kernel:   squared-exponential
#>   coords:   x, y
#>   time:     doy
#>   response: ndvi
```

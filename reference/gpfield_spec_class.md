# A gpfield model specification

The configuration of a spatial (or spatio-temporal) Gaussian process
before it is fitted: which covariance kernel to use, the smoothness for
the Matern family, the names of the spatial coordinate columns, an
optional time-axis column, and the jitter added to the kernel diagonal
for numerical conditioning. Construct one with
[`gpfield_spec()`](https://max578.github.io/gpfield/reference/gpfield_spec.md)
and fit it with
[`gp_fit()`](https://max578.github.io/gpfield/reference/gp_fit.md).

## Value

An S7 object of class `gpfield_spec`.

## See also

[`gpfield_spec()`](https://max578.github.io/gpfield/reference/gpfield_spec.md),
[`gp_fit()`](https://max578.github.io/gpfield/reference/gp_fit.md)

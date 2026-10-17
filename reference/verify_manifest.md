# Verify an orchestra manifest's payload integrity

Recomputes the payload hash from the object's own load-bearing slots and
compares it to the stored `data_hash`. A mismatch means the payload was
modified after emission. Matches the reference contract's
`verify_manifest()`.

## Usage

``` r
verify_manifest(m)
```

## Arguments

- m:

  An `orchestra_manifest` object.

## Value

A list with logical `ok` and a human-readable `message`.

## See also

[`as_orchestra_manifest()`](https://max578.github.io/gpfield/reference/as_orchestra_manifest.md)

## Examples

``` r
set.seed(1L)
grid <- expand.grid(x = seq_len(8L), y = seq_len(8L))
grid$yield <- 2 + 0.3 * grid$x + stats::rnorm(nrow(grid), 0, 0.2)
fit <- gp_fit(gpfield_spec(c("x", "y"), "yield"), grid, seed = 1L)
pred <- gp_predict(fit, grid)
m <- as_orchestra_manifest(pred)
verify_manifest(m)
#> $ok
#> [1] TRUE
#> 
#> $message
#> [1] "data_hash verified"
#> 
```

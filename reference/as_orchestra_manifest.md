# Emit a gpfield result as an orchestra manifest

The federation's emit / adapt generic. The `gpfield_prediction` method
turns a smoothed surface into the shared `orchestra_manifest` contract:
`inferential_target = "predictions"`, the predictive mean and standard
deviation (and, for block support, the block bounds) carried in
`outputs`, and the model provenance – kernel, estimated range, support,
log-likelihood – in `metadata`. The payload is integrity-hashed so a
downstream consumer can verify it with
[`verify_manifest()`](https://max578.github.io/gpfield/reference/verify_manifest.md).

## Usage

``` r
as_orchestra_manifest(x, ...)
```

## Arguments

- x:

  A `gpfield_prediction` object.

- ...:

  Method-specific arguments. The `gpfield_prediction` method accepts
  `run_id`, an optional character run identifier; when omitted a content
  hash is derived, so two identical predictions get the same identifier.

## Value

An `orchestra_manifest` S7 object.

## See also

[`verify_manifest()`](https://max578.github.io/gpfield/reference/verify_manifest.md),
[`gp_predict()`](https://max578.github.io/gpfield/reference/gp_predict.md)

## Examples

``` r
set.seed(1L)
grid <- expand.grid(x = seq_len(8L), y = seq_len(8L))
grid$yield <- 2 + 0.3 * grid$x + stats::rnorm(nrow(grid), 0, 0.2)
fit <- gp_fit(gpfield_spec(c("x", "y"), "yield"), grid, seed = 1L)
pred <- gp_predict(fit, grid)
as_orchestra_manifest(pred)
#> <orchestra_manifest>
#>   schema:   2.0.0-draft
#>   emitter:  gpfield 0.4.1.9000
#>   target:   predictions
#>   method:   gpfield:matern:point
#>   run_id:   gpfield-88053910c51c
#>   outputs:  64 rows x 6 cols
#>   hash:     sha256:88053910c51c0d7d257a06efeac29b587ed6f63d6672af42275531619f2358b1
```

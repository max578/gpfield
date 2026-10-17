# A fitted gpfield Gaussian process

The result of
[`gp_fit()`](https://max578.github.io/gpfield/reference/gp_fit.md): the
originating `gpfield_spec`, the standardised training coordinates and
response, the estimated hyperparameters (marginal variance, length-scale
and noise variance), the Cholesky factor and weight vector of the solved
system, and the marginal log-likelihood at the optimum. Predict from it
– at the observed support or another – with
[`gp_predict()`](https://max578.github.io/gpfield/reference/gp_predict.md).

## Value

An S7 object of class `gpfield_fit`.

## See also

[`gp_fit()`](https://max578.github.io/gpfield/reference/gp_fit.md),
[`gp_predict()`](https://max578.github.io/gpfield/reference/gp_predict.md)

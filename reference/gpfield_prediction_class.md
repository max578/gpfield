# A gpfield prediction at a requested support

The result of a successful
[`gp_predict()`](https://max578.github.io/gpfield/reference/gp_predict.md):
the queried locations or block definitions, the predictive mean and
standard deviation, the inferential support (`"point"` or `"block"`),
and the number of observations that informed each query (carried so a
consumer can see how well-supported each value is). Unsuccessful
predictions return a
[`gpfield_abstention()`](https://max578.github.io/gpfield/reference/gpfield_abstention.md)
instead.

## Value

An S7 object of class `gpfield_prediction`.

## See also

[`gp_predict()`](https://max578.github.io/gpfield/reference/gp_predict.md)

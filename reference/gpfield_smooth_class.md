# A fitted-and-smoothed field

The successful result of
[`gp_field_smooth()`](https://max578.github.io/gpfield/reference/gp_field_smooth.md):
the fitted `gpfield_fit` and the point-support `gpfield_prediction` over
the (possibly refined) plot grid, carried together as one typed object
so the smoothing path returns the same kind of inspectable value as the
rest of the package rather than a bare list. Access the parts with
`@fit` and `@prediction`. An unsuccessful smoothing returns a
[`gpfield_abstention()`](https://max578.github.io/gpfield/reference/gpfield_abstention.md)
instead.

## Value

An S7 object of class `gpfield_smooth`.

## See also

[`gp_field_smooth()`](https://max578.github.io/gpfield/reference/gp_field_smooth.md),
[`gp_field_plot()`](https://max578.github.io/gpfield/reference/gp_field_plot.md)

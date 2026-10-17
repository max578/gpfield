# Package index

## Model specification and fitting

Declare a spatial or spatio-temporal Gaussian-process model and fit it
to field or trial data by marginal-likelihood maximisation.

- [`gpfield_spec()`](https://max578.github.io/gpfield/reference/gpfield_spec.md)
  : Specify a gpfield Gaussian-process model
- [`gp_fit()`](https://max578.github.io/gpfield/reference/gp_fit.md) :
  Fit a gpfield Gaussian process to field or trial data

## Prediction and change of support

Predict the latent field at point support, or at a different support –
paddock-scale block averages with the predictive variance propagated
through the support map.

- [`gp_predict()`](https://max578.github.io/gpfield/reference/gp_predict.md)
  : Predict a gpfield surface, optionally at a different support
- [`block_support()`](https://max578.github.io/gpfield/reference/block_support.md)
  : Describe a block (areal) support for change-of-support prediction

## Field and trial smoothing

The one-call path from a row-column multi-environment-trial layout to a
smoothed surface, and a colourblind-safe raster of it.

- [`gp_field_smooth()`](https://max578.github.io/gpfield/reference/gp_field_smooth.md)
  : Smooth a row-column field or trial layout
- [`gp_field_plot()`](https://max578.github.io/gpfield/reference/gp_field_plot.md)
  : Draw a smoothed field surface (requires ggplot2)

## Orchestra contract manifest

Emit a smoothed surface as the orchestra’s versioned, integrity-hashed
ensemble-manifest contract, and verify it.

- [`as_orchestra_manifest()`](https://max578.github.io/gpfield/reference/as_orchestra_manifest.md)
  : Emit a gpfield result as an orchestra manifest
- [`orchestra_manifest`](https://max578.github.io/gpfield/reference/orchestra_manifest.md)
  : The orchestra ensemble-manifest contract (gpfield-side
  implementation)
- [`verify_manifest()`](https://max578.github.io/gpfield/reference/verify_manifest.md)
  : Verify an orchestra manifest's payload integrity

## Abstention

The typed refusal returned when the data support or spatial range cannot
bear the requested prediction resolution.

- [`gpfield_abstention()`](https://max578.github.io/gpfield/reference/gpfield_abstention.md)
  : Construct a typed gpfield abstention
- [`is_gpfield_abstention()`](https://max578.github.io/gpfield/reference/is_gpfield_abstention.md)
  : Is an object a gpfield abstention?

## Classes

The S7 object hierarchy carrying an analysis end to end.

- [`gpfield_spec_class`](https://max578.github.io/gpfield/reference/gpfield_spec_class.md)
  : A gpfield model specification
- [`gpfield_fit_class`](https://max578.github.io/gpfield/reference/gpfield_fit_class.md)
  : A fitted gpfield Gaussian process
- [`gpfield_prediction_class`](https://max578.github.io/gpfield/reference/gpfield_prediction_class.md)
  : A gpfield prediction at a requested support
- [`gpfield_smooth_class`](https://max578.github.io/gpfield/reference/gpfield_smooth_class.md)
  : A fitted-and-smoothed field

## Package

- [`gpfield`](https://max578.github.io/gpfield/reference/gpfield-package.md)
  [`gpfield-package`](https://max578.github.io/gpfield/reference/gpfield-package.md)
  : gpfield: Change-of-Support Gaussian-Process Regression for Field and
  Multi-Environment-Trial Data

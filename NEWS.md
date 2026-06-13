# gpfield 0.1.0

First release. `gpfield` enrols the orchestra's spatial member: change-of-support
Gaussian-process regression for field and multi-environment-trial data, with
honest abstention and orchestra-manifest emission from day one. The Gaussian
process is a self-contained exact solver in base R -- no heavy external
GP dependency -- so the package installs and checks anywhere.

## New features

* Exact spatial (and spatio-temporal) Gaussian-process regression.
  `gpfield_spec()` declares the model -- the covariance kernel, its smoothness,
  the coordinate columns and an optional time axis -- and `gp_fit()` solves it by
  marginal-likelihood maximisation over a Cholesky factorisation, returning a
  typed `gpfield_fit` whose estimated correlation range is made explicit. Two
  covariance kernels ship: the squared-exponential and the `Matern` family at
  smoothness `0.5`, `1.5` (the field-data default) and `2.5`.

* **Change of support, the defining capability.** `gp_predict()` predicts at a
  support different from the one observed. `support = "point"` is the usual GP
  posterior at query points; `support = "block"`, with a `block_support()`
  description, is the change-of-support integral -- a paddock-scale block average
  is the integral of the latent field over the block, and its predictive variance
  is the full quadratic form over the block's within-block covariance, so spatial
  correlation is propagated rather than averaged away.

* **Honest abstention.** A prediction the data cannot support is refused, not
  fabricated. `gp_predict()` returns a typed `gpfield_abstention()` -- with a
  machine-readable reason a caller can branch on -- when the query grid is coarser
  than the estimated range (`"range_too_short"`), when a requested block has no
  observation within one correlation range of it (`"support_gap"`), when the fit
  is degenerate (`"degenerate_fit"`), or when the query is empty
  (`"empty_query"`).

* Multi-environment-trial smoothing. `gp_field_smooth()` is the one-call path from
  a row-column trial data frame to a smoothed surface, optionally on a refined
  grid, inheriting the abstention discipline. `gp_field_plot()` draws the smoothed
  surface as a colourblind-safe viridis raster when `ggplot2` is present.

* Orchestra-manifest emission. `as_orchestra_manifest()` adapts a
  `gpfield_prediction` into the federation's shared, versioned, integrity-hashed
  `orchestra_manifest` contract (`inferential_target = "predictions"`), so a
  smoothed field surface composes directly with the orchestra's calibration,
  uncertainty-quantification, causal-inference and decision members.
  `verify_manifest()` confirms a manifest's payload was not tampered with.

## Known limitations

* The exact solver is cubic in the number of observations, which is comfortable
  for the hundreds-to-low-thousands of plots a multi-environment trial carries. A
  low-rank / Nystrom approximation for larger fields is a documented future path,
  not built in this release. The covariance is isotropic; a geometrically
  anisotropic kernel is a planned extension.

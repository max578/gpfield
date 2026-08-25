# gpfield (development version)

## Bug fixes

* `gp_field_smooth()`'s `refine` argument could escape its own documented
  abstention: a large enough `refine` shrank the *refined* grid's own
  point-to-point spacing below the estimated correlation range and so passed
  the support guard, even though the *observed* grid the refinement was built
  from was never any better supported. The observed grid's spacing is now
  checked against the range before any refinement is applied, so a base grid
  the range cannot resolve stays refused at every `refine` level.
* `print.gpfield_abstention()` and `print.gpfield_block_support()` are now
  registered explicitly via `registerS3method()` in `.onLoad()`. Under a real
  installed `library(gpfield)` load the two methods were declared in
  `NAMESPACE` but never reached `base::.__S3MethodsTable__.`, so the typed
  refusal objects printed as a raw list with `attr(,"class")` exposed instead
  of dispatching to their own print method.
* The block-average predictive variance no longer adds an observation-noise
  term. The block target is the integral of the *latent* field over the block
  footprint, which carries no observation noise; treating the quadrature
  nodes as `n_quad` independent noisy measurements added a term that shrank
  with `n_quad` without vanishing, so the reported block standard deviation
  never converged as the quadrature was refined.

## Other

* Added a GitHub Actions R-CMD-check workflow (ubuntu/macOS/windows, several
  R versions) so the public CI oracle the rest of the orchestra relies on now
  also covers gpfield.

## Documentation

* Corrected the vignette's identification of the worked dataset:
  `agridat::besag.met` is a multi-environment trial of 64 **corn** hybrids
  across six North Carolina counties, not barley -- grounded against the
  `agridat` documentation and repeated in two places (running prose and a
  figure's alt text).
* Added a caption and an interpreting paragraph to the vignette's one figure
  (the smoothed-surface plot), which previously carried alt text only and no
  discussion of what the surface shows.
* Added the governing equations for the block mean and variance (the
  quadrature-weighted posterior mean and the full within-block quadratic
  form) and for the Deterministic Training Conditional low-rank
  approximation, with citations (Cressie 1993; Gotway and Young 2002;
  Quinonero-Candela and Rasmussen 2005), to a vignette that previously
  described both only in prose with no equations and no method citations.
* Fixed the vignette's naive-independence standard-deviation comparison,
  which divided by the *requested* `n_quad` rather than the tensor-midpoint
  quadrature rule's *realised* point count (`round(sqrt(n_quad))^2`), a
  discrepancy of 200 versus 196 at the vignette's default settings.

# gpfield 0.3.0

A correctness, performance and methodology pass over the exact solver and the
change-of-support machinery, an optional low-rank solver for large fields, and a
re-grounding of the orchestra manifest against the federation contract.

## New features

* **Low-rank solver for large fields.** `gpfield_spec(solver = "lowrank")` fits a
  Deterministic Training Conditional (DTC) sparse Gaussian process on
  `n_inducing` space-filling inducing points, at cost `O(n * n_inducing^2)`
  rather than the exact solver's `O(n^3)`. On a smooth field of ~1700 plots the
  low-rank fit is roughly 30 times faster than the exact fit with matching
  held-out accuracy, and it scales to fields the exact solver cannot reach. The
  inducing points are selected deterministically by farthest-point sampling (no
  RNG), so the fit is reproducible; when the inducing set is the whole training
  set the DTC posterior is exactly the exact GP. Every downstream verb -- point
  and block prediction, change of support, honest abstention, manifest emission
  -- works unchanged under the low-rank fit. The default solver stays exact, and
  the low-rank solver falls back to exact when the data have no more rows than
  `n_inducing`.

## Bug fixes

* The block-support guard (`support = "block"`) counted supporting observations
  from a per-axis distance that was silently miscomputed for a block straddling
  the field boundary -- a coordinate-recycling error that could over- or
  under-state the count and so flip a `support_gap` abstention. The per-axis gap
  is now computed correctly, checked against an independent brute-force count.

* `gp_predict()` no longer mutates the caller's global random-number stream. The
  block quadrature previously seeded the global RNG as a side effect; it is now a
  deterministic tensor grid, so a block prediction is reproducible with no seed
  and leaves `.Random.seed` untouched. The `seed` argument is retained for
  backward compatibility but no longer affects the result.

## Performance

* Point and grid prediction no longer forms the full query-by-query posterior
  covariance when only the marginal variances are needed. A fine prediction grid
  that previously allocated an `m`-by-`m` matrix (hundreds of megabytes on a
  refined field) now costs `O(m n)`, so `gp_field_smooth(refine = ...)` scales to
  fine grids. The block-support path, which genuinely needs the full within-block
  covariance, is unchanged.

* The marginal-likelihood objective adds noise to the kernel diagonal in place
  rather than allocating a fresh diagonal matrix each optimiser step, the
  anisotropic objective reuses precomputed per-axis squared differences instead
  of re-forming the pairwise distance every evaluation, and the point-support
  spacing guard computes its nearest-neighbour spacing in row blocks, bounding
  peak memory on large query grids.

## Methodology

* **Effective correlation range.** The range a fit reports, and the range the
  abstention guards reason about, is now the effective (practical) range -- the
  distance at which the covariance decays to 0.05 -- rather than the bare
  length-scale. For the exponential kernel this is the textbook three-times-the-
  length-scale. `spacing_tol` is therefore measured in effective ranges.

* **Per-axis abstention under anisotropy.** With an anisotropic fit the support
  guards now reason per axis: a query resolved finely along a long-range axis is
  no longer condemned by a short-range one, and a block's supporting reach is
  per-axis. The isotropic path is unchanged.

* **Spatio-temporal fits are anisotropic by default.** When a `time` axis is
  given, the fit estimates a separate length-scale for time rather than coupling
  space and time through one isotropic length-scale -- a unit of space and a unit
  of time are not exchangeable. A purely spatial fit follows the `anisotropic`
  flag as before.

* **Deterministic block quadrature.** The change-of-support integral is computed
  on a deterministic tensor midpoint grid rather than by uniform Monte-Carlo
  sampling, which converges faster on the smooth latent fields a GP represents
  and removes the seed dependence.

* **More robust hyperparameter fitting.** The marginal-likelihood optimisation
  runs from several length-scale starts and keeps the best, guarding against the
  local optima the single-start simplex settled into on multi-scale fields.

## Orchestra contract

* The emitted `orchestra_manifest` is re-grounded against the federation
  reference contract (`orchestra_manifest.R`, schema `2.0.0-draft`). The payload
  integrity hash now serialises to a version-stable byte layout -- the format-2
  header is dropped before hashing -- so a gpfield manifest verifies across R
  versions and carries the same `data_hash` as a reference manifest of the same
  payload. The previous scheme was fragile across R versions and would not have
  verified under the current federation `verify_manifest()`. A new parity test
  grounds the property set, the inferential-target enum and the hash scheme
  against a snapshot of the reference. The `structure` inferential target is
  added to the accepted enum.

## API

* `gp_field_smooth()` now returns a typed `gpfield_smooth` object with `@fit` and
  `@prediction` properties, rather than a bare list -- the smoothing path now
  returns the same kind of inspectable value as the rest of the package. Access
  the parts with `@fit` / `@prediction` (previously `$fit` / `$prediction`);
  `gp_field_plot()` accepts the new object directly.
* A `predict()` method is registered for a fitted GP, delegating to the
  documented verb `gp_predict()`, so a fit drops into generic tooling.
* `gp_predict()` now warns when an argument is set that does not apply to the
  chosen support (`min_support_ranges` at point support, `spacing_tol` at block
  support) rather than ignoring it silently.
* `block_support()` documents that blocks are axis-aligned rectangles; irregular
  or polygonal footprints are a planned extension.

## Testing

* An independent-oracle test recomputes the GP posterior from scratch with
  explicit matrix algebra sharing no code path with the package, grounding the
  central mathematical claim rather than checking the package against itself.

# gpfield 0.2.0

## New features

* `gpfield_spec(anisotropic = TRUE)` fits an **anisotropic** Gaussian process: one
  length-scale per coordinate axis (automatic relevance determination) instead of
  a single isotropic length-scale. Each axis's length-scale is estimated by
  marginal likelihood and absorbed into that axis's standardisation, so the
  stored kernel stays isotropic over the rescaled coordinates and every
  downstream verb -- point and block prediction, change-of-support, the support
  guard -- is unchanged. On a field that varies on different scales along
  different directions this is a large accuracy gain: on the Branin function the
  anisotropic fit cuts held-out error about 20-fold over the isotropic fit (to
  roughly 0.05% of the function range) and matches a dedicated anisotropic GP
  (`DiceKriging`). The fitted per-axis correlation ranges are reported by the
  `gpfield_fit` print method and stored in `fit@hyper$range_axis`. The default
  stays isotropic, so existing fits are unchanged. This resolves the constellation
  `/stretch` finding that gpfield's single isotropic length-scale sat well above
  an anisotropic oracle on a strongly anisotropic function. Re-grounding script:
  `ORCHESTRA_dev/stretch/constellation/verify/v9_R4_gpfield_ard_regrounded.R`.

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

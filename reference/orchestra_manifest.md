# The orchestra ensemble-manifest contract (gpfield-side implementation)

A versioned, hashed, provenance-complete S7 result object,
property-compatible with the federation's reference
`orchestra_manifest`. A `gpfield_prediction` is adapted into one through
[`as_orchestra_manifest()`](https://max578.github.io/gpfield/reference/as_orchestra_manifest.md):
the predictive mean and standard deviation ride in `outputs`, the
queried locations and the model provenance ride in `metadata`, and the
payload is integrity-hashed so a tampered surface is detected
downstream.

## Value

An S7 object of class `orchestra_manifest`.

## See also

[`as_orchestra_manifest()`](https://max578.github.io/gpfield/reference/as_orchestra_manifest.md),
[`verify_manifest()`](https://max578.github.io/gpfield/reference/verify_manifest.md)

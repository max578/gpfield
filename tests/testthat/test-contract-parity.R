# test-contract-parity.R -- ground the orchestra_manifest contract against the
# federation reference, rather than assert it. The reference lives outside this
# package (the composition layer sources it, it is not installed), so the golden
# values below are a vendored snapshot of it.
#
# Provenance: snapshotted from ORCHESTRA_dev/integration/orchestra_manifest.R,
# contract "2.0.0-draft", on 2026-07-05. The GOLDEN_HASH was computed in a fresh
# R session by that file's own `.hash_payload()` algorithm, independent of any
# gpfield code path. If gpfield's implementation ever drifts from the reference,
# these assertions fail and demand a re-grounding.

# The load-bearing property set a consumer reads (order-independent).
REF_PROPERTIES <- c(
  "manifest_version", "emitter_package", "emitter_version",
  "inferential_target", "run_id", "method", "seed", "params", "outputs",
  "weights", "obs_target", "obs_schema", "summary", "consumed_manifests",
  "metadata", "timestamp", "data_hash"
)
REF_TARGETS <- c("parameters", "predictions", "treatment_effects", "decisions",
                 "breeding_values", "marker_associations", "structure")
REF_VERSION <- "2.0.0-draft"
GOLDEN_HASH <-
  "sha256:8606b44f99f5e226f05413341d84bfe39a5a459446b86f354adf38ab08b7f314"

test_that("the emitted manifest carries exactly the reference property set", {
  fit <- .fitted_field()
  m <- as_orchestra_manifest(gp_predict(fit, .make_field()[, c("x", "y")]))
  expect_setequal(S7::prop_names(m), REF_PROPERTIES)
  expect_identical(m@manifest_version, REF_VERSION)
})

test_that("the inferential-target enum tracks the reference", {
  expect_setequal(gpfield:::.INFERENTIAL_TARGETS, REF_TARGETS)
})

test_that("the payload hash is byte-identical to the reference scheme", {
  # The reference (contract 2.0.0) serialises with version = 2L and strips the
  # 14-byte header before hashing so a manifest verifies across R versions. A
  # fixed payload must hash to the value the reference algorithm produced.
  outputs <- data.frame(x = 1L, mean = 2.5, sd = 0.3)
  got <- gpfield:::.hash_payload(data.frame(), outputs, NULL, NULL, NA_integer_)
  expect_identical(got, GOLDEN_HASH)
})

test_that("the hash is stable across the serialisation-version header", {
  # Regression for the R-version fragility the 2.0.0 scheme fixed: the hash must
  # not depend on the 14-byte serialisation header.
  payload <- list(a = 1L, b = "x")
  raw_full <- serialize(payload, connection = NULL, version = 2L)
  expect_identical(
    gpfield:::.sha256(payload),
    digest::digest(raw_full[-seq_len(14L)], algo = "sha256", serialize = FALSE)
  )
})

test_that("a manifest emitted by gpfield verifies under its own scheme", {
  fit <- .fitted_field()
  m <- as_orchestra_manifest(gp_predict(fit, .make_field()[, c("x", "y")]))
  expect_true(verify_manifest(m)$ok)
})

# Opt-in live drift detector: when the reference file is reachable (its path in
# the ORCHESTRA_REF environment variable), confirm the vendored snapshot still
# matches the live reference's hashing algorithm. Skipped in a clean-room / CRAN
# run where the composition layer is absent -- never hardcodes a user path.
test_that("the vendored snapshot still matches the live reference (when present)", {
  ref <- Sys.getenv("ORCHESTRA_REF", unset = NA_character_)
  skip_if(is.na(ref) || !file.exists(ref), "ORCHESTRA_REF not set")
  src <- readLines(ref, warn = FALSE)
  txt <- paste(src, collapse = "\n")
  # The reference must still declare the 2.0.0 hashing scheme this snapshot pins.
  expect_true(grepl("version = 2L", txt, fixed = TRUE))
  expect_true(grepl("seq_len(14L)", txt, fixed = TRUE))
})

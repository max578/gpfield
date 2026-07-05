# test-manifest.R -- the orchestra contract emission (ORCHESTRA binding #1).

test_that("a point prediction emits a conformant orchestra manifest", {
  fit <- .fitted_field()
  pred <- gp_predict(fit, .make_field()[, c("x", "y")])
  m <- as_orchestra_manifest(pred)
  expect_true(S7::S7_inherits(m, orchestra_manifest))
  expect_identical(m@emitter_package, "gpfield")
  expect_identical(m@emitter_version,
                   as.character(utils::packageVersion("gpfield")))
  expect_identical(m@inferential_target, "predictions")
  expect_true(nzchar(m@run_id))
  expect_true(grepl("^gpfield:", m@method))
})

test_that("the manifest uses the federation field names and hash scheme", {
  # These property names and the `sha256:` prefix are the load-bearing contract
  # that lets a consumer read a gpfield manifest with no special-casing.
  fit <- .fitted_field()
  pred <- gp_predict(fit, .make_field()[, c("x", "y")])
  m <- as_orchestra_manifest(pred)
  props <- S7::prop_names(m)
  expect_true(all(c("manifest_version", "emitter_package", "emitter_version",
                    "inferential_target", "run_id", "method", "seed", "params",
                    "outputs", "weights", "obs_target", "consumed_manifests",
                    "metadata", "timestamp", "data_hash") %in% props))
  expect_true(grepl("^sha256:", m@data_hash))
  expect_identical(m@manifest_version, "2.0.0-draft")
})

test_that("verify_manifest confirms an untampered manifest", {
  fit <- .fitted_field()
  pred <- gp_predict(fit, .make_field()[, c("x", "y")])
  m <- as_orchestra_manifest(pred)
  v <- verify_manifest(m)
  expect_true(v$ok)
})

test_that("verify_manifest detects a tampered payload", {
  fit <- .fitted_field()
  pred <- gp_predict(fit, .make_field()[, c("x", "y")])
  m <- as_orchestra_manifest(pred)
  m@outputs$mean[1L] <- m@outputs$mean[1L] + 1
  v <- verify_manifest(m)
  expect_false(v$ok)
  expect_match(v$message, "MISMATCH")
})

test_that("a block prediction also emits a verifiable manifest", {
  fit <- .fitted_field()
  bl <- block_support(lower = rbind(c(1, 1)), upper = rbind(c(6, 6)))
  blk <- gp_predict(fit, support = "block", blocks = bl, seed = 1L)
  m <- as_orchestra_manifest(blk)
  expect_true(verify_manifest(m)$ok)
  expect_match(m@method, ":block$")
  expect_identical(m@metadata$support, "block")
})

test_that("manifest metadata carries the model provenance", {
  fit <- .fitted_field()
  pred <- gp_predict(fit, .make_field()[, c("x", "y")])
  m <- as_orchestra_manifest(pred)
  expect_identical(m@metadata$kernel, "matern")
  expect_identical(m@metadata$response, "yield")
  expect_true(is.finite(m@metadata$loglik))
  expect_true(is.finite(m@metadata$hyper$range_raw))
})

test_that("identical predictions get identical run_ids", {
  fit <- .fitted_field()
  q <- .make_field()[, c("x", "y")]
  m1 <- as_orchestra_manifest(gp_predict(fit, q))
  m2 <- as_orchestra_manifest(gp_predict(fit, q))
  expect_identical(m1@run_id, m2@run_id)
})

test_that("verify_manifest rejects a non-manifest object", {
  v <- verify_manifest(list())
  expect_false(v$ok)
})

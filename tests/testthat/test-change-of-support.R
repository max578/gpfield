# test-change-of-support.R -- the defining capability: predict at a support
# different from the observed one, with the predictive variance propagated
# through the support map (not naively averaged).

test_that("block_support validates its bounds and quadrature count", {
  bl <- block_support(lower = rbind(c(0, 0)), upper = rbind(c(4, 4)))
  expect_s3_class(bl, "gpfield_block_support")
  expect_error(block_support(rbind(c(0, 0)), rbind(c(0, 4))),
               "must exceed")
  expect_error(block_support(rbind(c(0, 0)), rbind(c(4, 4)), n_quad = 5L),
               "at least 10")
})

test_that("block prediction returns one value per block", {
  fit <- .fitted_field()
  bl <- block_support(lower = rbind(c(1, 1), c(6, 6)),
                      upper = rbind(c(5, 5), c(10, 10)))
  pred <- gp_predict(fit, support = "block", blocks = bl, seed = 1L)
  expect_true(S7::S7_inherits(pred, gpfield_prediction_class))
  expect_identical(pred@support, "block")
  expect_equal(length(pred@mean), 2L)
  expect_equal(length(pred@sd), 2L)
})

test_that("change-of-support round-trip: block average matches dense points", {
  # The block average from the change-of-support integral should agree with the
  # mean of a dense point-prediction grid over the same footprint.
  set.seed(2L)
  g <- expand.grid(x = seq_len(12L), y = seq_len(12L))
  g$z <- 5 + 0.4 * g$x - 0.2 * g$y + stats::rnorm(nrow(g), 0, 0.15)
  fit <- gp_fit(gpfield_spec(c("x", "y"), "z"), g, seed = 2L)

  bl <- block_support(lower = rbind(c(2, 2)), upper = rbind(c(8, 8)),
                      n_quad = 400L)
  blk <- gp_predict(fit, support = "block", blocks = bl, seed = 2L)

  dense <- expand.grid(x = seq(2, 8, length.out = 15L),
                       y = seq(2, 8, length.out = 15L))
  pt <- gp_predict(fit, dense)
  expect_lt(abs(blk@mean - mean(pt@mean)), 0.1)
})

test_that("block variance propagates within-block correlation", {
  # The whole point of change of support: the block-average variance is the full
  # quadratic form over the within-block covariance, so it must exceed the naive
  # point_sd / sqrt(n_quad) that an independence assumption would give.
  fit <- .fitted_field()
  bl <- block_support(lower = rbind(c(1, 1)), upper = rbind(c(5, 5)),
                      n_quad = 200L)
  blk <- gp_predict(fit, support = "block", blocks = bl, seed = 1L)
  centre <- gp_predict(fit, data.frame(x = 3, y = 3))
  naive <- centre@sd / sqrt(bl$n_quad)
  expect_gt(blk@sd, naive)
})

test_that("block prediction abstains on a support gap", {
  fit <- .fitted_field()
  bl <- block_support(lower = rbind(c(100, 100)), upper = rbind(c(105, 105)))
  out <- gp_predict(fit, support = "block", blocks = bl, seed = 1L)
  expect_true(is_gpfield_abstention(out))
  expect_identical(out$reason, "support_gap")
})

test_that("block prediction is reproducible under a fixed quadrature seed", {
  fit <- .fitted_field()
  bl <- block_support(lower = rbind(c(1, 1)), upper = rbind(c(6, 6)))
  a <- gp_predict(fit, support = "block", blocks = bl, seed = 11L)
  b <- gp_predict(fit, support = "block", blocks = bl, seed = 11L)
  expect_equal(a@mean, b@mean)
  expect_equal(a@sd, b@sd)
})

test_that("block prediction is deterministic without a seed and leaves the RNG alone", {
  # The quadrature is a deterministic tensor grid: reproducible with no seed, and
  # it must not mutate the caller's global random stream.
  fit <- .fitted_field()
  bl <- block_support(lower = rbind(c(1, 1)), upper = rbind(c(6, 6)))
  set.seed(123L)
  before <- .Random.seed
  a <- gp_predict(fit, support = "block", blocks = bl)
  after <- .Random.seed
  b <- gp_predict(fit, support = "block", blocks = bl)
  expect_identical(before, after)             # no global-RNG side effect
  expect_equal(a@mean, b@mean)                # deterministic without a seed
  expect_equal(a@sd, b@sd)
})

test_that("block support requires a block_support object and matching axes", {
  fit <- .fitted_field()
  expect_error(gp_predict(fit, support = "block", blocks = list()),
               "must be a `gpfield_block_support`")
  bad <- block_support(lower = rbind(c(1, 1, 1)), upper = rbind(c(2, 2, 2)))
  expect_error(gp_predict(fit, support = "block", blocks = bad),
               "one column per spatial coordinate")
})

test_that("block support is refused for a spatio-temporal fit", {
  set.seed(3L)
  g <- expand.grid(x = seq_len(6L), y = seq_len(6L), t = seq_len(3L))
  g$z <- 1 + 0.1 * g$x + 0.05 * g$t + stats::rnorm(nrow(g), 0, 0.1)
  fit <- gp_fit(gpfield_spec(c("x", "y"), "z", time = "t"), g, seed = 3L)
  bl <- block_support(lower = rbind(c(1, 1)), upper = rbind(c(4, 4)))
  expect_error(gp_predict(fit, support = "block", blocks = bl),
               "spatio-temporal")
})

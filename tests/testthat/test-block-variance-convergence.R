# test-block-variance-convergence.R -- the block-average target is the
# integral of the *latent* field over the block footprint, which carries no
# observation noise. The block variance must therefore converge as the
# quadrature gets finer, not keep moving with `n_quad` (G-07).

test_that("block-average sd converges as n_quad increases, not floats with it", {
  fit <- .fitted_field(seed = 3L)
  bl_lo <- rbind(c(2, 2))
  bl_hi <- rbind(c(8, 8))

  nqs <- c(49L, 400L, 2500L)
  sds <- vapply(nqs, function(nq) {
    bl <- block_support(lower = bl_lo, upper = bl_hi, n_quad = nq)
    blk <- gp_predict(fit, support = "block", blocks = bl, seed = 1L)
    blk@sd
  }, numeric(1L))

  # A convergent quantity: the gap between successive refinements should
  # shrink towards zero, not remain a near-constant fraction of the sd (which
  # is what an O(1/nq) noise/nq contamination term produces).
  gap1 <- abs(sds[[2L]] - sds[[1L]])
  gap2 <- abs(sds[[3L]] - sds[[2L]])
  expect_lt(gap2, gap1 / 3)
  # The last two refinements should already agree tightly.
  expect_lt(abs(sds[[3L]] - sds[[2L]]) / sds[[3L]], 0.01)
})

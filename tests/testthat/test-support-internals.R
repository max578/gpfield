# test-support-internals.R -- the support-guard internals: the per-axis nearness
# count (regression for the recycling defect), per-axis query spacing, and the
# deterministic block quadrature.

test_that(".count_near_block matches an independent per-axis brute-force count", {
  # An edge-straddling block: some points sit outside on one axis, which is the
  # case a naive `lo - sp` recycling would mis-handle. The truth is computed by
  # an explicit per-point loop that shares no code with .count_near_block().
  coords <- rbind(c(0, 0), c(5, 5), c(12, 3), c(3, 12), c(20, 20))
  lo <- c(2, 2)
  hi <- c(10, 10)
  brute <- function(reach) {
    reach <- rep_len(reach, 2L)
    sum(vapply(seq_len(nrow(coords)), function(i) {
      gap <- pmax(lo - coords[i, ], 0) + pmax(coords[i, ] - hi, 0)
      all(gap <= reach)
    }, logical(1L)))
  }
  for (r in list(3, 1, c(5, 0.5), c(0.5, 5))) {
    expect_equal(.count_near_block(coords, lo, hi, r), brute(r),
                 info = paste("reach =", paste(r, collapse = ",")))
  }
})

test_that(".axis_spacing reports the per-axis minimum positive step", {
  xq <- as.matrix(expand.grid(x = c(0, 1, 2, 3), y = c(0, 5, 10)))
  expect_equal(.axis_spacing(xq), c(1, 5))
  # A constant axis has no positive gap.
  expect_true(is.infinite(.axis_spacing(cbind(c(1, 1, 1)))))
})

test_that(".block_quadrature is deterministic, seed-free and roughly n_quad points", {
  a <- .block_quadrature(c(0, 0), c(4, 6), 200L)
  b <- .block_quadrature(c(0, 0), c(4, 6), 200L)
  expect_identical(a, b)                       # no RNG: identical every call
  expect_equal(nrow(a), 14L^2)                 # round(sqrt(200))^2 midpoints
  # Every point lies strictly inside the block footprint.
  expect_true(all(a[, 1] > 0 & a[, 1] < 4))
  expect_true(all(a[, 2] > 0 & a[, 2] < 6))
})

test_that(".query_spacing is unchanged by row-block chunking on a large grid", {
  q <- as.matrix(expand.grid(x = seq_len(40L), y = seq_len(40L)))   # 1600 rows
  d <- gpfield:::.pairwise_distance(q, q)
  diag(d) <- Inf
  reference <- stats::median(apply(d, 1L, min))
  expect_equal(.query_spacing(q), reference)
})

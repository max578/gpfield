# helper-field.R -- a deterministic synthetic field for the test suite.

# A smooth row-column field with a gentle spatial gradient plus low noise, on a
# fixed seed, so every test runs against the same surface.
.make_field <- function(side = 10L, seed = 1L) {
  set.seed(seed)
  g <- expand.grid(x = seq_len(side), y = seq_len(side))
  g$yield <- 2 + 0.3 * g$x + sin(g$y / 2) +
    stats::rnorm(nrow(g), 0, 0.2)
  g
}

# A fitted GP on the synthetic field, used by several tests.
.fitted_field <- function(kernel = "matern", nu = 1.5, seed = 1L) {
  g <- .make_field(seed = seed)
  spec <- gpfield_spec(c("x", "y"), "yield", kernel = kernel, nu = nu)
  gp_fit(spec, g, seed = seed)
}

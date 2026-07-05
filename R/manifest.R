# manifest.R -- the orchestra contract-emitting result object.
#
# gpfield is an orchestra member, so a fitted surface must be expressible in the
# federation's shared manifest contract -- the versioned, hashed,
# provenance-complete S7 object every member emits or consumes as its primary
# inference-result type (ORCHESTRA binding #1; manifest_spec v0.1). This file
# carries a stand-in `orchestra_manifest` class whose property names and integrity
# hash match the canonical reference implementation
# (`ORCHESTRA_dev/integration/orchestra_manifest.R`) field for field, so a
# consumer -- decideR, conductoR -- reads a gpfield manifest with no special
# casing. `as_orchestra_manifest()` is the emit generic, with a method for the
# `gpfield_prediction` result.
#
# The contract class is defined here (rather than depended-on) because the
# canonical implementation lives in the composition layer, not an installable
# package; the field names and the `sha256:`-prefixed payload hash are the
# load-bearing invariants, and they are matched exactly.

# The manifest schema version this member emits. Tracks the reference
# implementation (`ORCHESTRA_dev/integration/orchestra_manifest.R`); bump only
# with an additive (x.y) or breaking (x.0) change there. The 2.0.0 major bump was
# a breaking change to the integrity-hash scheme (see `.hash_payload`): the hash
# is now computed over version-stable serialised bytes so a manifest verifies
# across R versions. A gpfield manifest and a reference manifest of the same
# payload therefore carry the same `data_hash`, verified by
# `tests/testthat/test-contract-parity.R`.
MANIFEST_VERSION <- "2.0.0-draft"

# The inferential-target enum, kept identical to the reference contract so a
# consumer's dispatch never sees an unknown token. `structure` (a recovered
# causal / graphical-model edge set) was added to the reference on 2026-06-24.
.INFERENTIAL_TARGETS <- c("parameters", "predictions",
                          "treatment_effects", "decisions",
                          "breeding_values", "marker_associations",
                          "structure")

#' SHA-256 over version-stable serialised bytes
#'
#' Serialisation is pinned to format 2 and its fixed 14-byte header (magic,
#' format, writer / minimum R versions) is dropped before hashing: those bytes
#' are the only version-varying part, so a manifest emitted under one R version
#' verifies under any other. Byte-identical to the reference contract's `.sha256`
#' (`ORCHESTRA_dev/integration/orchestra_manifest.R`, contract 2.0.0).
#'
#' @param obj The object to hash.
#'
#' @returns A single hex string (no prefix).
#' @noRd
#' @keywords internal
.sha256 <- function(obj) {
  raw <- serialize(obj, connection = NULL, version = 2L)
  raw <- raw[-seq_len(14L)]
  digest::digest(raw, algo = "sha256", serialize = FALSE)
}

#' Payload integrity hash matching the orchestra contract
#'
#' SHA-256 over the load-bearing data slots only (the schema, version and
#' timestamp are metadata and are not hashed -- spec section 8.4). The
#' `"sha256:"` prefix and the slot ordering match the reference implementation so
#' a manifest hashed by gpfield verifies under the federation's
#' `verify_manifest()`.
#'
#' @param params,outputs,weights,obs_target,seed,summary The load-bearing slots.
#'
#' @returns A single `"sha256:"`-prefixed hex string.
#' @noRd
#' @keywords internal
.hash_payload <- function(params, outputs, weights, obs_target, seed,
                          summary = NULL) {
  obj <- list(params, outputs, weights, obs_target, seed, summary)
  paste0("sha256:", .sha256(obj))
}

# --- the contract class ------------------------------------------------------

#' The orchestra ensemble-manifest contract (gpfield-side implementation)
#'
#' A versioned, hashed, provenance-complete S7 result object, property-compatible
#' with the federation's reference `orchestra_manifest`. A `gpfield_prediction`
#' is adapted into one through [as_orchestra_manifest()]: the predictive mean and
#' standard deviation ride in `outputs`, the queried locations and the model
#' provenance ride in `metadata`, and the payload is integrity-hashed so a
#' tampered surface is detected downstream.
#'
#' @usage NULL
#'
#' @returns An S7 object of class `orchestra_manifest`.
#'
#' @seealso [as_orchestra_manifest()], [verify_manifest()]
#' @export
orchestra_manifest <- S7::new_class(
  "orchestra_manifest",
  package = "gpfield",
  properties = list(
    manifest_version   = S7::new_property(S7::class_character,
                                          default = MANIFEST_VERSION),
    emitter_package    = S7::class_character,
    emitter_version    = S7::class_character,
    inferential_target = S7::class_character,
    run_id             = S7::class_character,
    method             = S7::class_character,
    seed               = S7::new_property(S7::class_integer,
                                          default = NA_integer_),
    params             = S7::new_property(S7::class_data.frame,
                                          default = data.frame()),
    outputs            = S7::new_property(S7::class_any, default = NULL),
    weights            = S7::new_property(S7::class_any, default = NULL),
    obs_target         = S7::new_property(S7::class_any, default = NULL),
    obs_schema         = S7::new_property(S7::class_any, default = NULL),
    summary            = S7::new_property(S7::class_any, default = NULL),
    consumed_manifests = S7::new_property(S7::class_list, default = list()),
    metadata           = S7::new_property(S7::class_list, default = list()),
    timestamp          = S7::class_POSIXct,
    data_hash          = S7::class_character
  ),
  validator = function(self) {
    errs <- character(0)
    if (length(self@run_id) != 1L || !nzchar(self@run_id)) {
      errs <- c(errs, "`run_id` must be a single non-empty string")
    }
    if (length(self@inferential_target) != 1L ||
        !self@inferential_target %in% .INFERENTIAL_TARGETS) {
      errs <- c(errs, sprintf("`inferential_target` must be one of %s",
                              paste(.INFERENTIAL_TARGETS, collapse = ", ")))
    }
    if (length(self@data_hash) != 1L) {
      errs <- c(errs, "`data_hash` must be a single string")
    }
    # Reference fork 3: a derived manifest must carry its provenance lineage.
    # gpfield emits only primary (non-derived) manifests, so this never fires on
    # its own output; it is kept to stay a faithful structural match.
    if (isTRUE(self@metadata$derived) &&
        length(self@consumed_manifests) < 1L) {
      errs <- c(errs, paste0("a derived manifest must record >= 1 ",
                             "`consumed_manifests` (provenance lineage is ",
                             "required, not optional)"))
    }
    if (length(errs) == 0L) NULL else paste(errs, collapse = "; ")
  }
)

#' Verify an orchestra manifest's payload integrity
#'
#' Recomputes the payload hash from the object's own load-bearing slots and
#' compares it to the stored `data_hash`. A mismatch means the payload was
#' modified after emission. Matches the reference contract's `verify_manifest()`.
#'
#' @param m An `orchestra_manifest` object.
#'
#' @returns A list with logical `ok` and a human-readable `message`.
#'
#' @seealso [as_orchestra_manifest()]
#'
#' @examples
#' set.seed(1L)
#' grid <- expand.grid(x = seq_len(8L), y = seq_len(8L))
#' grid$yield <- 2 + 0.3 * grid$x + stats::rnorm(nrow(grid), 0, 0.2)
#' fit <- gp_fit(gpfield_spec(c("x", "y"), "yield"), grid, seed = 1L)
#' pred <- gp_predict(fit, grid)
#' m <- as_orchestra_manifest(pred)
#' verify_manifest(m)
#'
#' @export
verify_manifest <- function(m) {
  if (!S7::S7_inherits(m, orchestra_manifest)) {
    return(list(ok = FALSE, message = "not an orchestra_manifest"))
  }
  recomputed <- .hash_payload(m@params, m@outputs, m@weights,
                              m@obs_target, m@seed, m@summary)
  ok <- identical(recomputed, m@data_hash)
  list(ok = ok,
       message = if (ok) "data_hash verified"
                 else "data_hash MISMATCH -- manifest payload was modified")
}

S7::method(print, orchestra_manifest) <- function(x, ...) {
  cat("<orchestra_manifest>\n")
  cat(sprintf("  schema:   %s\n", x@manifest_version))
  cat(sprintf("  emitter:  %s %s\n", x@emitter_package, x@emitter_version))
  cat(sprintf("  target:   %s\n", x@inferential_target))
  cat(sprintf("  method:   %s\n", x@method))
  cat(sprintf("  run_id:   %s\n", x@run_id))
  if (!is.null(x@outputs)) {
    cat(sprintf("  outputs:  %d rows x %d cols\n",
                nrow(x@outputs), ncol(x@outputs)))
  }
  cat(sprintf("  hash:     %s\n", x@data_hash))
  invisible(x)
}

# --- the emit generic --------------------------------------------------------

#' Emit a gpfield result as an orchestra manifest
#'
#' The federation's emit / adapt generic. The `gpfield_prediction` method turns a
#' smoothed surface into the shared `orchestra_manifest` contract:
#' `inferential_target = "predictions"`, the predictive mean and standard
#' deviation (and, for block support, the block bounds) carried in `outputs`, and
#' the model provenance -- kernel, estimated range, support, log-likelihood -- in
#' `metadata`. The payload is integrity-hashed so a downstream consumer can
#' verify it with [verify_manifest()].
#'
#' @param x A `gpfield_prediction` object.
#' @param ... Method-specific arguments. The `gpfield_prediction` method accepts
#'   `run_id`, an optional character run identifier; when omitted a content hash
#'   is derived, so two identical predictions get the same identifier.
#'
#' @returns An `orchestra_manifest` S7 object.
#'
#' @seealso [verify_manifest()], [gp_predict()]
#'
#' @examples
#' set.seed(1L)
#' grid <- expand.grid(x = seq_len(8L), y = seq_len(8L))
#' grid$yield <- 2 + 0.3 * grid$x + stats::rnorm(nrow(grid), 0, 0.2)
#' fit <- gp_fit(gpfield_spec(c("x", "y"), "yield"), grid, seed = 1L)
#' pred <- gp_predict(fit, grid)
#' as_orchestra_manifest(pred)
#'
#' @export
as_orchestra_manifest <- S7::new_generic("as_orchestra_manifest", "x")

S7::method(as_orchestra_manifest, gpfield_prediction_class) <-
  function(x, ..., run_id = NULL) {
    fit <- x@fit
    loc <- as.data.frame(x@locations)
    outputs <- data.frame(loc, mean = x@mean, sd = x@sd,
                          n_support = x@n_support, check.names = FALSE)

    meta <- list(
      derived = FALSE,
      support = x@support,
      kernel = fit@spec@kernel,
      nu = fit@spec@nu,
      coords = fit@spec@coords,
      time = fit@spec@time,
      response = fit@spec@response,
      hyper = fit@hyper,
      loglik = fit@loglik,
      n_train = length(fit@y_raw))

    seed <- as.integer(fit@seed)
    dh <- .hash_payload(data.frame(), outputs, NULL, NULL, seed)
    rid <- run_id %||% paste0("gpfield-",
                              substr(sub("^sha256:", "", dh), 1L, 12L))

    orchestra_manifest(
      manifest_version   = MANIFEST_VERSION,
      emitter_package    = "gpfield",
      emitter_version    = as.character(utils::packageVersion("gpfield")),
      inferential_target = "predictions",
      run_id             = rid,
      method             = paste0("gpfield:", fit@spec@kernel, ":", x@support),
      seed               = seed,
      params             = data.frame(),
      outputs            = outputs,
      consumed_manifests = list(),
      metadata           = meta,
      timestamp          = Sys.time(),
      data_hash          = dh)
  }

# --- internal ----------------------------------------------------------------

#' Null-coalescing operator
#'
#' @param a,b The candidate and the fallback.
#'
#' @returns `a` unless it is `NULL`, in which case `b`.
#' @noRd
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a

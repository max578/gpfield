# abstention.R -- the typed "I cannot answer" result.
#
# gpfield will not return a confident fine-scale surface it cannot support. When
# the estimated spatial range or the observed support cannot bear a requested
# prediction resolution, the prediction verb returns a `gpfield_abstention`
# rather than a fabricated surface or a stack trace. This is the orchestra's
# calibrated-abstention pattern (Independent-Oracle-aligned): a member that
# refuses cleanly, carrying a machine-readable reason a caller -- or the
# orchestration layer -- can branch on.

#' Construct a typed gpfield abstention
#'
#' Returns a small classed object signalling that a prediction could not be
#' honestly produced, with a machine-readable reason code and human-readable
#' detail. Used in place of a confident-but-wrong prediction so that callers can
#' branch on a refusal rather than trust an unsupported surface.
#'
#' @param reason Character scalar reason code. One of `"range_too_short"` (the
#'   estimated correlation range is shorter than the requested prediction
#'   spacing, so interpolation would be unsupported extrapolation between
#'   effectively independent points), `"support_gap"` (a requested block has too
#'   few -- or no -- observations within its own footprint or one correlation
#'   range of it), `"degenerate_fit"` (the marginal-likelihood optimisation did
#'   not yield a usable hyperparameter set), or `"empty_query"` (the prediction
#'   grid contained no rows).
#' @param detail Character scalar human-readable detail, or `NA`.
#' @param scope Character scalar naming what was refused (default `"gp_predict"`).
#' @param diagnostics Optional named list of the numbers behind the refusal (for
#'   example the estimated range and the requested spacing) so the caller can act
#'   on the margin, not just the verdict.
#'
#' @returns An object of class `"gpfield_abstention"`: a list with `reason`,
#'   `detail`, `scope`, `diagnostics` and `abstained = TRUE`.
#'
#' @examples
#' a <- gpfield_abstention(
#'   "range_too_short",
#'   "estimated range 2.1 m < requested spacing 10 m"
#' )
#' is_gpfield_abstention(a)
#'
#' @export
gpfield_abstention <- function(reason, detail = NA_character_,
                               scope = "gp_predict", diagnostics = list()) {
  .check_abstention_reason(reason)
  if (!is.list(diagnostics)) {
    stop("`diagnostics` must be a list.", call. = FALSE)
  }
  structure(
    list(reason = reason, detail = as.character(detail),
         scope = as.character(scope), diagnostics = diagnostics,
         abstained = TRUE),
    class = "gpfield_abstention")
}

#' Is an object a gpfield abstention?
#'
#' @param x Any object.
#'
#' @returns A single logical: `TRUE` when `x` is a `gpfield_abstention`.
#'
#' @examples
#' is_gpfield_abstention(gpfield_abstention("support_gap"))
#' is_gpfield_abstention(42)
#'
#' @export
is_gpfield_abstention <- function(x) {
  inherits(x, "gpfield_abstention")
}

#' @export
print.gpfield_abstention <- function(x, ...) {
  cat("<gpfield_abstention>\n")
  cat(sprintf("  scope:  %s\n", x$scope))
  cat(sprintf("  reason: %s\n", x$reason))
  if (!is.na(x$detail) && nzchar(x$detail)) {
    cat(sprintf("  detail: %s\n", x$detail))
  }
  if (length(x$diagnostics)) {
    nm <- names(x$diagnostics)
    for (i in seq_along(x$diagnostics)) {
      cat(sprintf("    %s = %s\n", nm[[i]],
                  format(x$diagnostics[[i]], digits = 4L)))
    }
  }
  invisible(x)
}

# --- internal ----------------------------------------------------------------

#' Validate an abstention reason code
#'
#' @param reason The candidate reason code.
#'
#' @returns Invisibly `TRUE`; errors on an unknown code.
#' @noRd
#' @keywords internal
.check_abstention_reason <- function(reason) {
  valid <- c("range_too_short", "support_gap", "degenerate_fit", "empty_query")
  if (length(reason) != 1L || !is.character(reason) ||
      !reason %in% valid) {
    stop("`reason` must be one of ", paste(valid, collapse = ", "), ".",
         call. = FALSE)
  }
  invisible(TRUE)
}

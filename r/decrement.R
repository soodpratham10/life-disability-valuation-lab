# Module 2: multiple decrement models.
# q is a matrix of dependent probabilities q^(j)_{x+k}: one row per policy year,
# one column per decrement (for example column 1 = death, column 2 = lapse).

# Multiple decrement table: l^(tau) at the start of each year, and deaths by cause.
decrement_table <- function(q, radix = 100000) {
  q <- as.matrix(q)
  q_tau <- rowSums(q)
  stopifnot(all(q >= 0), all(q_tau <= 1))
  n <- nrow(q)
  l <- radix * c(1, cumprod(1 - q_tau))       # l at times 0, 1, ..., n
  d <- l[1:n] * q                             # d^(j) for each year and cause
  list(l = l, d = d, d_tau = rowSums(d))
}

# k p^(tau): probability of no decrement for k years, for k = 0, 1, ..., n
survival_tau <- function(q) c(1, cumprod(1 - rowSums(as.matrix(q))))

# k| q^(j): survive k years, then leave by cause j in the next year (k = 0, ..., n-1)
deferred_q <- function(q, j) {
  q <- as.matrix(q)
  survival_tau(q)[seq_len(nrow(q))] * q[, j]
}

# Associated single decrement rates q'^(j) -> dependent rates q^(j),
# assuming UDD in each single decrement table:
#   q^(j) = q'^(j) * integral from 0 to 1 of prod over k != j of (1 - t q'^(k)) dt
# Works for any number of decrements.
udd_single_to_multiple <- function(q_single) {
  q_single <- as.matrix(q_single)
  out <- q_single
  m <- ncol(q_single)
  for (r in seq_len(nrow(q_single))) {
    for (j in seq_len(m)) {
      coef <- 1                                # polynomial in t, ascending powers
      for (k in setdiff(seq_len(m), j)) {
        coef <- c(coef, 0) - q_single[r, k] * c(0, coef)
      }
      out[r, j] <- q_single[r, j] * sum(coef / seq_along(coef))
    }
  }
  out
}

# Dependent rates q^(j) -> associated single rates q'^(j),
# assuming UDD in the multiple decrement table:
#   p'^(j) = (p^(tau)) ^ (q^(j) / q^(tau))
udd_multiple_to_single <- function(q) {
  q <- as.matrix(q)
  q_tau <- rowSums(q)
  share <- q / q_tau
  share[is.nan(share)] <- 0
  1 - (1 - q_tau) ^ share
}

# Constant forces of decrement: probability of leaving by each cause within t
const_force_probs <- function(mu, t = 1) {
  mu_tau <- sum(mu)
  mu / mu_tau * (1 - exp(-mu_tau * t))
}

# EPV of benefits paid at the end of the year of decrement.
# b: one amount per decrement (vector), or a matrix with one row per year.
md_epv_benefits <- function(q, b, i) {
  q <- as.matrix(q)
  n <- nrow(q)
  if (is.null(dim(b))) b <- matrix(b, nrow = n, ncol = ncol(q), byrow = TRUE)
  v <- 1 / (1 + i)
  p <- survival_tau(q)[1:n]
  sum(v^(1:n) * p * rowSums(q * b))
}

# EPV of 1 per year paid at the start of each year while still in force
md_annuity_due <- function(q, i) {
  q <- as.matrix(q)
  n <- nrow(q)
  v <- 1 / (1 + i)
  sum(v^(0:(n - 1)) * survival_tau(q)[1:n])
}

# Level annual premium (start of year, while in force) by the equivalence principle
md_premium <- function(q, b, i) md_epv_benefits(q, b, i) / md_annuity_due(q, i)
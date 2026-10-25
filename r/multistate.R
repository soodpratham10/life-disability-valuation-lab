# k-step transition probabilities for a Markov chain.
# P_list: one matrix (homogeneous chain) or a list of yearly matrices.
kstep_probs <- function(P_list, k) {
  if (is.matrix(P_list)) P_list <- rep(list(P_list), k)
  stopifnot(length(P_list) >= k)
  for (P in P_list[seq_len(k)]) check_transition_matrix(P)
  out <- diag(nrow(P_list[[1]]))
  for (j in seq_len(k)) out <- out %*% P_list[[j]]
  out
}

# Every row must be non-negative and sum to 1.
check_transition_matrix <- function(P, tol = 1e-9) {
  stopifnot(is.matrix(P), nrow(P) == ncol(P),
            all(P >= 0), all(abs(rowSums(P) - 1) < tol))
  invisible(TRUE)
}

# Turn a matrix of off-diagonal intensities into a generator matrix Q:
# the diagonal is minus the sum of the rest of each row.
make_generator <- function(M) {
  diag(M) <- 0
  diag(M) <- -rowSums(M)
  M
}

# Solve Kolmogorov's forward equations with Euler's method.
# mu: either a square matrix of constant intensities (off-diagonal entries
#     are mu^ij; the diagonal is ignored), or a function of time t that
#     returns such a matrix.
# t: horizon in years. h: step size (t must be a whole number of steps).
# Returns the matrix whose (i, j) entry approximates tp_x^ij.
euler_kolmogorov <- function(mu, t, h) {
  mu_fun <- if (is.function(mu)) mu else function(s) mu
  n_steps <- round(t / h)
  stopifnot(h > 0, abs(n_steps * h - t) < 1e-9)
  P <- diag(nrow(mu_fun(0)))
  for (s in seq_len(n_steps)) {
    Q <- make_generator(mu_fun((s - 1) * h))
    P <- P + h * (P %*% Q)
  }
  P
}
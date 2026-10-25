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

# Solve Kolmogorov's forward equations with Euler's method, keeping every step.
# mu: either a square matrix of constant intensities (off-diagonal entries
#     are mu^ij; the diagonal is ignored), or a function of time t that
#     returns such a matrix.
# t: horizon in years. h: step size (t must be a whole number of steps).
# Returns an array path[step, from, to]; step 1 is time 0.
# States are numbered from 1 in R (e.g. healthy = 1, disabled = 2, dead = 3).
kolmogorov_path <- function(mu, t, h) {
  mu_fun <- if (is.function(mu)) mu else function(s) mu
  n_steps <- round(t / h)
  stopifnot(h > 0, abs(n_steps * h - t) < 1e-9)
  n <- nrow(mu_fun(0))
  path <- array(0, dim = c(n_steps + 1, n, n))
  path[1, , ] <- diag(n)
  for (s in seq_len(n_steps)) {
    Q <- make_generator(mu_fun((s - 1) * h))
    P <- path[s, , ]
    path[s + 1, , ] <- P + h * (P %*% Q)
  }
  path
}

# Probabilities at time t only: the (i, j) entry approximates tp_x^ij.
euler_kolmogorov <- function(mu, t, h) {
  path <- kolmogorov_path(mu, t, h)
  path[dim(path)[1], , ]
}

# EPV of a continuous annuity of 1 per year, paid while in state j,
# for a life now in state i, over n years, force of interest delta.
# Trapezoid rule applied to exp(-delta * t) * tp^ij.
epv_annuity <- function(mu, i, j, n, delta, h = 0.01) {
  path <- kolmogorov_path(mu, n, h)
  t <- (seq_len(dim(path)[1]) - 1) * h
  f <- exp(-delta * t) * path[, i, j]
  h * sum((f[-1] + f[-length(f)]) / 2)
}

# EPV of 1 paid immediately on every transition into state j,
# for a life now in state i, over n years.
epv_insurance <- function(mu, i, j, n, delta, h = 0.01) {
  mu_fun <- if (is.function(mu)) mu else function(s) mu
  path <- kolmogorov_path(mu, n, h)
  t <- (seq_len(dim(path)[1]) - 1) * h
  f <- sapply(seq_along(t), function(s) {
    M <- mu_fun(t[s])
    diag(M) <- 0
    k <- setdiff(seq_len(nrow(M)), j)
    exp(-delta * t[s]) * sum(path[s, i, k] * M[k, j])
  })
  h * sum((f[-1] + f[-length(f)]) / 2)
}

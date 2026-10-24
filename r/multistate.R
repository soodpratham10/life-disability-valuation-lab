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
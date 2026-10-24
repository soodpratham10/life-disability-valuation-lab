library(testthat)
source("../r/multistate.R")

test_that("two-step probability in a 2-state chain", {
  P <- matrix(c(0.7, 0.3,
                0.4, 0.6), nrow = 2, byrow = TRUE)
  # 0.4*0.3 + 0.6*0.6 = 0.48
  expect_equal(kstep_probs(P, 2)[2, 2], 0.48)
})

test_that("three-state chain with absorbing state", {
  P <- matrix(c(0.8, 0.1, 0.1,
                0.2, 0.6, 0.2,
                0.0, 0.0, 1.0), nrow = 3, byrow = TRUE)
  P2 <- kstep_probs(P, 2)
  expect_equal(P2[1, 3], 0.20)            # active -> dead in 2 years
  expect_equal(rowSums(P2), c(1, 1, 1))   # rows still sum to 1
})

test_that("invalid matrix is rejected", {
  expect_error(check_transition_matrix(matrix(c(0.5, 0.6, 0.5, 0.5), 2)))
})
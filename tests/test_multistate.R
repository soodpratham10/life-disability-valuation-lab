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

mu <- matrix(c(0, 0.10, 0.05,
               0, 0,    0.20,
               0, 0,    0), nrow = 3, byrow = TRUE)

test_that("one Euler step of h = 0.5 matches the hand calculation", {
  P <- euler_kolmogorov(mu, t = 0.5, h = 0.5)
  expect_equal(P[1, ], c(0.925, 0.05, 0.025))
  expect_equal(P[2, ], c(0, 0.9, 0.1))
})

test_that("two steps of h = 0.5 match the hand calculation", {
  P <- euler_kolmogorov(mu, t = 1, h = 0.5)
  expect_equal(P[1, ], c(0.855625, 0.09125, 0.053125))
  expect_equal(P[2, ], c(0, 0.81, 0.19))
})

test_that("rows sum to 1 and the dead state is absorbing", {
  P <- euler_kolmogorov(mu, t = 5, h = 0.01)
  expect_equal(rowSums(P), c(1, 1, 1))
  expect_equal(P[3, ], c(0, 0, 1))
})

test_that("small steps approach the closed-form answers", {
  P <- euler_kolmogorov(mu, t = 1, h = 0.001)
  expect_equal(P[1, 1], exp(-0.15), tolerance = 1e-4)
  expect_equal(P[2, 2], exp(-0.20), tolerance = 1e-4)
  expect_equal(P[1, 2], 2 * (exp(-0.15) - exp(-0.20)), tolerance = 1e-4)
})

test_that("a function of time with constant intensities gives the same answer", {
  P1 <- euler_kolmogorov(mu, t = 1, h = 0.5)
  P2 <- euler_kolmogorov(function(s) mu, t = 1, h = 0.5)
  expect_equal(P1, P2)
})
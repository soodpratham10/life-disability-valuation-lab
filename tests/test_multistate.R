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

delta <- 0.06

test_that("annuities over all states add up to a certain annuity", {
  total <- sum(sapply(1:3, function(j) epv_annuity(mu, 1, j, n = 20, delta)))
  expect_equal(total, (1 - exp(-delta * 20)) / delta, tolerance = 1e-6)
})

test_that("healthy-to-healthy annuity matches the closed form", {
  # a00 = (1 - exp(-(mu01 + mu02 + delta) n)) / (mu01 + mu02 + delta)
  exact <- (1 - exp(-0.21 * 20)) / 0.21
  expect_equal(epv_annuity(mu, 1, 1, n = 20, delta), exact, tolerance = 2e-3)
})

test_that("healthy-to-disabled annuity matches the closed form", {
  exact <- 2 * ((1 - exp(-0.21 * 20)) / 0.21 - (1 - exp(-0.26 * 20)) / 0.26)
  expect_equal(epv_annuity(mu, 1, 2, n = 20, delta), exact, tolerance = 2e-3)
})

test_that("insurance on entry to the dead state matches the closed form", {
  # A02 = mu02 * a00 + mu12 * a01
  a00 <- (1 - exp(-0.21 * 20)) / 0.21
  a01 <- 2 * ((1 - exp(-0.21 * 20)) / 0.21 - (1 - exp(-0.26 * 20)) / 0.26)
  expect_equal(epv_insurance(mu, 1, 3, n = 20, delta),
               0.05 * a00 + 0.20 * a01, tolerance = 2e-3)
})

exact_a00 <- (1 - exp(-0.21 * 20)) / 0.21
exact_a01 <- 2 * ((1 - exp(-0.21 * 20)) / 0.21 - (1 - exp(-0.26 * 20)) / 0.26)
exact_A02 <- 0.05 * exact_a00 + 0.20 * exact_a01

test_that("disability income premium matches the closed form", {
  benefit <- epv_annuity(mu, 1, 2, n = 20, delta)
  P <- equivalence_premium(benefit, mu, start = 1, premium_states = 1,
                           n = 20, delta = delta)
  expect_equal(P, exact_a01 / exact_a00, tolerance = 5e-3)
})

test_that("death benefit premium matches the closed form", {
  benefit <- 100 * epv_insurance(mu, 1, 3, n = 20, delta)
  P <- equivalence_premium(benefit, mu, start = 1, premium_states = 1,
                           n = 20, delta = delta)
  expect_equal(P, 100 * exact_A02 / exact_a00, tolerance = 5e-3)
})

test_that("combined benefits give the combined premium", {
  benefit <- epv_annuity(mu, 1, 2, n = 20, delta) +
    10 * epv_insurance(mu, 1, 3, n = 20, delta)
  P <- equivalence_premium(benefit, mu, start = 1, premium_states = 1,
                           n = 20, delta = delta)
  expect_equal(P, (exact_a01 + 10 * exact_A02) / exact_a00, tolerance = 5e-3)
})

test_that("premiums and benefits have equal EPV at issue", {
  benefit <- 100 * epv_insurance(mu, 1, 3, n = 20, delta)
  P <- equivalence_premium(benefit, mu, start = 1, premium_states = 1,
                           n = 20, delta = delta)
  expect_equal(P * epv_annuity(mu, 1, 1, n = 20, delta), benefit)
})
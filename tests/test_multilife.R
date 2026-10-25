library(testthat)
source("../r/multistate.R")
source("../r/multilife.R")

# Two years, two lives (my own numbers, worked by hand)
qx <- c(0.10, 0.20)
qy <- c(0.20, 0.25)

test_that("joint-life and last-survivor survival", {
  # both alive: 0.9 * 0.8 = 0.72, then 0.72 * 0.8 * 0.75 = 0.432
  expect_equal(joint_survival(qx, qy), c(1, 0.72, 0.432))
  # at least one alive: 0.9 + 0.8 - 0.72 = 0.98, then 0.72 + 0.6 - 0.432 = 0.888
  expect_equal(last_survivor_survival(qx, qy), c(1, 0.98, 0.888))
})

test_that("annuities and insurances with no interest", {
  expect_equal(joint_annuity(qx, qy, i = 0), 1 + 0.72)
  expect_equal(first_death_insurance(qx, qy, i = 0), 1 - 0.432)
  expect_equal(second_death_insurance(qx, qy, i = 0), 1 - 0.888)
  # (y) alive and (x) dead at time 1: 0.8 * 0.1 = 0.08
  expect_equal(reversionary_annuity(qx, qy, i = 0), 0.08)
})

test_that("discounting", {
  expect_equal(joint_annuity(qx, qy, i = 0.1), 1 + 0.72 / 1.1)
})

test_that("joint plus last survivor equals the two single lives", {
  ax <- annuity_due_status(survival_curve(qx), 0.05)
  ay <- annuity_due_status(survival_curve(qy), 0.05)
  expect_equal(joint_annuity(qx, qy, 0.05) + last_survivor_annuity(qx, qy, 0.05), ax + ay)
})

test_that("contingent probabilities", {
  # year 1: 0.1 * (1 - 0.1) = 0.09; year 2: 0.72 * 0.2 * (1 - 0.125) = 0.126
  expect_equal(contingent_first(qx, qy), 0.09 + 0.126)
  # x dies first or y dies first = the joint status fails
  expect_equal(contingent_first(qx, qy) + contingent_first(qy, qx), 1 - 0.432)
})

test_that("constant forces: expected time to first and last death", {
  expect_equal(e_first_death_const(0.01, 0.02), 1 / 0.03)
  expect_equal(e_last_death_const(0.01, 0.02), 100 + 50 - 1 / 0.03)
})

test_that("Makeham rates reproduce the SOA Standard Ultimate Life Table", {
  expect_equal(makeham_q(60, 1), 0.003398, tolerance = 1e-3)
  expect_equal(makeham_q(70, 1), 0.010413, tolerance = 1e-3)
})

test_that("two lives are a multiple state model (cross-chapter check)", {
  # states: 1 = both alive, 2 = only y alive, 3 = only x alive, 4 = both dead
  mx <- 0.01; my <- 0.02
  mu <- matrix(c(0, mx, my, 0,
                 0, 0,  0,  my,
                 0, 0,  0,  mx,
                 0, 0,  0,  0), nrow = 4, byrow = TRUE)
  P <- euler_kolmogorov(mu, t = 10, h = 0.001)
  expect_equal(P[1, 1], exp(-0.03 * 10), tolerance = 1e-4)
  expect_equal(1 - P[1, 4], exp(-0.1) + exp(-0.2) - exp(-0.3), tolerance = 1e-4)
})
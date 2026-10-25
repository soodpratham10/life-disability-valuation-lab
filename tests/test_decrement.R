library(testthat)
source("../r/multistate.R")
source("../r/decrement.R")

# Two years, two decrements: column 1 = death, column 2 = lapse
q <- rbind(c(0.01, 0.10),
           c(0.02, 0.05))

test_that("decrement table matches the hand calculation", {
  tab <- decrement_table(q, radix = 1000)
  # l1 = 1000 * (1 - 0.11) = 890; l2 = 890 * (1 - 0.07) = 827.7
  expect_equal(tab$l, c(1000, 890, 827.7))
  # year 2: deaths 890 * 0.02 = 17.8, lapses 890 * 0.05 = 44.5
  expect_equal(tab$d[2, ], c(17.8, 44.5))
})

test_that("survival and deferred probabilities", {
  expect_equal(survival_tau(q)[3], 0.89 * 0.93)
  expect_equal(deferred_q(q, 1)[2], 0.89 * 0.02)
})

test_that("UDD in single tables: single rates to dependent rates", {
  # two decrements: q1 = q1'(1 - q2'/2), q2 = q2'(1 - q1'/2)
  two <- udd_single_to_multiple(matrix(c(0.1, 0.2), nrow = 1))
  expect_equal(as.vector(two), c(0.09, 0.19))
  # three decrements: q1 = q1'(1 - (q2' + q3')/2 + q2' q3'/3)
  three <- udd_single_to_multiple(matrix(c(0.1, 0.2, 0.3), nrow = 1))
  expect_equal(three[1, 1], 0.1 * (1 - 0.5 / 2 + 0.06 / 3))
})

test_that("UDD in the multiple decrement table: dependent to single rates", {
  # equal dependent rates 0.1 and 0.1: p' = 0.8^(1/2) for each
  single <- udd_multiple_to_single(matrix(c(0.1, 0.1), nrow = 1))
  expect_equal(as.vector(single), rep(1 - sqrt(0.8), 2))
  # the single survival probabilities multiply back to p^(tau)
  expect_equal(prod(1 - single), 0.8)
})

test_that("constant forces of decrement", {
  probs <- const_force_probs(c(0.02, 0.08))
  expect_equal(probs[1], 0.2 * (1 - exp(-0.1)))
  expect_equal(sum(probs), 1 - exp(-0.1))
})

test_that("EPV, annuity and premium match the hand calculation", {
  # death benefit 1000, nothing on lapse
  expect_equal(md_epv_benefits(q, c(1000, 0), i = 0), 10 + 17.8)
  epv <- md_epv_benefits(q, c(1000, 0), i = 0.1)
  expect_equal(epv, 10 / 1.1 + 17.8 / 1.1^2)
  ann <- md_annuity_due(q, i = 0.1)
  expect_equal(ann, 1 + 0.89 / 1.1)
  expect_equal(md_premium(q, c(1000, 0), i = 0.1), epv / ann)
})

test_that("a decrement model is a multiple state model (cross-module check)", {
  # states: 1 = in force, 2 = dead, 3 = lapsed; constant forces 0.02 and 0.08
  mu <- matrix(c(0, 0.02, 0.08,
                 0, 0,    0,
                 0, 0,    0), nrow = 3, byrow = TRUE)
  P <- euler_kolmogorov(mu, t = 1, h = 0.001)
  expect_equal(P[1, 2], const_force_probs(c(0.02, 0.08))[1], tolerance = 1e-4)
  expect_equal(P[1, 3], const_force_probs(c(0.02, 0.08))[2], tolerance = 1e-4)
})
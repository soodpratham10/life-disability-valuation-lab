library(testthat)
source("../r/experience.R")

test_that("estimator on a hand-checkable table", {
  experience <- list(
    exposure    = data.frame(state_from = c(1, 2), exposure = c(100, 50)),
    transitions = data.frame(state_from = c(1, 1, 2), state_to = c(2, 3, 3),
                             n = c(10, 5, 10)))
  est <- estimate_intensities(experience, 3)
  expect_equal(est$mu[1, 2], 10 / 100)
  expect_equal(est$mu[1, 3], 5 / 100)
  expect_equal(est$mu[2, 3], 10 / 50)
  expect_equal(est$se[1, 2], sqrt(10) / 100)
})

test_that("SQL queries on a tiny hand-built database", {
  spells <- data.frame(
    person_id  = c(1, 1, 2, 3),
    state_from = c(1, 2, 1, 1),
    state_to   = c(2, 3, 3, NA),
    start_time = c(0, 2, 0, 0),
    end_time   = c(2, 3, 1, 5))
  con <- write_experience_db(spells, ":memory:")
  ex <- query_experience(con)
  DBI::dbDisconnect(con)
  # time in state 1 = 2 + 1 + 5 = 8; time in state 2 = 1
  expect_equal(ex$exposure$exposure, c(8, 1))
  expect_equal(ex$transitions$n, c(1, 1, 1))
  est <- estimate_intensities(ex, 3)
  expect_equal(est$mu[1, 2], 1 / 8)
  expect_equal(est$mu[1, 3], 1 / 8)
  expect_equal(est$mu[2, 3], 1 / 1)
})

test_that("simulated experience recovers the true intensities", {
  mu_true <- matrix(c(0, 0.10, 0.05,
                      0, 0,    0.20,
                      0, 0,    0), nrow = 3, byrow = TRUE)
  spells <- simulate_experience(mu_true, n = 10000, obs_years = 5, seed = 2026)
  expect_true(max(spells$end_time) <= 5)
  expect_false(any(spells$state_from == 3))
  con <- write_experience_db(spells, ":memory:")
  est <- estimate_intensities(query_experience(con), 3)
  DBI::dbDisconnect(con)
  expect_equal(est$mu[1, 2], 0.10, tolerance = 0.15)
  expect_equal(est$mu[1, 3], 0.05, tolerance = 0.15)
  expect_equal(est$mu[2, 3], 0.20, tolerance = 0.15)
  expect_true(abs(est$mu[1, 2] - 0.10) < 4 * est$se[1, 2])
  expect_true(abs(est$mu[1, 3] - 0.05) < 4 * est$se[1, 3])
  expect_true(abs(est$mu[2, 3] - 0.20) < 4 * est$se[2, 3])
})
library(testthat)
source("../r/multilife.R")
source("../r/experience.R")

# ===================== Chapter 1 =====================

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

# ===================== Chapter 2 =====================

test_that("exit study SQL on a hand-built block of policies", {
  # 5 three-year policies:
  #   1 dies in year 1, 2 lapses in year 2, 3 reaches the end,
  #   4 dies in year 3, 5 lapses in year 1
  policies <- data.frame(
    policy_id = 1:5,
    term      = 3,
    exit_year = c(1, 2, NA, 3, 1),
    cause     = c("death", "lapse", NA, "death", "lapse"))
  con <- write_policy_db(policies, ":memory:")
  study <- query_exit_study(con)
  DBI::dbDisconnect(con)
  # year 1: all 5 in force; year 2: policies 2, 3, 4; year 3: policies 3, 4
  expect_equal(study$in_force, c(5, 3, 2))
  expect_equal(study$deaths, c(1, 0, 1))
  expect_equal(study$lapses, c(1, 1, 0))
  est <- estimate_decrement_rates(study)
  expect_equal(est$q_death[1], 1 / 5)
  # assumed death rate 0.1 each year: expected deaths = 0.1 * (5 + 3 + 2) = 1, actual = 2
  ae <- actual_vs_expected(study, matrix(0.1, nrow = 3, ncol = 2))
  expect_equal(ae$ae_ratio[1], 2)
})

test_that("simulated policies recover the true decrement rates", {
  q_true <- cbind(rep(0.01, 10), rep(0.08, 10))
  policies <- simulate_policies(q_true, n = 20000, seed = 2026)
  con <- write_policy_db(policies, ":memory:")
  study <- query_exit_study(con)
  DBI::dbDisconnect(con)
  expect_equal(study$in_force[1], 20000)
  expect_equal(sum(study$deaths) / sum(study$in_force), 0.01, tolerance = 0.10)
  expect_equal(sum(study$lapses) / sum(study$in_force), 0.08, tolerance = 0.05)
  ae <- actual_vs_expected(study, q_true)
  expect_equal(ae$ae_ratio[1], 1, tolerance = 0.10)
  expect_equal(ae$ae_ratio[2], 1, tolerance = 0.05)
})

# ===================== Chapter 3 =====================

test_that("couples study SQL on a hand-built group of couples", {
  # 4 couples observed for 2 years (times are years from now; NA = still alive):
  #   1: x dies at 0.5, y alive          -> x dies first in year 1
  #   2: x dies at 1.5, y dies at 0.7    -> y dies first in year 1
  #   3: both alive
  #   4: x dies at 1.2, y dies at 1.8    -> x dies first in year 2
  couples <- data.frame(
    couple_id    = 1:4,
    age_x        = NA,
    age_y        = NA,
    obs_years    = 2,
    death_time_x = c(0.5, 1.5, NA, 1.2),
    death_time_y = c(NA, 0.7, NA, 1.8))
  con <- write_couple_db(couples, ":memory:")
  study <- query_couple_study(con)
  DBI::dbDisconnect(con)
  expect_equal(study$both_alive, c(4, 2))           # start of year 2: couples 3 and 4
  expect_equal(study$at_least_one_alive, c(4, 4))   # every couple still has someone at time 1
  expect_equal(study$x_dies_first, c(1, 1))
  expect_equal(study$y_dies_first, c(1, 0))
})

test_that("simulated couples match the joint-life and last-survivor model", {
  qx <- rep(0.02, 20)
  qy <- rep(0.03, 20)
  couples <- simulate_couples(qx, qy, n = 20000, seed = 2026)
  con <- write_couple_db(couples, ":memory:")
  study <- query_couple_study(con)
  DBI::dbDisconnect(con)
  cmp <- compare_couples(study, qx, qy)
  expect_equal(cmp$both_alive_observed[20], cmp$both_alive_model[20], tolerance = 0.05)
  expect_equal(cmp$any_alive_observed[20], cmp$any_alive_model[20], tolerance = 0.05)
  expect_equal(sum(study$x_dies_first) / 20000, contingent_first(qx, qy), tolerance = 0.05)
  expect_equal(sum(study$y_dies_first) / 20000, contingent_first(qy, qx), tolerance = 0.05)
})
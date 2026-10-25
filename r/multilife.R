# Chapter 3: Two Lives. Multiple life models for two independent lives.
# qx, qy: one-year death probabilities for each life, year by year from now
# (qx[k + 1] = q_{x+k}). Both vectors must have the same length n.

# k p for k = 0, 1, ..., n
survival_curve <- function(q) c(1, cumprod(1 - q))

# Joint-life status: both alive.  k p_xy = k p_x * k p_y
joint_survival <- function(qx, qy) {
  stopifnot(length(qx) == length(qy))
  survival_curve(qx) * survival_curve(qy)
}

# Last-survivor status: at least one alive.  k p_xy-bar = k p_x + k p_y - k p_xy
last_survivor_survival <- function(qx, qy) {
  sx <- survival_curve(qx); sy <- survival_curve(qy)
  sx + sy - sx * sy
}

# EPV of 1 per year at the start of each year while the status survives (n years)
annuity_due_status <- function(surv, i) {
  n <- length(surv) - 1
  v <- 1 / (1 + i)
  sum(v^(0:(n - 1)) * surv[1:n])
}

# EPV of 1 at the end of the year in which the status fails, within n years
insurance_status <- function(surv, i) {
  n <- length(surv) - 1
  v <- 1 / (1 + i)
  sum(v^(1:n) * (surv[1:n] - surv[2:(n + 1)]))
}

joint_annuity          <- function(qx, qy, i) annuity_due_status(joint_survival(qx, qy), i)
last_survivor_annuity  <- function(qx, qy, i) annuity_due_status(last_survivor_survival(qx, qy), i)
first_death_insurance  <- function(qx, qy, i) insurance_status(joint_survival(qx, qy), i)
second_death_insurance <- function(qx, qy, i) insurance_status(last_survivor_survival(qx, qy), i)

# Reversionary annuity: pays (y) each year that (y) is alive and (x) has died.
#   a_{x|y} = a_y - a_xy
reversionary_annuity <- function(qx, qy, i) {
  annuity_due_status(survival_curve(qy), i) - joint_annuity(qx, qy, i)
}

# Contingent probability: (x) dies before (y), within n years.
# Within each year, deaths are uniformly distributed for each life, so
#   P(x dies first in the year | both alive) = qx (1 - qy / 2)
contingent_first <- function(qx, qy) {
  s <- joint_survival(qx, qy)
  n <- length(qx)
  sum(s[1:n] * qx * (1 - qy / 2))
}

# Constant forces of mortality: expected time to first and to last death
e_first_death_const <- function(mux, muy) 1 / (mux + muy)
e_last_death_const  <- function(mux, muy) 1 / mux + 1 / muy - 1 / (mux + muy)

# Makeham mortality, mu_x = A + B c^x, giving one-year death rates from a given age.
# Default parameters are those of the SOA Standard Ultimate Life Table.
makeham_q <- function(age, n, A = 0.00022, B = 2.7e-6, c = 1.124) {
  x <- age + 0:(n - 1)
  1 - exp(-A - B * c^x * (c - 1) / log(c))
}
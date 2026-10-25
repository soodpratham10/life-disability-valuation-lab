# ===================== Shared helper =====================

# Find a SQL file whether we run from the project root or from tests/
read_sql <- function(name) {
  for (p in c(file.path("sql", name), file.path("..", "sql", name))) {
    if (file.exists(p)) return(paste(readLines(p, warn = FALSE), collapse = "\n"))
  }
  stop("Cannot find sql/", name)
}

# ===================== Chapter 1: Detours =====================

# Simulate n people who all start in state 1 and are observed for obs_years.
# mu: matrix of constant intensities (off-diagonal = mu^ij).
# Returns one row per spell (a stretch of time in one state).
simulate_experience <- function(mu, n, obs_years, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  rate <- rowSums(mu)
  out <- vector("list", n)
  for (p in seq_len(n)) {
    s <- 1L; t <- 0
    fr <- integer(0); to <- integer(0); st <- numeric(0); en <- numeric(0)
    while (rate[s] > 0) {
      e <- t + rexp(1, rate[s])
      if (e >= obs_years) {            # still in this state when observation ends
        fr <- c(fr, s); to <- c(to, NA_integer_)
        st <- c(st, t); en <- c(en, obs_years)
        break
      }
      nxt <- sample.int(ncol(mu), 1, prob = mu[s, ])
      fr <- c(fr, s); to <- c(to, nxt); st <- c(st, t); en <- c(en, e)
      t <- e; s <- nxt
    }
    out[[p]] <- list(person = rep(p, length(fr)), fr = fr, to = to, st = st, en = en)
  }
  data.frame(
    person_id  = unlist(lapply(out, `[[`, "person")),
    state_from = unlist(lapply(out, `[[`, "fr")),
    state_to   = unlist(lapply(out, `[[`, "to")),
    start_time = unlist(lapply(out, `[[`, "st")),
    end_time   = unlist(lapply(out, `[[`, "en"))
  )
}

# Create the SQLite table of spells. Returns the connection.
write_experience_db <- function(spells, path = ":memory:") {
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  DBI::dbExecute(con, "DROP TABLE IF EXISTS spell")
  DBI::dbExecute(con, read_sql("schema.sql"))
  spells$spell_id <- seq_len(nrow(spells))
  DBI::dbWriteTable(con, "spell", spells, append = TRUE)
  con
}

# Run the two SQL queries: total time in each state, and transition counts.
query_experience <- function(con) {
  list(exposure    = DBI::dbGetQuery(con, read_sql("exposure.sql")),
       transitions = DBI::dbGetQuery(con, read_sql("transitions.sql")))
}

# Occurrence-exposure estimate: mu_hat^ij = (transitions i to j) / (time in i).
# The standard error uses Var(mu_hat) ~ D / T^2, so se = sqrt(D) / T.
estimate_intensities <- function(experience, n_states) {
  expo <- experience$exposure
  tr <- experience$transitions
  mu <- se <- matrix(0, n_states, n_states)
  for (r in seq_len(nrow(tr))) {
    i <- tr$state_from[r]; j <- tr$state_to[r]
    time_in_i <- expo$exposure[expo$state_from == i]
    mu[i, j] <- tr$n[r] / time_in_i
    se[i, j] <- sqrt(tr$n[r]) / time_in_i
  }
  list(mu = mu, se = se)
}

# ===================== Chapter 2: Exits =====================

# Simulate n term policies, year by year, using dependent rates q
# (one row per policy year; column 1 = death, column 2 = lapse).
# Returns one row per policy: the year it ended and why (NA if it reached the end).
simulate_policies <- function(q, n, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  q <- as.matrix(q)
  term <- nrow(q)
  exit_year <- rep(NA_integer_, n)
  cause <- rep(NA_character_, n)
  active <- rep(TRUE, n)
  for (k in seq_len(term)) {
    idx <- which(active)
    u <- runif(length(idx))
    dead <- u < q[k, 1]
    lapsed <- !dead & u < q[k, 1] + q[k, 2]
    exit_year[idx[dead | lapsed]] <- k
    cause[idx[dead]] <- "death"
    cause[idx[lapsed]] <- "lapse"
    active[idx[dead | lapsed]] <- FALSE
  }
  data.frame(policy_id = seq_len(n), term = term,
             exit_year = exit_year, cause = cause)
}

# Create the SQLite table of policies. Returns the connection.
write_policy_db <- function(policies, path = ":memory:") {
  con <- DBI::dbConnect(RSQLite::SQLite(), path)
  DBI::dbExecute(con, "DROP TABLE IF EXISTS policy")
  DBI::dbExecute(con, read_sql("policy_schema.sql"))
  DBI::dbWriteTable(con, "policy", policies, append = TRUE)
  con
}

# Run the experience study query: in force, deaths and lapses by policy year
query_exit_study <- function(con) {
  DBI::dbGetQuery(con, read_sql("exit_study.sql"))
}

# Estimated dependent rates by policy year, with standard errors
#   q_hat = exits / in force at the start of the year,  se = sqrt(q (1 - q) / in force)
estimate_decrement_rates <- function(study) {
  study$q_death  <- study$deaths / study$in_force
  study$q_lapse  <- study$lapses / study$in_force
  study$se_death <- sqrt(study$q_death * (1 - study$q_death) / study$in_force)
  study$se_lapse <- sqrt(study$q_lapse * (1 - study$q_lapse) / study$in_force)
  study
}

# Actual versus expected: compare the study with an assumed set of dependent rates q
actual_vs_expected <- function(study, q) {
  q <- as.matrix(q)
  k <- study$policy_year
  exp_deaths <- sum(study$in_force * q[k, 1])
  exp_lapses <- sum(study$in_force * q[k, 2])
  data.frame(
    decrement = c("Death", "Lapse"),
    actual    = c(sum(study$deaths), sum(study$lapses)),
    expected  = c(exp_deaths, exp_lapses),
    ae_ratio  = c(sum(study$deaths) / exp_deaths, sum(study$lapses) / exp_lapses)
  )
}
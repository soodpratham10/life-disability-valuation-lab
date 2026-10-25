# Find a SQL file whether we run from the project root or from tests/
read_sql <- function(name) {
  for (p in c(file.path("sql", name), file.path("..", "sql", name))) {
    if (file.exists(p)) return(paste(readLines(p, warn = FALSE), collapse = "\n"))
    }
  stop("Cannot find sql/", name)
}

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

# Create the SQLite database and load the spells. Returns the connection.
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
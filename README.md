# Actuarial Models Lab (R)

An R toolkit that implements life contingencies models from first principles, verifies every function against hand-derived answers, estimates its assumptions from experience data stored in SQL, cross-checks its results in Excel, and puts an interactive calculator on top.

![Disability & Death Policy Calculator](docs/calculator.png)

## What this project is about

> Once a policy is sold, how much money must the insurer hold to keep its promise, and how do we explain the gap between what we expected and what actually happened?

Most insurance models start from "alive or dead." Real products, such as disability income, depend on a person moving between several states over time. This project builds that machinery step by step, then connects it to premiums, reserves, profit and surplus analysis.

## The plan

The project follows one story from start to finish:

1. **How do people move?** Multiple state, multiple decrement and multiple life models describe what can happen to a policyholder and with what probability.
2. **What does it cost?** Premiums and pension contributions are set so that the expected value of what comes in balances what goes out.
3. **What actually happened?** Profit testing and analysis of surplus show whether a product made money and which assumption (interest, mortality, expenses, lapses) drove the result.
4. **Modern products.** Universal life and embedded options show how flexible accounts and guarantees change the risk.

## Tools

| Tool | Role | Status |
|---|---|---|
| R | Model engine and automated tests | In use |
| SQL (SQLite) | Experience data: time spent in each state and transitions between states, aggregated with SQL queries | In use |
| Excel | Assumptions and an independent rebuild of the calculations in spreadsheet formulas, to cross-check the R results | In use |
| Shiny | Interactive calculator, one tab per module | v1 |

The pipeline: simulated experience data is stored in SQLite, SQL queries aggregate it, R estimates the transition intensities and runs the models, Excel independently reproduces the results, and the calculator shows them.

## What works today

### Module 1: multiple state models

- **Transition probabilities for discrete-time chains**: k-step probabilities for homogeneous and non-homogeneous Markov chains, with input validation
- **Kolmogorov forward equations**: a general Euler solver that takes any set of transition intensities (constant or varying with time) and returns the probability of being in each state at any time
- **State-dependent annuities and insurances**: expected present values of payments made while in a state, or on entry into a state
- **Equivalence-principle premiums**: the level premium that balances the EPV of benefits against the EPV of premiums

### Data layer: estimating intensities from experience

- **Simulation**: synthetic policyholders move between healthy, disabled and dead according to known "true" intensities, observed for a fixed period
- **SQLite database**: one row per spell (a stretch of time a person spent in one state), with the state moved to, or empty if still there when observation ended
- **SQL queries** (`sql/`): total exposure in each state and the number of each type of transition
- **Estimation**: occurrence-exposure estimates of each intensity with standard errors and 95% intervals

With 20,000 simulated lives observed for 5 years, the estimates land close to the truth, and every true value falls inside its 95% interval:

| Transition | True value | Estimate | 95% interval |
|---|---|---|---|
| Healthy to disabled | 0.10 | 0.1001 | 0.0977 to 0.1024 |
| Death while healthy | 0.05 | 0.0512 | 0.0495 to 0.0528 |
| Death while disabled | 0.20 | 0.2010 | 0.1937 to 0.2084 |

### Excel cross-check

`excel/disability_death_crosscheck.xlsx` rebuilds the calculations independently, using spreadsheet formulas only:

- an **Euler sheet** that solves the forward equations step by step and evaluates the annuity and insurance integrals
- a **closed-form sheet** with the exact formulas for constant intensities
- an **experience sheet** that re-estimates the intensities from the SQL query results, giving the same estimates as R

At the default assumptions, R and Excel agree to the cent, and both are within 0.03% of the exact closed-form premium (the gap is the Euler discretisation error):

| | R calculator | Excel (Euler) | Exact closed form |
|---|---|---|---|
| Annual premium | $2,433.23 | $2,433.23 | $2,432.57 |
| EPV of disability benefit | $15,960.66 | $15,960.66 | $15,955.76 |
| EPV of death benefit | $8,313.12 | $8,313.12 | $8,312.26 |

### Calculator v1: Disability & Death

A Shiny app (`app/`) that wraps the engine. You set the transition intensities, interest rate, policy term and benefits, and it shows the annual premium, the expected present value of each benefit, and how the probability of being healthy, disabled or dead changes over time. One button loads the intensities estimated from the SQL experience data into the model.

### Example

```r
source("r/multistate.R")

# States: 1 = healthy, 2 = disabled, 3 = dead (illustrative intensities)
mu <- matrix(c(0, 0.10, 0.05,
               0, 0,    0.20,
               0, 0,    0), nrow = 3, byrow = TRUE)

# Annual premium, paid while healthy, for 1 per year while disabled (20 years)
benefit <- epv_annuity(mu, i = 1, j = 2, n = 20, delta = 0.06)
equivalence_premium(benefit, mu, start = 1, premium_states = 1,
                    n = 20, delta = 0.06)
# about 0.369 per year
```

## The mathematics

Notation follows Dickson, Hardy and Waters, *Actuarial Mathematics for Life Contingent Risks*.

### States and transition probabilities

A policyholder moves between a finite set of states (for example healthy, disabled, dead). The probability of being in state $j$ at age $x+t$, given state $i$ at age $x$, is

$$
{}_tp_x^{ij} = \Pr\big[\text{in state } j \text{ at age } x+t \mid \text{in state } i \text{ at age } x\big]
$$

The process is Markov: the future depends only on the current state. The transition intensity from $i$ to $j$ is

$$
\mu_x^{ij} = \lim_{h \to 0^+} \frac{{}_hp_x^{ij}}{h}, \qquad i \neq j
$$

### Kolmogorov's forward equations

$$
\frac{d}{dt}\,{}_tp_x^{ij} = \sum_{k \neq j} \Big( {}_tp_x^{ik}\,\mu_{x+t}^{kj} - {}_tp_x^{ij}\,\mu_{x+t}^{jk} \Big)
$$

with starting values

$$
{}_0p_x^{ii} = 1, \qquad {}_0p_x^{ij} = 0 \quad (j \neq i)
$$

In words: the probability of being in state $j$ grows with flow in from other states and shrinks with flow out of $j$. These equations have no closed form for general intensities, so they are solved numerically with Euler's method. In matrix form, with step size $h$,

$$
\mathbf{P}(t+h) \approx \mathbf{P}(t) + h\,\mathbf{P}(t)\,\mathbf{Q}(t)
$$

where the generator matrix has off-diagonal entries equal to the intensities and diagonal entries equal to minus the row sums:

$$
Q_{ij} = \mu_{x+t}^{ij} \;\; (i \neq j), \qquad Q_{ii} = -\sum_{j \neq i} \mu_{x+t}^{ij}
$$

### Annuities and insurances by state

The expected present value of 1 per year paid continuously while in state $j$, for a life now in state $i$, over $n$ years at force of interest $\delta$:

$$
\bar{a}_{x:\overline{n}|}^{\,ij} = \int_0^n e^{-\delta t}\; {}_tp_x^{ij}\; dt
$$

The expected present value of 1 paid immediately on every transition into state $j$:

$$
\bar{A}_{x:\overline{n}|}^{\,ij} = \int_0^n e^{-\delta t} \sum_{k \neq j} {}_tp_x^{ik}\,\mu_{x+t}^{kj}\; dt
$$

Both integrals are evaluated with the trapezoid rule on the Euler solution.

### Premiums

Under the equivalence principle, the level premium rate $P$ paid while healthy satisfies

$$
P \cdot \bar{a}_{x:\overline{n}|}^{\,00} = \text{EPV of benefits}
$$

so that

$$
P = \frac{\text{EPV of benefits}}{\bar{a}_{x:\overline{n}|}^{\,00}}
$$

For a policy paying $D$ per year while disabled and $B$ on death, the EPV of benefits is

$$
D\,\bar{a}_{x:\overline{n}|}^{\,01} + B\,\bar{A}_{x:\overline{n}|}^{\,02}
$$

### Estimating intensities from experience

If $D^{ij}$ is the number of observed transitions from state $i$ to state $j$, and $T^{i}$ is the total time all lives spent in state $i$, the maximum likelihood estimate of a constant intensity is

$$
\hat{\mu}^{ij} = \frac{D^{ij}}{T^{i}}
$$

with approximate variance

$$
\text{Var}\big(\hat{\mu}^{ij}\big) \approx \frac{D^{ij}}{\big(T^{i}\big)^2}
$$

The two SQL queries in `sql/` produce exactly the inputs to this formula: `transitions.sql` counts each type of transition, and `exposure.sql` sums the time spent in each state.

### A closed-form check

For constant intensities in the three-state permanent disability model, the probabilities have exact solutions, which the tests and the Excel workbook compare the numerical solver against:

$$
{}_tp_x^{00} = e^{-(\mu^{01}+\mu^{02})\,t}
$$

$$
{}_tp_x^{01} = \frac{\mu^{01}}{\mu^{12}-\mu^{01}-\mu^{02}}\Big(e^{-(\mu^{01}+\mu^{02})\,t} - e^{-\mu^{12}\,t}\Big)
$$

### How the formulas map to code

| Formula | Function |
|---|---|
| k-step transition probabilities | `kstep_probs()` |
| Generator matrix | `make_generator()` |
| Forward equations by Euler's method | `kolmogorov_path()`, `euler_kolmogorov()` |
| Annuity by state | `epv_annuity()` |
| Insurance on entry to a state | `epv_insurance()` |
| Equivalence-principle premium | `equivalence_premium()` |
| Simulated experience | `simulate_experience()` |
| Database and SQL queries | `write_experience_db()`, `query_experience()` |
| Occurrence-exposure estimates | `estimate_intensities()` |

## How correctness is checked

Three independent layers:

1. **Automated tests** (`tests/`): expected values are worked out by hand before the code is written, or derived as closed-form formulas. Examples: one- and two-step Euler results checked by hand, the solver compared to exact exponential formulas, annuities over all states required to add up to a certain annuity, premiums checked against closed-form values, the SQL queries checked on a small hand-built database, and simulated data required to recover the true intensities.
2. **Excel rebuild** (`excel/`): the same calculations implemented separately in spreadsheet formulas, which match R to the cent for the premium and exactly for the intensity estimates.
3. **Closed-form comparison**: both numerical results are compared with the exact answer, so the size of the numerical error is known.

## Important note on assumptions

The intensities used in the examples, tests, workbook and calculator are illustrative numbers chosen so results can be checked, and the experience data is simulated. They are **not calibrated to real data** and are not a pricing basis.

## Getting started

```r
install.packages(c("testthat", "DBI", "RSQLite", "shiny"))

# Run the tests
testthat::test_file("tests/test_multistate.R")
testthat::test_file("tests/test_experience.R")

# Build the experience database (the file is not stored in the repository)
source("r/multistate.R"); source("r/experience.R")
mu_true <- matrix(c(0, 0.10, 0.05,
                    0, 0,    0.20,
                    0, 0,    0), nrow = 3, byrow = TRUE)
spells <- simulate_experience(mu_true, n = 20000, obs_years = 5, seed = 2026)
con <- write_experience_db(spells, "sql/experience.sqlite")
DBI::dbDisconnect(con)

# Launch the calculator
shiny::runApp("app")
```

## Roadmap

| Module | Topic | Status |
|---|---|---|
| 1 | Multiple state models, annuities, insurances, premiums | Done |
| Data layer | SQL experience data and intensity estimation | Done |
| Excel | Independent cross-check workbook | Done |
| Calculator | Disability & Death tab | v1 done |
| 2 | Multiple decrement models (death, lapse, cause-specific benefits) | Next |
| 3 | Multiple life models (joint life, last survivor, contingent) | Planned |
| 4 | Profit testing and analysis of surplus by source | Planned |
| 5 | Pension mathematics | Planned |
| 6 | Universal life | Planned |
| 7 | Embedded options in life insurance and annuities | Planned |

## Repository layout

```
r/          model functions and experience-data functions
sql/        database schema and SQL queries
excel/      independent cross-check workbook
tests/      automated tests with hand-checked expected values
app/        Shiny calculator
docs/       images and write-ups
```

## About

Built alongside my actuarial coursework at the University of Manitoba. Course notes and exam material are not included in this repository.

License: MIT
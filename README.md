# Actuarial Models Lab (R)

An R toolkit that implements life contingencies models from first principles and checks every function against hand-worked answers.

## The question this project answers

> Once a policy is sold, how much money must the insurer hold to keep its promise, and how do we explain the gap between what we expected and what actually happened?

That is valuation and surplus analysis. Each module adds a product or a tool to one pipeline: assumptions, then reserves, then profit, then an explanation of where gains and losses came from.

## Principles

- **Built from first principles.** No actuarial packages. Every formula is implemented and understood.
- **Verified, not just run.** Each function has tests whose expected values were worked out by hand before the code was written.
- **Honest scope.** A module is marked done only when its tests pass.

## Roadmap

| Module | Topic | Status |
|---|---|---|
| 1 | Multiple state models: transition matrices, Kolmogorov forward equations solved with Euler's method, state-dependent annuities and insurances, disability income | In progress |
| 2 | Multiple decrement models: decrement tables, associated single decrements, cause-specific benefits | Planned |
| 3 | Multiple life models: joint life, last survivor, contingent and reversionary benefits | Planned |
| 4 | Profit testing and analysis of surplus by source | Planned |
| 5 | Pension mathematics | Planned |
| 6 | Universal life | Planned |
| 7 | Embedded options in life insurance and annuities | Planned |

## Repository layout

```
r/          model functions
tests/      automated tests with hand-checked expected values
docs/       short write-ups of assumptions and method
outputs/    charts and tables
```

## Running the tests

From the project root in R:

```r
install.packages("testthat")
testthat::test_file("tests/test_multistate.R")
```

## Current progress

- `kstep_probs()`: k-step transition probabilities for homogeneous and non-homogeneous Markov chains, with input validation
- Next: a general Euler solver for Kolmogorov's forward equations

## About

Built alongside my actuarial coursework at the University of Manitoba. Course notes and exam material are not included in this repository.

License: MIT
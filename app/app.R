library(shiny)

# Load the tested engine whether the app runs from app/ or the project root
find_file <- function(...) {
  for (p in c(file.path("..", ...), file.path(...))) if (file.exists(p)) return(p)
  NA
}
source(find_file("r", "multistate.R"))
source(find_file("r", "experience.R"))
source(find_file("r", "decrement.R"))

# If the experience database exists, estimate intensities from it
est <- NULL
db_path <- find_file("sql", "experience.sqlite")
if (!is.na(db_path)) {
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  est <- estimate_intensities(query_experience(con), 3)
  DBI::dbDisconnect(con)
}

money <- function(x) paste0("$", formatC(x, format = "f", big.mark = ",", digits = 2))
note <- p(em("Illustrative assumptions only. Not calibrated to real data and not a pricing basis."))

# ---------- Chapter 1: Detours (multiple state model) ----------
tab_disability <- tabPanel("Chapter 1: Detours",
                           sidebarLayout(
                             sidebarPanel(
                               h4("Transition intensities (per year)"),
                               sliderInput("mu01", "Healthy to disabled", min = 0, max = 0.30,
                                           value = 0.02, step = 0.001),
                               sliderInput("mu02", "Death while healthy", min = 0, max = 0.10,
                                           value = 0.01, step = 0.001),
                               sliderInput("mu12", "Death while disabled", min = 0, max = 0.30,
                                           value = 0.05, step = 0.001),
                               if (!is.null(est)) actionButton("use_est",
                                                               "Use intensities estimated from experience data"),
                               h4("Economics and term"),
                               sliderInput("delta", "Force of interest", min = 0, max = 0.10,
                                           value = 0.05, step = 0.005),
                               sliderInput("n", "Policy term (years)", min = 5, max = 40,
                                           value = 20, step = 1),
                               h4("Benefits"),
                               numericInput("di", "Disability benefit (per year while disabled)",
                                            value = 12000, min = 0, step = 1000),
                               numericInput("db", "Death benefit (paid on death)",
                                            value = 50000, min = 0, step = 5000)
                             ),
                             mainPanel(
                               p(em("A healthy person may become disabled, and a disabled person may die.
            The policy pays an income while disabled and a lump sum on death.")),
                               h3("Results"),
                               tableOutput("results"),
                               h3("Where a healthy policyholder is over time"),
                               plotOutput("probs", height = "350px"),
                               if (!is.null(est)) tagList(
                                 h3("Intensities estimated from experience data (SQLite)"),
                                 tableOutput("est_table")
                               ),
                               p(em("Premiums are paid continuously while healthy and set by the equivalence principle.")),
                               note
                             )
                           )
)

# ---------- Chapter 2: Exits (multiple decrement model) ----------
tab_lapse <- tabPanel("Chapter 2: Exits",
                      sidebarLayout(
                        sidebarPanel(
                          h4("Term insurance"),
                          sliderInput("dl_n", "Policy term (years)", min = 5, max = 30, value = 20, step = 1),
                          numericInput("dl_b", "Death benefit (paid at end of year of death)",
                                       value = 250000, min = 0, step = 10000),
                          sliderInput("dl_i", "Annual interest rate", min = 0, max = 0.10,
                                      value = 0.05, step = 0.005),
                          h4("Mortality (independent rate)"),
                          sliderInput("dl_q0", "Year 1 death rate", min = 0.0005, max = 0.02,
                                      value = 0.002, step = 0.0005),
                          sliderInput("dl_g", "Annual increase in death rate", min = 0, max = 0.12,
                                      value = 0.08, step = 0.005),
                          h4("Lapses (independent rate)"),
                          sliderInput("dl_l1", "Year 1 lapse rate", min = 0, max = 0.30,
                                      value = 0.10, step = 0.01),
                          sliderInput("dl_lu", "Lapse rate after year 1", min = 0, max = 0.15,
                                      value = 0.05, step = 0.005)
                        ),
                        mainPanel(
                          p(em("A term policy ends in one of three ways: the policyholder dies, walks away,
            or reaches the end of the term. How many leave each way changes the price.")),
                          h3("Results"),
                          tableOutput("dl_results"),
                          h3("What happens to 1,000 policies"),
                          plotOutput("dl_plot", height = "350px"),
                          p(em("Death and lapse rates are entered as independent (single decrement) rates and
            converted to dependent rates assuming a uniform distribution of each decrement
            within the year. Premiums are paid at the start of each year while in force.
            No cash value is paid on lapse.")),
                          note
                        )
                      )
)

ui <- fluidPage(
  titlePanel("The Odds of a Lifetime", windowTitle = "The Odds of a Lifetime"),
  p(em("One policy, every way a life can unfold.")),
  tabsetPanel(tab_disability, tab_lapse)
)

server <- function(input, output, session) {
  
  # ----- Chapter 1 -----
  calc <- reactive({
    mu <- matrix(c(0, input$mu01, input$mu02,
                   0, 0,          input$mu12,
                   0, 0,          0), nrow = 3, byrow = TRUE)
    n <- input$n
    delta <- input$delta
    epv_di <- input$di * epv_annuity(mu, 1, 2, n, delta)
    epv_db <- input$db * epv_insurance(mu, 1, 3, n, delta)
    premium <- equivalence_premium(epv_di + epv_db, mu, start = 1,
                                   premium_states = 1, n = n, delta = delta)
    list(mu = mu, epv_di = epv_di, epv_db = epv_db, premium = premium)
  })
  
  output$results <- renderTable({
    r <- calc()
    data.frame(
      Item = c("Annual premium (paid while healthy)",
               "EPV of disability benefit",
               "EPV of death benefit",
               "Total EPV of benefits"),
      Value = c(money(r$premium), money(r$epv_di), money(r$epv_db),
                money(r$epv_di + r$epv_db))
    )
  })
  
  output$probs <- renderPlot({
    h <- 0.05
    path <- kolmogorov_path(calc()$mu, input$n, h)
    t <- (seq_len(dim(path)[1]) - 1) * h
    matplot(t, path[, 1, ], type = "l", lty = 1, lwd = 2,
            col = c("#2a9d8f", "#e9c46a", "#e76f51"), ylim = c(0, 1),
            xlab = "Years since issue", ylab = "Probability")
    legend("right", legend = c("Healthy", "Disabled", "Dead"),
           col = c("#2a9d8f", "#e9c46a", "#e76f51"), lty = 1, lwd = 2)
  })
  
  if (!is.null(est)) {
    output$est_table <- renderTable({
      m <- c(est$mu[1, 2], est$mu[1, 3], est$mu[2, 3])
      s <- c(est$se[1, 2], est$se[1, 3], est$se[2, 3])
      data.frame(
        Transition = c("Healthy to disabled", "Death while healthy",
                       "Death while disabled"),
        Estimate = sprintf("%.4f", m),
        `Std error` = sprintf("%.4f", s),
        `95% interval` = sprintf("%.4f to %.4f", m - 1.96 * s, m + 1.96 * s),
        check.names = FALSE
      )
    })
    
    observeEvent(input$use_est, {
      updateSliderInput(session, "mu01", value = round(est$mu[1, 2], 3))
      updateSliderInput(session, "mu02", value = round(est$mu[1, 3], 3))
      updateSliderInput(session, "mu12", value = round(est$mu[2, 3], 3))
    })
  }
  
  # ----- Chapter 2 -----
  dl <- reactive({
    n <- input$dl_n
    k <- 0:(n - 1)
    qd <- pmin(input$dl_q0 * (1 + input$dl_g)^k, 1)          # independent death rates
    qw <- ifelse(k == 0, input$dl_l1, input$dl_lu)            # independent lapse rates
    q <- udd_single_to_multiple(cbind(qd, qw))                # dependent rates
    q_no_lapse <- cbind(qd, 0)
    b <- c(input$dl_b, 0)
    list(q = q,
         prem = md_premium(q, b, input$dl_i),
         prem_no_lapse = md_premium(q_no_lapse, b, input$dl_i),
         epv = md_epv_benefits(q, b, input$dl_i),
         ann = md_annuity_due(q, input$dl_i))
  })
  
  output$dl_results <- renderTable({
    r <- dl()
    change <- (r$prem - r$prem_no_lapse) / r$prem_no_lapse
    data.frame(
      Item = c("Annual premium allowing for lapses",
               "Annual premium if nobody lapses",
               "Effect of lapses on the premium",
               "EPV of death benefit (with lapses)",
               "Annuity factor (with lapses)"),
      Value = c(money(r$prem), money(r$prem_no_lapse),
                sprintf("%+.1f%%", 100 * change),
                money(r$epv), sprintf("%.4f", r$ann))
    )
  })
  
  output$dl_plot <- renderPlot({
    tab <- decrement_table(dl()$q, radix = 1000)
    yrs <- 0:input$dl_n
    lines <- cbind(tab$l,
                   c(0, cumsum(tab$d[, 1])),
                   c(0, cumsum(tab$d[, 2])))
    matplot(yrs, lines, type = "l", lty = 1, lwd = 2,
            col = c("#2a9d8f", "#e76f51", "#457b9d"), ylim = c(0, 1000),
            xlab = "Policy year", ylab = "Number of policies (out of 1,000)")
    legend("right", legend = c("Still in force", "Cumulative deaths", "Cumulative lapses"),
           col = c("#2a9d8f", "#e76f51", "#457b9d"), lty = 1, lwd = 2)
  })
}

shinyApp(ui, server)
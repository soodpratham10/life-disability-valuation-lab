library(shiny)

# Load the tested engine whether the app runs from app/ or the project root
find_file <- function(...) {
  for (p in c(file.path("..", ...), file.path(...))) if (file.exists(p)) return(p)
  NA
}
source(find_file("r", "multistate.R"))
source(find_file("r", "experience.R"))

# If the experience database exists, estimate intensities from it
est <- NULL
db_path <- find_file("sql", "experience.sqlite")
if (!is.na(db_path)) {
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  est <- estimate_intensities(query_experience(con), 3)
  DBI::dbDisconnect(con)
}

ui <- fluidPage(
  titlePanel("Disability & Death Policy Calculator"),
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
      h3("Results"),
      tableOutput("results"),
      h3("Where a healthy policyholder is over time"),
      plotOutput("probs", height = "350px"),
      if (!is.null(est)) tagList(
        h3("Intensities estimated from experience data (SQLite)"),
        tableOutput("est_table")
      ),
      p(em("Illustrative assumptions only. The intensities are not calibrated
            to real data and this is not a pricing basis. Premiums are paid
            continuously while healthy and set by the equivalence principle."))
    )
  )
)

server <- function(input, output, session) {
  
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
  
  money <- function(x) paste0("$", formatC(x, format = "f", big.mark = ",", digits = 2))
  
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
}

shinyApp(ui, server)
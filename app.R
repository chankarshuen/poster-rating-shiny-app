library(shiny)
library(httr2)
library(qrcode)

# -----------------------------
# Configuration
# -----------------------------
N_POSTERS <- 20L
SUPABASE_URL <- Sys.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY <- Sys.getenv("SUPABASE_SERVICE_KEY")
ADMIN_PASSWORD <- Sys.getenv("ADMIN_PASSWORD")
DEFAULT_BASE_URL <- Sys.getenv("APP_BASE_URL")

db_ready <- function() {
  nzchar(SUPABASE_URL) && nzchar(SUPABASE_SERVICE_KEY)
}

api_url <- function(path = "ratings") {
  paste0(sub("/+$", "", SUPABASE_URL), "/rest/v1/", path)
}

db_insert_rating <- function(poster_number, content_score, presentation_score, rater_id) {
  req <- request(api_url("ratings")) |>
    req_headers(
      apikey = SUPABASE_SERVICE_KEY,
      Authorization = paste("Bearer", SUPABASE_SERVICE_KEY),
      Prefer = "return=minimal"
    ) |>
    req_body_json(list(
      poster_number = as.integer(poster_number),
      content_score = as.integer(content_score),
      presentation_score = as.integer(presentation_score),
      rater_id = as.character(rater_id)
    ))
  resp <- req_perform(req)
  invisible(resp)
}

db_get_ratings <- function() {
  req <- request(api_url("ratings")) |>
    req_headers(
      apikey = SUPABASE_SERVICE_KEY,
      Authorization = paste("Bearer", SUPABASE_SERVICE_KEY)
    ) |>
    req_url_query(select = "*", order = "poster_number.asc,created_at.asc")
  resp <- req_perform(req)
  out <- resp_body_json(resp, simplifyVector = TRUE)
  if (length(out) == 0) {
    return(data.frame(
      id = integer(), created_at = character(), poster_number = integer(),
      content_score = integer(), presentation_score = integer(),
      rater_id = character(), stringsAsFactors = FALSE
    ))
  }
  as.data.frame(out, stringsAsFactors = FALSE)
}

make_summary <- function(dat) {
  base <- data.frame(poster_number = seq_len(N_POSTERS))
  if (nrow(dat) == 0) {
    base$n_ratings <- 0L
    base$content_mean <- NA_real_
    base$presentation_mean <- NA_real_
    base$overall_mean <- NA_real_
    return(base)
  }
  dat$overall <- (dat$content_score + dat$presentation_score) / 2
  s <- aggregate(
    cbind(content_score, presentation_score, overall) ~ poster_number,
    data = dat,
    FUN = mean
  )
  n <- aggregate(rater_id ~ poster_number, data = dat, FUN = length)
  names(n)[2] <- "n_ratings"
  names(s) <- c("poster_number", "content_mean", "presentation_mean", "overall_mean")
  out <- merge(base, merge(n, s, by = "poster_number", all = TRUE),
               by = "poster_number", all.x = TRUE)
  out$n_ratings[is.na(out$n_ratings)] <- 0L
  out$content_mean <- round(out$content_mean, 2)
  out$presentation_mean <- round(out$presentation_mean, 2)
  out$overall_mean <- round(out$overall_mean, 2)
  out
}

rating_scale <- function(input_id, label) {
  tagList(
    tags$div(class = "domain-label", label),
    radioButtons(
      input_id, NULL, choices = setNames(1:7, 1:7),
      inline = TRUE, selected = character(0)
    ),
    tags$div(class = "scale-caption",
             tags$span("1 = lowest"), tags$span("7 = highest"))
  )
}

ui <- fluidPage(
  tags$head(
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$style(HTML("
      body { background:#f7f7f7; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif; }
      .container-fluid { max-width:760px; margin:0 auto; padding:18px; }
      .card { background:white; border:1px solid #ddd; border-radius:14px; padding:22px; margin-top:16px; }
      .poster-number { font-size:2rem; font-weight:750; margin:4px 0 20px; }
      .domain-label { font-size:1.35rem; font-weight:700; margin-top:22px; margin-bottom:8px; }
      .shiny-options-group { display:flex; justify-content:space-between; gap:5px; flex-wrap:nowrap; }
      .radio-inline { margin:0 !important; padding:0 !important; }
      .radio-inline input { position:absolute; opacity:0; }
      .radio-inline span {
        display:flex; align-items:center; justify-content:center;
        width:46px; height:46px; border:2px solid #777; border-radius:50%;
        font-size:1.15rem; font-weight:700; background:white;
      }
      .radio-inline input:checked + span { background:#1769aa; color:white; border-color:#1769aa; }
      .scale-caption { display:flex; justify-content:space-between; color:#666; font-size:.85rem; margin-top:5px; }
      .btn-primary { width:100%; min-height:52px; font-size:1.2rem; font-weight:700; margin-top:24px; }
      .thanks { text-align:center; padding:30px 10px; }
      .thanks h2 { color:#237a3b; }
      .errorbox { background:#fff3cd; border-left:5px solid #d39e00; padding:12px; margin:14px 0; }
      table { background:white; }
      @media (max-width:430px) {
        .container-fluid { padding:10px; }
        .card { padding:16px; }
        .radio-inline span { width:40px; height:40px; font-size:1rem; }
      }
    ")),
    # Anonymous browser identifier. It is used only to prevent accidental
    # duplicate ratings of the same poster from the same browser.
    tags$script(HTML("
      (function(){
        var key='poster_symposium_rater_id';
        var id=localStorage.getItem(key);
        if(!id){
          if(window.crypto && crypto.randomUUID) id=crypto.randomUUID();
          else id='r_'+Date.now()+'_'+Math.random().toString(36).slice(2);
          localStorage.setItem(key,id);
        }
        function send(){
          if(window.Shiny && Shiny.setInputValue){
            Shiny.setInputValue('rater_id', id, {priority:'event'});
          } else { setTimeout(send,100); }
        }
        send();
      })();
    "))
  ),
  uiOutput("page")
)

server <- function(input, output, session) {
  query <- reactiveVal(list())
  submitted <- reactiveVal(FALSE)
  submit_message <- reactiveVal(NULL)
  admin_ok <- reactiveVal(FALSE)

  session$onFlushed(function() {
    query(parseQueryString(session$clientData$url_search %||% ""))
  }, once = TRUE)

  is_admin <- reactive({
    identical(as.character(query()$admin %||% ""), "1")
  })

  poster <- reactive({
    p <- suppressWarnings(as.integer(query()$poster %||% NA))
    if (is.na(p) || p < 1 || p > N_POSTERS) NA_integer_ else p
  })

  output$page <- renderUI({
    if (is_admin()) {
      if (!admin_ok()) {
        return(div(class = "card",
          h2("Poster Rating Administration"),
          passwordInput("admin_password", "Administrator password"),
          actionButton("admin_login", "Sign in", class = "btn-primary"),
          uiOutput("admin_login_message")
        ))
      }
      return(tagList(
        div(class = "card",
          h2("Poster Rating Administration"),
          p("Content and Presentation are weighted equally. Overall = (Content + Presentation) / 2."),
          actionButton("refresh_admin", "Refresh results"),
          downloadButton("download_csv", "Download raw ratings (.csv)"),
          hr(),
          h3("Summary"),
          tableOutput("summary_table")
        ),
        div(class = "card",
          h3("QR codes"),
          p("Enter the public rating-app URL. The QR generator adds ?poster=1 through ?poster=20."),
          textInput("base_url", "Public app URL", value = DEFAULT_BASE_URL,
                    placeholder = "https://your-app.share.connect.posit.cloud"),
          downloadButton("download_qr_pdf", "Download 20 QR codes (.pdf)")
        )
      ))
    }

    if (is.na(poster())) {
      return(div(class = "card",
        h2("Poster Symposium Rating"),
        div(class = "errorbox",
            "This link does not specify a valid poster number. Please scan the QR code displayed next to a poster.")
      ))
    }

    if (submitted()) {
      return(div(class = "card thanks",
        h2("Rating submitted"),
        h3(paste("Poster", poster())),
        p(submit_message() %||% "Thank you for rating this poster.")
      ))
    }

    div(class = "card",
      h2("Symposium Poster Rating"),
      div(class = "poster-number", paste("Poster", poster())),
      rating_scale("content_score", "Content"),
      rating_scale("presentation_score", "Presentation"),
      actionButton("submit_rating", "Submit Rating", class = "btn-primary"),
      uiOutput("rating_message")
    )
  })

  observeEvent(input$submit_rating, {
    if (!db_ready()) {
      output$rating_message <- renderUI(
        div(class = "errorbox", "Database connection is not configured.")
      )
      return()
    }
    if (is.null(input$content_score) || is.null(input$presentation_score)) {
      output$rating_message <- renderUI(
        div(class = "errorbox", "Please select a score for both Content and Presentation.")
      )
      return()
    }
    if (is.null(input$rater_id) || !nzchar(input$rater_id)) {
      output$rating_message <- renderUI(
        div(class = "errorbox", "Your browser identifier is still loading. Please tap Submit again.")
      )
      return()
    }

    tryCatch({
      db_insert_rating(
        poster(), as.integer(input$content_score),
        as.integer(input$presentation_score), input$rater_id
      )
      submit_message("Thank you for rating this poster.")
      submitted(TRUE)
    }, error = function(e) {
      msg <- conditionMessage(e)
      if (grepl("409|duplicate|23505", msg, ignore.case = TRUE)) {
        submit_message("A rating for this poster has already been submitted from this browser.")
        submitted(TRUE)
      } else {
        output$rating_message <- renderUI(
          div(class = "errorbox",
              "The rating could not be saved. Please check your connection and try again.")
        )
      }
    })
  })

  observeEvent(input$admin_login, {
    if (!nzchar(ADMIN_PASSWORD)) {
      output$admin_login_message <- renderUI(
        div(class = "errorbox", "ADMIN_PASSWORD has not been configured.")
      )
    } else if (identical(input$admin_password, ADMIN_PASSWORD)) {
      admin_ok(TRUE)
    } else {
      output$admin_login_message <- renderUI(
        div(class = "errorbox", "Incorrect password.")
      )
    }
  })

  ratings_data <- eventReactive(
    list(admin_ok(), input$refresh_admin),
    {
      req(admin_ok())
      if (!db_ready()) return(data.frame())
      tryCatch(db_get_ratings(), error = function(e) data.frame())
    },
    ignoreInit = FALSE
  )

  output$summary_table <- renderTable({
    req(admin_ok())
    make_summary(ratings_data())
  }, striped = TRUE, bordered = TRUE, hover = TRUE, na = "—")

  output$download_csv <- downloadHandler(
    filename = function() paste0("poster_ratings_", Sys.Date(), ".csv"),
    content = function(file) {
      req(admin_ok())
      dat <- db_get_ratings()
      if (nrow(dat) > 0) {
        dat$overall_score <- (dat$content_score + dat$presentation_score) / 2
      }
      write.csv(dat, file, row.names = FALSE)
    }
  )

  output$download_qr_pdf <- downloadHandler(
    filename = function() "poster_QR_codes_1_to_20.pdf",
    content = function(file) {
      req(admin_ok())
      base <- trimws(input$base_url %||% "")
      validate(need(nzchar(base), "Enter the public app URL first."))
      base <- sub("[?&]+$", "", base)
      sep <- if (grepl("\\?", base)) "&" else "?"

      pdf(file, width = 8.5, height = 11)
      oldpar <- par(no.readonly = TRUE)
      on.exit({par(oldpar); dev.off()}, add = TRUE)

      for (page_start in seq(1, N_POSTERS, by = 4)) {
        par(mfrow = c(2, 2), mar = c(2.5, 2.5, 4.5, 2.5))
        for (p in page_start:min(page_start + 3, N_POSTERS)) {
          url <- paste0(base, sep, "poster=", p)
          code <- qrcode::qr_code(url)
          plot(code)
          title(main = paste("POSTER", p), cex.main = 2.2, font.main = 2)
          mtext("Scan to rate", side = 1, line = 0.5, cex = 1)
        }
        if ((page_start + 3) > N_POSTERS) {
          for (k in seq_len(page_start + 3 - N_POSTERS)) plot.new()
        }
      }
    }
  )
}

shinyApp(ui, server)

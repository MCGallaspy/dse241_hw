library(shiny)
library(semantic.dashboard)
library(ggplot2)
library(plotly)
library(DT)
library(teamcolors)
library(dplyr)
library(tidyr)
require(grImport2)
require(grid)
require(grConvert)
require(gridSVG)

# Read CSV
r_csv2 <- function(X.file_path) {
    read.csv(file = X.file_path,header = TRUE,sep = ",",stringsAsFactors = FALSE)
}

cuts <- c("Season","Down")

### NFL DATA ###
nfl_runs <- r_csv2("./rushers_lines.csv") # Read in Rushes CSV from Python Output
nfl_runs <- nfl_runs %>% filter(Position%in%c('RB','HB')) %>%
    mutate(speed_mph = round((S*60^2)/1760,1),acc_mph = round((A*60^2)/1760,1))# only care about RB/HB, translate speed and acc to MPH
teams <- nfl_runs %>% select(PossessionTeam) %>% unique() %>% arrange(PossessionTeam) %>% pull() # Get team list, alpha sort
nfl_teamcolors <- teamcolors %>% filter(league == "nfl") # Get team colors package
nfl_teamcolors <- nfl_teamcolors[c(1:16,18,17,19:27,29,28,30:nrow(nfl_teamcolors)),] # Re-Order to match team list
# Combine teams and team colors
teams <- cbind(teams,nfl_teamcolors)
teams$teams <- as.character(teams$teams)
teams_values <- teams %>% select(teams)
offensive_formations <- nfl_runs %>% select(OffenseFormation) %>% unique()
player_values <- nfl_runs %>% select(DisplayName) %>% unique() %>% arrange(DisplayName)
metrics <- c("Acceleration","Speed","Yards")
calc <- c("Average","Max","Total")

yards <- nfl_runs %>% select(Yards) %>% summarise(min_yards_gained = min(Yards), max_yards_gained = max(Yards))
min_yards <- yards$min_yards_gained[[1]]
max_yards <- yards$max_yards_gained[[1]]

ui <- dashboardPage(
    dashboardHeader(title = "Analyzing the NFL Running Back", color = "blue", title_width=400,inverted = TRUE),
    dashboardSidebar(
        size = "thin", color = "teal",
        sidebarMenu(
            menuItem(tabName = "main", "Teams Summary"),
            menuItem(tabName = "extra", "Spatial"),
            menuItem(tabName = "rush","Rushes")
        )
    ),
    dashboardBody(
        tabItems(
            selected = 1,
            tabItem(
                tabName = "main",
                fluidRow(
                    box(width = 4,
                        title = "Select Views",
                        color = "blue", ribbon = TRUE,title_side = "top left",
                        selectInput("cut","Select Cut:",choices = c("None",cuts),selected = "None"),
                        selectInput("metric","Select Metric",choices = metrics,selected = "Yards")
                        ),
                    box(width = 6,
                        title = "Select Filters",
                        color = "blue", ribbon = TRUE,title_side = "top left",
                        selectInput("team","Select Team:",choices = c("All",teams_values),selected = "All"),
                        sliderInput("season","Select Season:",2017,2019,value=c(2017,2019)),
                        selectInput("off","Select Offensive Formation:",choices = c("All",offensive_formations),selected = "All"),
                        sliderInput("def_box","Select Defense in Box",1,11,value=c(1,11))
                    ),
                    box(width = 4,
                        title = "Select Calculation",
                        color = "blue", ribbon = TRUE,title_side = "top left",
                        selectInput("calc","Select Calc:",choices = calc,selected = "Average")
                    )
                ),
                fluidRow(
                    box(width = 14,
                        title = "Summary View",
                        color = "green", ribbon = TRUE, title_side = "top right",
                        column(width = 8,
                               plotOutput("plot1")
                        )
                    )
                )
            ),
            tabItem(
                tabName = "extra",
                fluidRow(
					box(width = 10,
                        title = "Filters",
                        color = "green", ribbon = TRUE, title_side = "top right",
                        sliderInput("yards_gained", "Filter by plays that gained yards:", min_yards, max_yards, value=c(min_yards, max_yards))
                    ),
                    box(width = 14, height = 10,
                        title = "Speed Across the Field",
                        color = "green", ribbon = TRUE, title_side = "top right",
                        column(width = 10,
                            plotOutput("field1")
                        )
                    )
                )
            ),
            tabItem(
                tabName = "rush",
                fluidRow(box(width = 6,
                             title = "Select Filters",
                             color = "blue", ribbon = TRUE,title_side = "top left",
                             selectInput("team","Select Team:",choices = teams_values,selected = "ARZ"),
                             sliderInput("season","Select Season:",2017,2019,value=c(2017,2019)),
                             selectInput("player","Select RB:",choices = c("All",player_values),selected = "All")
                            )
                    ),
                fluidRow(box(width=14,height=10,
                             title="Distribution of Runs",
                             color = "green",ribbon = TRUE,title_side = "top right",
                             column(width = 10,
                                    plotOutput("field2")
                                    )
                             )
                         )
            )
        )
    ), theme = "cerulean"
)

server <- shinyServer(function(input, output, session) {

	df <- reactive({
	    result <- nfl_runs %>% 
			filter(Yards >= input$yards_gained[[1]]) %>%
	        filter(Yards <= input$yards_gained[[2]]) %>%
			select(X, Y, speed_mph) %>%
			mutate(xbin=ntile(X, 20), ybin=ntile(Y, 10)) %>%
			group_by(xbin, ybin) %>%
			summarise(
				mean_speed = mean(speed_mph)
			)
		print(dim(result))
		print(result$xbin)
		result
	})
    
    output$field1 <- renderPlot({
	    ggplot(df(), aes(x=xbin, y=ybin, fill=mean_speed)) +
            geom_tile() + scale_fill_distiller(palette = "RdYlGn") +
            theme(
                panel.background = element_rect(fill = "transparent"), # bg of the panel
                plot.background = element_rect(fill = "transparent", color = NA), # bg of the plot
                panel.grid.major = element_blank(), # get rid of major grid
                panel.grid.minor = element_blank(), # get rid of minor grid
                legend.background = element_rect(fill = "transparent"), # get rid of legend bg
                legend.box.background = element_rect(fill = "transparent"), # get rid of legend panel bg, 
                axis.line=element_blank(),axis.text.x=element_blank(),
                axis.text.y=element_blank(),
                axis.ticks=element_blank(), legend.position = "top"
            ) + xlab("") + ylab("") + labs(fill="Avg. Speed")
    })
})

shinyApp(ui, server)
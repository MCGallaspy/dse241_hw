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
                             selectInput("rush_team","Select Team:",choices = teams_values,selected = "ARZ"),
                             sliderInput("rush_season","Select Season:",2017,2019,value=c(2017,2019)),
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
    
    plot_agg <- reactive({
        if(input$metric=='Yards'){
            var = "Yards"
        } else if(input$metric=='Acceleration'){
            var = "acc_mph"
        } else{
            var = "speed_mph"
        }
        if(input$cut!="None"){
            if(input$team!="All"){
                plot_data <- nfl_runs %>%
                    filter(PossessionTeam==input$team & dplyr::between(Season,input$season[1],input$season[2]) & 
                               dplyr::between(DefendersInTheBox,input$def_box[1],input$def_box[2]))
            }
            if(input$off!="All"){
                plot_data <- nfl_runs %>%
                    filter(OffenseFormation==input$off & dplyr::between(Season,input$season[1],input$season[2]) & 
                               dplyr::between(DefendersInTheBox,input$def_box[1],input$def_box[2]))
            }
            
            if(input$calc=="Average"){
                plot_data <- nfl_runs %>% group_by_at(vars(PossessionTeam,input$cut)) %>% summarise(metric = mean(!!sym(var))) %>%
                    left_join(.,teams,by=c("PossessionTeam"="teams"))
            } else if(input$calc=="Max"){
                plot_data <- nfl_runs %>% group_by_at(vars(PossessionTeam,input$cut)) %>% summarise(metric = max(!!sym(var))) %>%
                    left_join(.,teams,by=c("PossessionTeam"="teams"))
            } else{
                plot_data <- nfl_runs %>% group_by_at(vars(PossessionTeam,input$cut)) %>% summarise(metric = sum(!!sym(var))) %>%
                    left_join(.,teams,by=c("PossessionTeam"="teams"))
            }
        } else{
            if(input$team!="All"){
                plot_data <- nfl_runs %>%
                    filter(PossessionTeam==input$team & dplyr::between(Season,input$season[1],input$season[2]) & 
                               dplyr::between(DefendersInTheBox,input$def_box[1],input$def_box[2]))
            }
            if(input$off!="All"){
                plot_data <- nfl_runs %>%
                    filter(OffenseFormation==input$off & dplyr::between(Season,input$season[1],input$season[2]) & 
                               dplyr::between(DefendersInTheBox,input$def_box[1],input$def_box[2]))
            }
            
            if(input$calc=="Average"){
                plot_data <- nfl_runs %>% group_by(PossessionTeam) %>% summarise(metric = mean(!!sym(var))) %>%
                    left_join(.,teams,by=c("PossessionTeam"="teams"))
            } else if(input$calc=="Max"){
                plot_data <- nfl_runs %>% group_by(PossessionTeam) %>% summarise(metric = max(!!sym(var))) %>%
                    left_join(.,teams,by=c("PossessionTeam"="teams"))
            } else{
                plot_data <- nfl_runs %>% group_by(PossessionTeam) %>% summarise(metric = sum(!!sym(var))) %>%
                    left_join(.,teams,by=c("PossessionTeam"="teams"))
            }
        }
    })
    
    colscale <- c(semantic_palette[["red"]], semantic_palette[["green"]], semantic_palette[["blue"]])
    mtcars$am <- factor(mtcars$am,levels=c(0,1),
                        labels=c("Automatic","Manual"))
    output$plot1 <- output$plot1 <- renderPlot({
        if(ncol(plot_agg())>13){
            ggplot(plot_agg(),aes_string(x="PossessionTeam",y="metric",fill=colnames(plot_agg())[2],color="primary")) + scale_fill_distiller() + 
                geom_bar(stat="identity",position = position_dodge(width = 0.5))+ ylab('Blah') + scale_color_identity() + ylab(input$metric)
        } else{
            ggplot(plot_agg(),aes_string(x="PossessionTeam",y="metric",fill="primary")) + 
                geom_bar(stat="identity") + scale_fill_identity() + ylab(input$metric)
        }
    })
    
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
		#print(dim(result))
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
    

    relev_runs <- nfl_runs %>% filter(dplyr::between(X1,0,120) & dplyr::between(Y1,0,53.3))
    
	field_agg <- reactive({
        if(input$player!="All"){
            field_plot <- relev_runs %>% filter((PossessionTeam %in% input$rush_team) & DisplayName %in% input$player 
                                                & dplyr::between(Season,input$rush_season[1],input$rush_season[2]))
        } else{
            field_plot <- relev_runs %>% filter((PossessionTeam %in% input$rush_team)
                                                & (dplyr::between(Season,input$rush_season[1],input$rush_season[2])))
        }
		field_plot
    })
    
    dat <- reactive({
        field_agg() %>% select(DisplayName,PossessionTeam,Season,X,Y,X1,Y1,speed_mph)
    })
	
    #Field:
    Rlogo <- readPicture("field-cairo.svg")
    RlogoSVGgrob <- gTree(children=gList(pictureGrob(Rlogo, ext="gridSVG")))
    output$field2 <- renderPlot({
        ggplot(dat(),aes(x=X,y=Y,color=DisplayName)) + annotation_custom(RlogoSVGgrob,xmin=-17, xmax=127, ymin=-5, ymax=64) + geom_point(size=2,show.legend = FALSE) + 
        geom_segment(aes(x = X, y = Y, xend = X1, yend = Y1, colour = DisplayName,size=(speed_mph)),arrow = arrow(length = unit(0.02, "npc"))) + scale_size_continuous("Speed",range=c(0,2)) + theme(
            panel.background = element_rect(fill = "transparent"), # bg of the panel
            plot.background = element_rect(fill = "transparent", color = NA), # bg of the plot
            panel.grid.major = element_blank(), # get rid of major grid
            panel.grid.minor = element_blank(), # get rid of minor grid
            legend.background = element_rect(fill = "transparent"), # get rid of legend bg
            legend.box.background = element_rect(fill = "transparent"), # get rid of legend panel bg, 
            axis.line=element_blank(),axis.text.x=element_blank(),
            axis.text.y=element_blank(),
            axis.ticks=element_blank(), legend.position = "top"
        ) + xlab("") + ylab("") 
    })
})

shinyApp(ui, server)
library(shiny)
library(semantic.dashboard)
library(ggplot2)
library(teamcolors)
library(dplyr)
library(tidyr)
require(grImport2)
require(grid)

# Read CSV
r_csv2 <- function(X.file_path) {
    read.csv(file = X.file_path,header = TRUE,sep = ",",stringsAsFactors = FALSE)
}

# Set Working Directory:
# If relative paths do not work, please set this directly to the path of the downloaded app:
#setwd("/dse241_hw/final/")

### NFL DATA ###
nfl_runs <- r_csv2("./data/rushers_lines.csv") # Read in Rushes CSV from Python Output
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
cuts <- c("Season","Down")

yards <- nfl_runs %>% select(Yards) %>% summarise(min_yards_gained = min(Yards), max_yards_gained = max(Yards))
min_yards <- yards$min_yards_gained[[1]]
max_yards <- yards$max_yards_gained[[1]]

heatmap_metrics <- c("Yards", "Speed", "Acceleration", "Direction")
heatmap_aggs <- c("Average", "Median", "Max")

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
                    box(width = 5,
                        title = "Yards gained",
                        color = "green", ribbon = TRUE, title_side = "top right",
                        sliderInput("yards_gained", "Filter by plays that gained yards:", min_yards, max_yards, value=c(min_yards, max_yards))
                    ),
                    box(width = 5,
                        title = "Metrics",
                        color = "green", ribbon = TRUE, title_side = "top right",
                        selectInput("heatmap_metric", "Select metric:", choices=heatmap_metrics, selected="Speed"),
                        selectInput("heatmap_agg", "Select aggregation:", choices=heatmap_aggs, selected="Average")
                    ),
                    box(width = 5,
                        title = "Aggregation factor",
                        color = "green", ribbon = TRUE, title_side = "top right",
                        numericInput("heatman_hbins", "Num horizontal bins:", 100, min=1),
                        numericInput("heatman_vbins", "Num vertical bins:", 53, min=1)
                    ),
                    box(width = 14, height = 10,
                        title = "Selected metric Across the Field",
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
        
        plot_data <- nfl_runs %>% filter(dplyr::between(Season,input$season[1],input$season[2]) & 
                                             dplyr::between(DefendersInTheBox,input$def_box[1],input$def_box[2]))
        
        if(input$cut!="None"){
            if(input$team!="All"){
                plot_data <- plot_data %>% filter(PossessionTeam %in% input$team)
            }
            if(input$off!="All"){
                plot_data <- plot_data %>% filter(OffenseFormation %in% input$off)
            }
            
            if(input$calc=="Average"){
                plot_data <- plot_data %>% group_by_at(vars(PossessionTeam,input$cut)) %>% summarise(metric = mean(!!sym(var))) %>%
                    left_join(.,teams,by=c("PossessionTeam"="teams"))
            } else if(input$calc=="Max"){
                plot_data <- plot_data %>% group_by_at(vars(PossessionTeam,input$cut)) %>% summarise(metric = max(!!sym(var))) %>%
                    left_join(.,teams,by=c("PossessionTeam"="teams"))
            } else{
                plot_data <- plot_data %>% group_by_at(vars(PossessionTeam,input$cut)) %>% summarise(metric = sum(!!sym(var))) %>%
                    left_join(.,teams,by=c("PossessionTeam"="teams"))
            }
        } else{
            if(input$team!="All"){
                plot_data <- plot_data %>%
                    filter(PossessionTeam %in% input$team)
            }
            if(input$off!="All"){
                plot_data <- plot_data%>%
                    filter(OffenseFormation %in% input$off)
            }
            
            if(input$calc=="Average"){
                plot_data <- plot_data %>% group_by(PossessionTeam) %>% summarise(metric = mean(!!sym(var))) %>%
                    left_join(.,teams,by=c("PossessionTeam"="teams"))
            } else if(input$calc=="Max"){
                plot_data <- plot_data %>% group_by(PossessionTeam) %>% summarise(metric = max(!!sym(var))) %>%
                    left_join(.,teams,by=c("PossessionTeam"="teams"))
            } else{
                plot_data <- plot_data %>% group_by(PossessionTeam) %>% summarise(metric = sum(!!sym(var))) %>%
                    left_join(.,teams,by=c("PossessionTeam"="teams"))
            }
        }
    })
    
    output$plot1 <- renderPlot({
        if(ncol(plot_agg())>13){
            ggplot(plot_agg(),aes_string(x="PossessionTeam",y="metric",fill=colnames(plot_agg())[2],color="primary")) + scale_fill_distiller() + 
                geom_bar(stat="identity",position = position_dodge(width = 0.5)) + scale_color_identity() + ylab(paste0(input$calc,' ',input$metric)) + xlab("Team")
        } else{
            ggplot(plot_agg(),aes_string(x="PossessionTeam",y="metric",fill="primary")) + 
                geom_bar(stat="identity") + scale_fill_identity() + ylab(paste0(input$calc,' ',input$metric)) + xlab("Team")
        }
    })
    
    df <- reactive({
        if(input$heatmap_metric=='Yards'){
            var = "Yards"
        } else if(input$heatmap_metric=='Acceleration'){
            var = "acc_mph"
        } else if(input$heatmap_metric=='Direction'){
            var = 'Dir'
        }else{
            var = "speed_mph"
        }
        
        result <- nfl_runs %>% 
            filter(Yards >= input$yards_gained[[1]]) %>%
            filter(Yards <= input$yards_gained[[2]]) %>%
            select(X, Y, !!sym(var)) %>%
            mutate(xbin=ntile(X, input$heatman_hbins), ybin=ntile(Y, input$heatman_vbins)) %>%
            group_by(xbin, ybin)
        
        if (input$heatmap_agg == "Average")
        {
            result <- result %>% summarise(
                value = mean(!!sym(var))
            )
        }
        else if (input$heatmap_agg == "Max")
        {
            result <- result %>% summarise(
                value = max(!!sym(var))
            )
        }
        else if (input$heatmap_agg == "Median")
        {
            result <- result %>% summarise(
                value = median(!!sym(var))
            )
        }
        result
    })
    
    output$field1 <- renderPlot({
        
        if (input$heatmap_metric %in% c('Direction'))
        {
            pi <- 3.14159
            angle <- df()$value - 90.
            angle <- -1. * angle
            angle <- angle * pi / 180.
            base_plot <- ggplot(df(), aes(x=xbin, y=ybin, fill=value, angle=angle, radius=0.5)) + 
                geom_tile() + geom_spoke(arrow=arrow(length=unit(.05, 'inches')))
        }
        else
        {
            base_plot <- ggplot(df(), aes(x=xbin, y=ybin, fill=value)) + geom_tile()
        }
        base_plot + scale_fill_distiller(palette = "RdYlGn") +
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
            ) + xlab("") + ylab("") + labs(fill=paste0(input$heatmap_agg,' ',input$heatmap_metric))
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
        field_agg() %>% select(Player=DisplayName,PossessionTeam,Season,X,Y,X1,Y1,speed_mph)
    })
    
    #Field:
    Rlogo <- readPicture("./data/field-cairo.svg")
    RlogoSVGgrob <- gTree(children=gList(pictureGrob(Rlogo, ext="gridSVG")))
    output$field2 <- renderPlot({
        ggplot(dat(),aes(x=X,y=Y,color=Player)) + annotation_custom(RlogoSVGgrob,xmin=-16, xmax=134, ymin=-18, ymax=80) + geom_point(size=2,show.legend = FALSE) + xlim(0,120) + ylim(0,53.3) +
            geom_segment(aes(x = X, y = Y, xend = X1, yend = Y1, colour = Player,size=(speed_mph)),arrow = arrow(length = unit(0.02, "npc"))) + scale_size_continuous("Speed",range=c(0,2)) + theme(
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
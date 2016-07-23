#Richard Shanahan  
#https://github.com/rjshanahan  
#rjshanahan@gmail.com
#10 July 2016


###### ABS Census 2016 Twitter Monitoring

# load required packages
library(shinydashboard)
library(shiny)
library(data.table)
library(DT)
library(ggplot2)
library(plotly)
library(dplyr)
library(rmongodb)
library(topicmodels)
library(wordcloud)
library(RColorBrewer)
library(stringi)
library(tm)
library(lda)
#install_github('bhaskarvk/leaflet') 
library(leaflet)


#set theme for graphics
theme = theme_set(theme_minimal())
theme = theme_update(legend.position="top",
                     axis.text.x = element_text(angle = 45, hjust = 1, vjust =1.25))


# Choices for drop-downs
vars <- c(
  "Polarity" = "text_sentiment.polarity",
  "Subjectivity" = "text_sentiment.subjectivity"
)

vars1 <- c(
  "Polarity" = "text_sentiment.polarity",
  "Subjectivity" = "text_sentiment.subjectivity"
)

vars2 <- c(
  "Polarity" = "text_sentiment.polarity",
  "Subjectivity" = "text_sentiment.subjectivity"
)

selections_Pop <- c('retweets',
                    'favorites')


############################################################
## shiny user interface function
############################################################


shinyUI(navbarPage("Census 2016 Twitter Text Analytics", 
                   #id="nav", 
                   inverse=TRUE,
                   
                   # MAPPING TAB                   
                   tabPanel("Geocoded Tweets", icon = icon("map-marker"),
                            
                            titlePanel('Where are all the tweets coming from?', windowTitle='Tweet Location'),
                            
                            div(class="outer",
                                
                                tags$head(
                                  # Include our custom CSS
                                  includeCSS("styles.css")
                                ),
                                
                                leafletOutput("myMap", width="100%", height="100%"),
                                
                                
                                absolutePanel(id = "controls", class = "panel panel-default", fixed = TRUE,
                                              draggable = TRUE, top = 120, left = "auto", right = 20, bottom = "auto",
                                              width = 450, height = 530,
                                              
                                              h2("Census 2016 Tweet Explorer"),
                                              h4("In your way? Move me around then!"),
                                              br(),
                                              
                                              selectInput(inputId="textual_type", "Tweet Sentiment Analysis Type", vars, selected = "text_sentiment.polarity"),
                                              plotOutput("time_series2", height = 300),
                                              h5("Want to know more? Please ", a("visit my GitHub repository", href="https://github.com/rjshanahan/Census_2016_Twitter_Insights", target="_blank"))
                                )
                                
                            ),
                            
                            tags$div(id="cite",
                                     'Data compiled "unofficially" by Richard Shanahan for the ', tags$em('Australian Bureau of Statistics - Census 2016'
                                     ))
                            
                   ),
                   
                   
                   # TOPIC MODELLING TAB
                   tabPanel("Explore Tweet Topics", icon = icon("flask"),
                            
                            titlePanel('What are people tweeting about and when?', windowTitle='Tweet Topics'),
                            h4("Topic Models are statisitcal contraptions that find underlying 'topics' from documents, or tweets in this case...", a("read more here.", href="https://en.wikipedia.org/wiki/Topic_model", target="_blank")),
                            h5("Use the controls to change the number of 'topics' and how many 'words' you want for each - these describe the main 'topics' extracted. You can also 'hide' layers by clicking on the legend"),
                            br(),
                            br(),
                            
                            div(class="outer1",
                                
                                tags$head(
                                  # Include our custom CSS
                                  includeCSS("styles.css")
                                ),
                                
                                plotlyOutput("topic_time2", width="100%", height="100%"),
                                
                                DT::dataTableOutput("topic_list2"),
                                
                                
                                absolutePanel(id = "controls", class = "panel panel-default", fixed = TRUE,
                                              draggable = TRUE, top = "auto", left = "auto", right = 20, bottom = 60,
                                              width = 450, height = 300,
                                              
                                              h3("Census 2016 Tweet Topic Modelling"),
                                              h4("In your way? Move me around then!"),
                                              br(),
                                              
                                              sliderInput(inputId="n_topics2","How many topics do you want?",value=5,min=1,max=8,step=1),
                                              sliderInput(inputId="topic_topN2","How many words per topic?",value=5,min=3,max=15,step=1)
                                              
                                )
                                
                            )
                            
                            
                   ),
                   
                   
                   
                   
                   # GENERIC STUFF TAB
                   tabPanel("Other Twitter-y Stuff", icon = icon("twitter-square"),
                            
                            fluidPage(
                              titlePanel('Twitter Analysis', windowTitle='Tweet Analysis'),
                              h4("A few other interesting morsels..."),
                              
                              fluidRow(
                                sidebarPanel(
                                  
                                  conditionalPanel(condition="input.conditionedPanels==1",
                                                   h4("time series bar plot shaded by text sentiment"),
                                                   br(),
                                                   radioButtons(inputId="myFill2", "Colour by text sentiment 'polarity' or 'subjectivity'", vars, selected = "text_sentiment.polarity", inline = T),
                                                   br()),

                                  conditionalPanel(condition="input.conditionedPanels==2",
                                                   h4("time series line plot shaded by text sentiment"),
                                                   br(),
                                                   radioButtons(inputId="myFill3", "Colour by text sentiment 'polarity' or 'subjectivity'", vars1, selected = "text_sentiment.polarity", inline = T),
                                                   br()),
                                  
                                  conditionalPanel(condition="input.conditionedPanels==3",
                                                   h4("top users - shaded by text sentiment"),
                                                   br(),
                                                   radioButtons(inputId="myFill4", "Colour by text sentiment 'polarity' or 'subjectivity'", vars2, selected = "text_sentiment.polarity", inline = T),
                                                   radioButtons(inputId="myPop", "Pick your popularity metric", selections_Pop, selected = "retweets", inline = T),
                                                   sliderInput(inputId="myHigh", "How many Top User records to display", value=20,min=15,max=50,step=1),
                                                   br()),
                                  
                                  conditionalPanel(condition="input.conditionedPanels==4",
                                                   h4("top words tweeted - select a word frequency"),
                                                   br(),
                                                   sliderInput(inputId="topN2","Top Words - minimum freq?",value=50,min=35,max=100,step=1),
                                                   br()),
                                  
                                  conditionalPanel(condition="input.conditionedPanels==5",
                                                   h4("word cloud... everybody's favourite - select a word frequency"),
                                                   br(),
                                                   sliderInput(inputId="topN3","Top Words - minimum freq?",value=50,min=35,max=100,step=1)),
                                  
                                  conditionalPanel(condition="input.conditionedPanels==6",
                                                   h4("how many Census 2016 tweets have been harvested from Twitter?"),
                                                   br()),
                                  width=3),
                                
                                column(width=9,
                                       tabsetPanel(type="tabs",
                                                   tabPanel("time series bar", icon = icon("bar-chart"), plotlyOutput("time_series3"), value=1),
                                                   tabPanel("time series line", icon = icon("line-chart"), plotlyOutput("time_series_line"), value=2),
                                                   tabPanel("top users", icon = icon("user"), plotlyOutput("top_users"), value=3),
                                                   tabPanel("top words", icon = icon("font"), plotlyOutput("top_words2"), value=4),
                                                   tabPanel("word cloud", icon = icon("cloud"), plotOutput("word_cloud2"), value=5),
                                                   tabPanel("how many tweets?", icon = icon("question-circle"), valueBoxOutput("numberRecords"), value=6),
                                                   id = "conditionedPanels"
                                                   
                                                   
                                       )
                                )
                                
                              )
                              
                            )
                            
                   )
)

)

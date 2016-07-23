#Richard Shanahan  
#https://github.com/rjshanahan  
#rjshanahan@gmail.com
#11 July 2016

## load packages
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
#library('bhaskarvk/leaflet') 
library(leaflet)

#set theme for ggplot2 graphics
theme = theme_set(theme_minimal())
theme = theme_update(legend.position="top",
                     axis.text.x = element_text(angle = 45, hjust = 1, vjust =1.25))


#icons
icon.positive <- makeAwesomeIcon(icon= 'plus-sign', markerColor = 'green', iconColor = 'white')
icon.neutral <- makeAwesomeIcon(icon = 'minus-sign', markerColor = 'blue', iconColor = 'white')
icon.negative <- makeAwesomeIcon(icon = 'remove-sign', markerColor = 'red', iconColor = 'white')

icon.subjective <- makeAwesomeIcon(icon= 'exclamation-sign', markerColor = 'orange', iconColor = 'white')
icon.objective <- makeAwesomeIcon(icon = 'info-sign', markerColor = 'cadetblue', iconColor = 'white')



################# 1. MONGODB CONNECTION #################

#connection object
mongo <- mongo.create(host="YOUR_DB", 
                      db="YOUR_DB")


################# 2. DATA SOURCES #################

################# 2.1 OBJECT FOR TOPIC MODELLING ################# 
#load in pre-processed text from MongoDB

myText <- mongo.find.all(mongo, "YOUR_DB.YOUR_COLLECTION",
                         query='{"$and": [
                        {"text_clean":{"$exists" :1},
                         "text_clean":{"$ne" :1},
                         "text_clean":{"$ne" :"null"}} 
                         ]}' ,
                         fields='{"text_clean":1,
                         "created_at":1,
                         "_id":0}',
                         data.frame=TRUE)

#additional tidy up
myText$text_clean <- gsub("^rt ", "", myText$text_clean)
myText$text_clean <- gsub(" amp ", "", myText$text_clean)
myText$text_clean <- gsub("https", "", myText$text_clean)
myText$text_clean <- gsub("  rt", "", myText$text_clean)
#myText$text_clean <- gsub("...", "", myText$text_clean)

#remove rows with empty strings
myText <- myText %>% filter(nchar(text_clean) > 4)
myText <- myText %>% filter(!text_clean == "                    ")


#change date format of CREATED_AT Twitter field
myText$created_at <- as.POSIXct(myText$created_at, format = "%a %b %d %H:%M:%S +0000 %Y")
#myText$created_at <- as.Date(myText$created_at)

################# 2.2 OBJECT FOR SENTIMENT TIMESERIES ################# 

#load in pre-processed text from MongoDB
mySentiment <- mongo.find.all(mongo, "YOUR_DB.YOUR_COLLECTION",
                              query='{
                              "text_sentiment":{"$exists" :1},
                              "favorites":{"$exists" :1},
                              "retweets":{"$exists" :1},
                              "user":{"$exists" :1},
                              "user_follower":{"$exists" :1},
                              "created_at":{"$exists" :1},
                              "text_sentiment": {"$ne":"null"},
                              "text_sentiment": {"$ne": 1}}',
                              fields='{
                              "text_sentiment.polarity":1,
                              "text_sentiment.subjectivity":1,
                              "favorites":1,
                              "retweets":1,
                              "user":1,
                              "user_follower":1,
                              "created_at":1,
                              "_id":0}',
                              data.frame=TRUE)


#change date format of CREATED_AT Twitter field
mySentiment$created_at <- as.POSIXct(mySentiment$created_at, format = "%a %b %d %H:%M:%S +0000 %Y")
mySentiment$day <- as.Date(mySentiment$created_at)




################# 2.3 OBJECT FOR SENTIMENT GEOCODED ################# 

#load in pre-processed text from MongoDB
myGeo <- mongo.find.all(mongo, "YOUR_DB.YOUR_COLLECTION",
                        query='{
                        "lat_lon_loc": {"$exists" :1},
                        "lat_lon_loc": {"$ne":"null"},
                        "lat_lon_loc": {"$ne": 1},
                        "text_sentiment": {"$exists" :1},
                        "text_sentiment": {"$ne":"null"},
                        "text_sentiment": {"$ne": 1}}' ,
                        fields='{
                        "text_sentiment.polarity":1,
                        "text_sentiment.subjectivity":1,
                        "lat_lon_loc.latitude":1,
                        "lat_lon_loc.longitude":1,
                        "created_at":1,
                        "text":1,
                        "_id":0}',
                        data.frame=TRUE)

myGeo.clean <- myGeo %>%
  filter(lat_lon_loc.latitude != "", lat_lon_loc.longitude  != "")

myGeo.clean$lat_lon_loc.longitude <- as.numeric(myGeo.clean$lat_lon_loc.longitude)
myGeo.clean$lat_lon_loc.latitude <- as.numeric(myGeo.clean$lat_lon_loc.latitude)


################# 3. SHINY SERVER FUNCTION #################


server <- function(input,output,sessions) {

  #tm reactive function - Term:Document Matrix
  myTDM <- reactive({
    
    # build a corpus, and specify the source to be character vectors
    myCorpus <- Corpus(VectorSource(myText$text_clean))
    
    # stem words
    myCorpus <- tm_map(myCorpus, PlainTextDocument)
    #myCorpus <- tm_map(myCorpus, stemDocument, lazy = TRUE)
    myCorpus <- tm_map(myCorpus,
           content_transformer(function(x) iconv(x, to='UTF-8', sub='byte')),
           mc.cores=1
    )
    
    tdm <- TermDocumentMatrix(myCorpus, control = list(wordLengths = c(1, Inf)))
    
  })
  
  
  #tm reactive function - Latent Dirichlet Allocation object
  myLDA <- reactive({
    
    tdm <- myTDM()
    dtm <- as.DocumentTermMatrix(tdm)
    
    # remove empty rows
    rowTotals <- apply(dtm , 1, sum)            #Find the sum of words in each Document
    dtm.new   <- dtm[rowTotals> 0, ]            #remove all docs without words
    
    # number of topics
    lda <- LDA(dtm.new, k = input$n_topics2)
    
  })
  
  
  #tm reactive function - tops n terms
  myTerm <- reactive({
    
    tdm <- myTDM()
    lda <- myLDA()
    
    # number of topics
    lda <- lda
    term <- terms(lda, input$topic_topN2) # first n words in Topic
    
  })
  
  
  #tm reactive function - tops n terms for visualisation
  myTerm_vis <- reactive({
    
    term <- myTerm()
    
    ###Visualisations
    term_vis <- apply(term, MARGIN = 2, paste, collapse = ", ")
    
  })
  
  
  #tm reactive function - LDA topics object
  myTopic <- reactive({
    
    lda <- myLDA()
    
    # first topic identified for every document (tweet)
    require(data.table) #for IDate
    
    topic <- topics(lda, 1)
    
  })
  
  
  # reactive object for sentiment time series
  mySentiment_day <- reactive({
    mySentiment %>%
      group_by_(quote(day), input$textual_type) %>%
      summarise_(total = paste0('n()')) 
  })
  
  # reactive object for sentiment time series bar
  mySentiment_day_ts1 <- reactive({
    mySentiment %>%
      group_by_(quote(day), input$myFill2) %>%
      summarise_(total = paste0('n()')) 
  })
  
  # reactive object for sentiment time series line
  mySentiment_day_ts2 <- reactive({
    mySentiment %>%
      group_by_(quote(day), input$myFill3) %>%
      summarise_(total = paste0('n()')) 
  })
  
  
  
  
  # reactive object for sentiment time series
  mySentiment_pop <- reactive({
    mySentiment %>%
      filter(!is.na(user) & user != "") %>%
      group_by_(quote(user), input$myPop, input$myFill4) %>%
      mutate(tweets = n()) %>%
      group_by_(quote(user), input$myPop, input$myFill4, quote(tweets)) %>%
      summarise_(paste0('sum(',input$myPop,')') ) %>%
      ungroup() %>%
      arrange_(paste0('desc(', quote(tweets),')'))
    
  })
  
  
  
  # top words by minimum frequency
  output$top_words2 <- renderPlotly({
    
    tdm <- myTDM()
    
    term.freq <- rowSums(as.matrix(tdm))
    term.freq <- subset(term.freq, term.freq >= input$topN2)
    myLDA.df <- data.frame(term = names(term.freq), freq = term.freq)
    
    
    #plot term frequencies
    p <- ggplot(myLDA.df, 
                aes_string(x=paste0('reorder(term, freq)'), 
                           y=quote(freq),
                           fill=quote(freq))) + 
      geom_bar(stat = "identity", linetype = 'blank') + 
      xlab("Terms") + 
      ylab("Count") +
      coord_flip() +
      theme_minimal(base_size = 8) +
      ggtitle(paste0("Showing top words tweeted at least ",input$topN2, " times"))
    
    p <- ggplotly(p,
                  tooltip = c("x","fill"))
    
    print(p)
    
  })
  
  
  # word cloud by minimum frequency  
  output$word_cloud2 <- renderPlot({
    
    tdm <- myTDM()

    m <- as.matrix(tdm)
    # calculate the frequency of words and sort it by frequency
    word.freq <- sort(rowSums(m), decreasing = T)

    pal <- brewer.pal(9,"BuGn")
    pal <- pal[-(1:4)]
    
    p <- wordcloud(words = names(word.freq), 
                   freq = word.freq, 
                   min.freq = input$topN3,
                   random.order = F,
                   colors=pal)
    
    print(p)
    
  })
  
  
  # topic model time series plot  
  output$topic_time2 <- renderPlotly({
    
    term <- myTerm_vis() 
    topic <- myTopic()
    
    topics <- data.frame(date=as.IDate(myText$created_at), topic)
    
    title_main <- paste0("Showing top ",input$topic_topN2, " words for ", input$n_topics2, " topics from ", nrow(myText), " tweets")
    title_sub <- paste0("Topic Modelling using Latent Dirichlet Allocation")
    
    p <- ggplot(topics,
                aes_string(
                  x=quote(date),
                  y=quote(..count..),
                  fill=quote(term[topic]),
                  position_stack())) +
      geom_density(linetype = 0,
                   alpha = 0.75) +
      ggtitle(title_main)
    #ggtitle(bquote(atop(.(title_main),
    #                    atop(bold(.(title_sub)))))) 
    
    p <- ggplotly(p,
                  tooltip = c("x","fill"))
    
    print(p)
    
  })
  
  
  
  # topic words list for display  
  output$topic_list2 <- renderDataTable({
    
    term <- myTerm_vis()  
    topic <- myTopic()
    
    topic_words <- data.frame(unique(term[topic]))
    
    names(topic_words)[1] <- paste0("TOPIC MODEL TOP ", input$topic_topN2, " words")
    
    topic_words
    
  })
  
  
  
  # time series plot - mapping tab
  output$time_series2 <- renderPlot({
    
    mySent_day <- mySentiment_day()
    
    #timeseries
    p <- 
      ggplot(data = mySent_day, 
             #ordered x axis by popularity count.
             aes_string(x=quote(day),
                        y=quote(total))) + 
      geom_bar(aes_string(fill=input$textual_type),
               stat='identity') +
      coord_flip() 
    
    print(p)
    
  })
  
  
  
  # time series plot - general tab
  output$time_series3 <- renderPlotly({
    
    mySent_day <- mySentiment_day_ts1()
    
    #timeseries
    p <- ggplot(data = mySent_day, 
                #ordered x axis by popularity count.
                aes_string(x=quote(day),
                           y=quote(total))) + 
      geom_bar(aes_string(fill=input$myFill2),
               stat='identity') +
      ggtitle(paste0("Time series for Census 2016 Tweets by ", input$myFill2))
    
    p <- ggplotly(p,
                  tooltip = c("x", "y", "fill"))
    
    print(p)
    
  })
  
  
  
  # time series plot - general tab
  output$time_series_line <- renderPlotly({
    
    mySent_day <- mySentiment_day_ts2()
    
    #timeseries
    p <- ggplot(data = mySent_day, 
                #ordered x axis by popularity count.
                aes_string(x=quote(day))) + 
      geom_line(aes_string(y=quote(total),
                           colour=input$myFill3)) +
      ggtitle(paste0("Time series for Census 2016 Tweets by ", input$myFill3))
    
    p <- ggplotly(p,
                  tooltip = c("x", "colour"))
    
    print(p)
    
  })
  
  
  # top users chart
  output$top_users <- renderPlotly({
    
    myDF <- mySentiment_pop()
    headmyDF <- arrange(head(myDF, n=input$myHigh))
    
    p <- ggplot(data = headmyDF, 
                #ordered x axis by popularity count.
                aes_string(x=paste0('reorder(user, desc(tweets))'),
                           y=quote(tweets))) + 
      geom_bar(aes_string(fill=input$myFill4),
               stat='identity') +
      theme_update(axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1.25, size = 8)) +
      ggtitle(paste0("Top ", input$myHigh, " users by ", input$myPop, " and ", input$myFill4)) +
      xlab("user name")
    
    p <- ggplotly(p,
                  tooltip = c("y","fill"))
    
    print(p)
    
  })
  
  
  # Create the map
  output$myMap <- renderLeaflet({
    
    sentiment_type <- input$textual_type
    
    #underlying map object - load once
    theMap <- leaflet() %>%
      addTiles(
        urlTemplate = "//{s}.tiles.mapbox.com/v3/jcheng.map-5ebohr46/{z}/{x}/{y}.png",
        attribution = 'Maps by <a href="http://www.mapbox.com/">Mapbox</a>'
      ) %>%
      setView(lng = 150.0000, lat = -24.1500, zoom = 4)
    
    
    #if statement to determine which sentiment analysis metrics will be shown
    if (sentiment_type == "text_sentiment.polarity") {
    
    #structures for map markers
    myPositive <- myGeo.clean %>% filter(text_sentiment.polarity == 'positive') %>% select(lat_lon_loc.longitude, lat_lon_loc.latitude, created_at, text)
    
    myNegative <- myGeo.clean %>% filter(text_sentiment.polarity == 'negative') %>% select(lat_lon_loc.longitude, lat_lon_loc.latitude, created_at, text)
    
    myNeutral <- myGeo.clean %>% filter(text_sentiment.polarity == 'neutral') %>% select(lat_lon_loc.longitude, lat_lon_loc.latitude, created_at, text)
    
    theMap %>%
      addAwesomeMarkers(
        lng = ~lat_lon_loc.longitude,
        lat = ~lat_lon_loc.latitude,
        icon = icon.negative,
        data = myNegative,
        label = paste('NEGATIVE tweet from', myNegative$created_at,". TWEET: ", myNegative$text)) %>%
      addAwesomeMarkers(
        lng = ~lat_lon_loc.longitude,
        lat = ~lat_lon_loc.latitude,
        icon = icon.neutral,
        data = myNeutral,
        label = paste('NEUTRAL tweet from', myNeutral$created_at,". TWEET: ", myNeutral$text)) %>%
      addAwesomeMarkers(
        lng = ~lat_lon_loc.longitude,
        lat = ~lat_lon_loc.latitude,
        icon = icon.positive,
        data = myPositive,
        label = paste('POSITIVE tweet from', myPositive$created_at,". TWEET: ", myPositive$text)) 
    } else {
      
      mySubjective <- myGeo.clean %>% filter(text_sentiment.subjectivity == 'subjective') %>% select(lat_lon_loc.longitude, lat_lon_loc.latitude, created_at, text)
      
      myObjective <- myGeo.clean %>% filter(text_sentiment.subjectivity == 'objective') %>% select(lat_lon_loc.longitude, lat_lon_loc.latitude, created_at, text)
      
      theMap %>%
        addAwesomeMarkers(
          lng = ~lat_lon_loc.longitude,
          lat = ~lat_lon_loc.latitude,
          icon = icon.objective,
          data = myObjective,
          label = paste('OBJECTIVE tweet from', myObjective$created_at,". TWEET: ", myObjective$text)) %>%
        addAwesomeMarkers(
          lng = ~lat_lon_loc.longitude,
          lat = ~lat_lon_loc.latitude,
          icon = icon.subjective,
          data = mySubjective,
          label = paste('SUBJECTIVE tweet from', mySubjective$created_at,". TWEET: ", mySubjective$text))
    }
    
  })
  

  #count of db objects
  output$numberRecords <- renderValueBox({
    
    valueBox(mongo.count(mongo, "twitter01.tweets_census_prod"),
             "Total Census 2016 Tweets harvested", 
             icon = icon("arrow-up"),
             color = "orange"
    )
  })
  
  
  
}

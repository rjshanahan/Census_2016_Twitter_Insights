## Australian Census 2016 Twitter Insights
### Sentiment Analysis, Topic Modelling and Geocoded Tweets

### *<a href="http://rjshanahan.shinyapps.io/Census_Twitter_Shiny" target="_blank">Click here for the Interactive Census Tweet Explorer</a>* 

What is the Census? According to the <a href="www.abs.gov.au/" target="_blank">Australian Bureau of Statistics</a>:  
*The Census of Population and Housing (Census) is Australia’s largest statistical collection undertaken by the Australian Bureau of Statistics (ABS). For more than 100 years, the Census has provided a snapshot of Australia, showing how our nation has changed over time, allowing us to plan for the future.*

Analysis and the interactive webapp are bolted together as follows:
- Twitter 'tweet' data is streamed via the <a href="https://dev.twitter.com/streaming/overview" target="_blank">Twitter Streaming API</a> using Python and <a href="http://www.tweepy.org/" target="_blank">Tweepy</a>
- Streamed tweets are written to and stored in the *NoSQL* database <a href="https://www.mongodb.com/" target="_blank">MongoDB</a>
- Tweets are 'enriched' using Sentiment Analysis using the <a href="http://aylien.com/" target="_blank">Aylien Python API</a>
- Tweets are geocoded (where latitude/longitude info is not available via Twitter) using the user's ```location``` tag via the <a href="https://developers.google.com/maps/" target="_blank">Google Maps API</a>
- R is then use to produce the following:
  - Sentiment coloured map pins using maps from <a href="https://rstudio.github.io/leaflet/" target="_blank">Leaflet for R</a> and <a href="https://www.mapbox.com/" target="_blank">Mapbox</a>
  - various Text Mining largely resulting in a Topic Modelling using <a href="https://plot.ly/" target="_blank">Plotly</a>
  - various Twitter insight visualisations using <a href="https://plot.ly/" target="_blank">Plotly</a>
- all this is bolted together as an <a href="http://rjshanahan.shinyapps.io/Census_Twitter_Shiny" target="_blank">interactive visualisation</a> using the amazeballs <a href="https://www.shinyapps.io/" target="_blank">ShinyApps</a> from RStudio
- the MongoDB instance and Python-hosting server are hosted on <a href="https://aws.amazon.com/ec2/" target="_blank">Amazon Web Services EC2</a>
- the Python Twitter Streaming API script is managed on the AWS EC2 instance by a ```cronjob```
  
The visualisation consists of three main tabs:
  

|ShinyApp Tab| Content|
|:---------------------------------------------------|:---------|
|```Geocoded Tweets```  							| Map pins shaded by ```polarity``` or ```subjectivity```	|
|```Topic Model``` 							| Topic Model showing topic development over time	|
|```Other Twitter-y Stuff```					| Various visualisation inc. wordcloud, top words, top users	|
  
  
  
![Twitter](https://g.twimg.com/Twitter_logo_blue.png)

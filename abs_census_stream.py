# -*- coding: utf-8 -*-

import tweepy
from tweepy.streaming import StreamListener
from tweepy import OAuthHandler
from tweepy import Stream
from pymongo import MongoClient 
import json
import re
from aylienapiclient import textapi
import googlemaps


#text analytics imports
import nltk
import string
from nltk.tokenize import word_tokenize
from nltk.corpus import stopwords
from nltk.stem.porter import PorterStemmer
from nltk.stem import WordNetLemmatizer
from nltk.tokenize import TweetTokenizer


PUNCTUATION = set(string.punctuation)
STOPWORDS = set(stopwords.words('english'))
STEMMER = PorterStemmer()
LEMMER = WordNetLemmatizer()
tweet_tokenizer = TweetTokenizer()


#Twitter API credentials
auth = tweepy.OAuthHandler('YOUR_CREDENTIALS', 'YOUR_CREDENTIALS')
auth.set_access_token('YOUR_CREDENTIALS', 'YOUR_CREDENTIALS')

consumer_key = 'YOUR_CREDENTIALS'
consumer_secret = 'YOUR_CREDENTIALS'
access_token = 'YOUR_CREDENTIALS'
access_token_secret = 'YOUR_CREDENTIALS'


#MongoDB connection
client = MongoClient('YOUR_DB')
db = client.YOUR_DB
collection = db.YOUR_COLLECTION

#regex patterns
problemchars = re.compile(r'[\[=\+/&<>;:!\\|*^\'"\?%$.@)°#(_\,\t\r\n0-9-—\]]')
url_finder = re.compile(r'http[s]?:\/\/(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\(\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+')
emojis = re.compile("["
        u"\U0001F600\\-\U0001F64F"  # emoticons
        u"\U0001F300\\-\U0001F5FF"  # symbols & pictographs
        u"\U0001F680\\-\U0001F6FF"  # transport & map symbols
        u"\U0001F1E0\\-\U0001F1FF"  # flags (iOS)
                           "]+", flags=re.UNICODE)
stop = re.compile(r'\b(' + r'|'.join(stopwords.words('english')) + r')\b\s*')
username = re.compile(r'(@)\w+( )')
retweeted = re.compile(r'^rt ')
reempty = re.compile(r'^$|\s+')


#function to flatten nested dictionaries in tweet JSON object
def flatten(indict, current_key=None, outerdict=None):
    if outerdict is None:
        outerdict = {}
    for key, value in indict.items():
        newkey = current_key + '__' + key if current_key else key
        if type(value) is not dict:
            outerdict[newkey] = value
        else:
            flatten(value, current_key=newkey, outerdict=outerdict)
    return outerdict



#function to lookup and count occurences of specific words in Tweet body
def tweet_cleaner(bodyText):
    
    #append nltk libraries
    nltk.data.path.append("/Users/rjshanahan/nltk_data")
    
    
    tokens = tweet_tokenizer.tokenize(bodyText)
    lowercased = [t.lower() for t in tokens]
    no_punctuation = []
    for word in lowercased:
        punct_removed = ''.join([letter for letter in word if not letter in PUNCTUATION and not letter.isdigit()])
        no_punctuation.append(punct_removed)
    no_stopwords = [w for w in no_punctuation if not w in STOPWORDS]
    stemmed = [STEMMER.stem(w) for w in no_stopwords]
    lemmed = [LEMMER.lemmatize(w) for w in stemmed]
    no_links = [w for w in lemmed if (not 'http' in w) and len(w)>2]
            
    return no_links


def transform_tweet(line):
    return re.compile('#\w+ ').sub('', re.compile('RT @\w+: ').sub('', line, count=1)).strip()



#define class for streaming Twitter data
class StdOutListener(StreamListener):

    def on_data(self, tweet_data):   

        #define objects: https://dev.twitter.com/overview/api/tweets
        tweet = json.loads(tweet_data)
        tweet = flatten(tweet)

        #elements of interest
        id_str = tweet["id_str"]
        created_at = tweet["created_at"]
        id_str = tweet["id_str"]
        text = tweet["text"]
        #text_token = tweet_cleaner(text)
        text_clean = retweeted.sub('', stop.sub('', problemchars.sub('', emojis.sub('', url_finder.sub('', username.sub('', text.lower().strip()))))))
        coord = tweet["coordinates"]
        fav = tweet["favorite_count"]
        rtwt = tweet["retweet_count"]
        user = tweet["user__name"]
        user_follower = tweet["user__followers_count"]
        user_friend = tweet["user__friends_count"]
        user_tweets = tweet["user__listed_count"]
        user_location = tweet["user__location"]
        user_statuses = tweet["user__statuses_count"]
        user_screen_name = tweet["user__screen_name"]
        ent_hashtag = tweet["entities__hashtags"]
        ent_user_mention = tweet["entities__user_mentions"]
        place_country = [tweet["place__country"] if "place__country" in tweet else "no_geo"]
        place_countrycode = [tweet["place__country_code"] if "place__country_code" in tweet else "no_geo"]
        place_name = [tweet["place__name"] if "place__name" in tweet else "no_geo"]
        place_type = [tweet["place__place_type"] if "place__place_type" in tweet else "no_geo"]
        
        
        #create dict to insert into MongoDB
        obj = { 
            "id_str":id_str,
            "created_at":created_at,
            "id_str":id_str,
            "text":text,
            #"text_token":text_token,
            #"text_clean":text_clean,
            "coordinates":coord,
            "favorites":fav,
            "retweets":rtwt,
            "user":user,
            "user_follower":user_follower,
            "user_friend":user_friend,
            "user_tweets":user_tweets,
            "user_location":user_location,
            "user_statuses":user_statuses,
            "user_screen_name":user_screen_name,
            "ent_hashtag":ent_hashtag,
            "ent_user_mention":ent_user_mention,
            "place_country":place_country,
            "place_countrycode":place_countrycode,
            "place_name":place_name,
            "place_type":place_type
              }
        
        #insert into MongoDB
        tweetind = collection.insert_one(obj).inserted_id
        print(obj)

        return True

    def on_error(self, status):

        #error 420 = API throttling - too many connections usually
        print(status)




#filter for #MyCensus
def streamer(consumer_key, consumer_secret, access_token, access_token_secret):
    
    #This handles Twitter authetification and the connection to Twitter Streaming AP
    if __name__ == '__main__':
    
        l = StdOutListener()
    
    #Twitter API access with streaming class
    auth = OAuthHandler(consumer_key, consumer_secret)

    auth.set_access_token(access_token, access_token_secret)

    stream = Stream(auth, l)
    
    try:
        # streaming API search terms
        stream.filter(track=['MyCensus', 'Census Australia', 'ABSCensus', 'Get online on August 9', 'making sense of the census'])
    except Exception as e:
        print(e) 
        stream.disconnect()
        
      

        
#call streamer function
print('Existing Census Tweets Collection Size: ' + str(db.YOUR_COLLECTION.count()) + '\n')
streamer(consumer_key, consumer_secret, access_token, access_token_secret)
print('\nNew Census Tweets Collection Size: ' + str(db.YOUR_COLLECTION.count()) + '\n')


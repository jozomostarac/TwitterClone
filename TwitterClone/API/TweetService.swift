//
//  TweetService.swift
//  TwitterClone
//
//  Created by MacBook Pro on 11/01/2021.
//

import Firebase

struct TweetService {
    static let shared = TweetService()
     
    func uploadTweet(caption: String, config: UploadTweetConfiguration, completion: @escaping(DatabaseCompletion)){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        var values = ["uid": uid,
                      "timestamp": Int(NSDate().timeIntervalSince1970),
                      "likes": 0,
                      "retweets": 0,
                      "caption": caption] as [String : Any]
        
        switch config {
        case .tweet:
            REF_TWEETS.childByAutoId().updateChildValues(values) { (err, ref) in
                // update user-tweet structure after tweet upload completes
                guard let tweetID = ref.key else { return }
                REF_USER_TWEETS.child(uid).updateChildValues([tweetID: 1], withCompletionBlock: completion)
            }
        case .reply(let tweet):
            values["replyingTo"] = tweet.user.username
            REF_TWEET_REPLIES.child(tweet.tweetID).childByAutoId()
                .updateChildValues(values) { (err, ref) in
                    guard let replyKey = ref.key else { return }
                    REF_USER_REPLIES.child(uid).updateChildValues([tweet.tweetID: replyKey], withCompletionBlock: completion)
                }
        }
    }
    
    func fetchTweets(completion: @escaping([Tweet]) -> Void){
        var tweets = [Tweet]()
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
            
        REF_USER_FOLLOWING.child(currentUid).observe(.childAdded) { snapshot in
            let followerUid = snapshot.key
            
            REF_USER_TWEETS.child(followerUid).observe(.childAdded) { snapshot in
                let tweetID = snapshot.key
                
                self.fetchTweet(forTweetID: tweetID) { tweet in
                    tweets.append(tweet)
                    completion(tweets)
                }
            }
        }
        
        REF_USER_TWEETS.child(currentUid).observe(.childAdded) { snapshot in
            let tweetID = snapshot.key
            
            self.fetchTweet(forTweetID: tweetID) { tweet in
                tweets.append(tweet)
                completion(tweets)
            }
        }
        
    }
    
    func fetchTweets(forUser user: User, completion: @escaping([Tweet]) -> Void) {
        var tweets = [Tweet]()
        REF_USER_TWEETS.child(user.uid).observe(.childAdded) { snapshot in
            let tweetID = snapshot.key
            
            self.fetchTweet(forTweetID: tweetID) { tweet in
                tweets.append(tweet)
                completion(tweets)
            }
        }
    }
    
    func fetchTweet(forTweetID tweetID: String, completion: @escaping(Tweet) -> Void) {
        REF_TWEETS.child(tweetID).observeSingleEvent(of: .value) { snapshot in
            guard let dictionary = snapshot.value as? [String: Any] else { return }
            guard let uid = dictionary["uid"] as? String else{ return }
            
            UserService.shared.fetchUser(uid: uid) { user in
                let tweet = Tweet(user: user, tweetID: tweetID, dictionary: dictionary)
                completion(tweet)
            }
        }
    }
    
    func fetchReplies(forUser user: User, completion: @escaping([Tweet]) -> Void) {
        var replies = [Tweet]()
        REF_USER_REPLIES.child(user.uid).observe(.childAdded) { snapshot in
            let tweetKey = snapshot.key
            guard let replyKey = snapshot.value as? String else { return }
            REF_TWEET_REPLIES.child(tweetKey).child(replyKey).observeSingleEvent(of: .value) { snapshot in
                guard let dictionary = snapshot.value as? [String: Any] else { return }
                guard let uid = dictionary["uid"] as? String else{ return }
                
                UserService.shared.fetchUser(uid: uid) { user in
                    let reply = Tweet(user: user, tweetID: replyKey, dictionary: dictionary)
                    replies.append(reply)
                    completion(replies)
                }
            }
        }
    }
    
    func fetchReplies(forTweet tweet: Tweet, completion: @escaping([Tweet]) -> Void) {
        var replies = [Tweet]()
        REF_TWEET_REPLIES.child(tweet.tweetID).observe(.childAdded) { snapshot in
            guard let dictionary = snapshot.value as? [String: Any] else { return }
            guard let uid = dictionary["uid"] as? String else{ return }
            let replyKey = snapshot.key
            
            UserService.shared.fetchUser(uid: uid) { user in
                let reply = Tweet(user: user, tweetID: replyKey, dictionary: dictionary)
                replies.append(reply)
                completion(replies)
            }
        }
    }
    
    func fetchLikes(forUser user: User, completion: @escaping([Tweet]) -> Void) {
        var tweets = [Tweet]()
        REF_USER_LIKES.child(user.uid).observe(.childAdded) { snapshot in
            let tweetID = snapshot.key
            self.fetchTweet(forTweetID: tweetID) { likedTweet in
                var tweet = likedTweet
                tweet.didLike = true
                
                tweets.append(tweet)
                completion(tweets)
            }
        }
    }
    
    func likeTweet(tweet: Tweet, completion: @escaping(DatabaseCompletion)) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let likes = tweet.didLike ? tweet.likes - 1 : tweet.likes + 1
        REF_TWEETS.child(tweet.tweetID).child("likes").setValue(likes)
        
        if tweet.didLike {
            REF_USER_LIKES.child(uid).child(tweet.tweetID).removeValue { (err, ref) in
                REF_TWEET_LIKES.child(tweet.tweetID).child(uid).removeValue(completionBlock: completion)
            }
        } else {
            REF_USER_LIKES.child(uid).updateChildValues([tweet.tweetID : 1]) { (err, ref) in
                REF_TWEET_LIKES.child(tweet.tweetID).updateChildValues([uid : 1], withCompletionBlock: completion)
            }
        }
    }
    
    func checkIfUserLikedTweet(tweet: Tweet, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        REF_USER_LIKES.child(uid).child(tweet.tweetID).observeSingleEvent(of: .value) { snapshot in
            completion(snapshot.exists())
        }
    }
    
}

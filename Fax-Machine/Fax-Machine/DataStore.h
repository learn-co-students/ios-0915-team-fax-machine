//
//  DataStore.h
//  Fax-Machine
//
//  Created by Claire Davis on 11/18/15.
//  Copyright © 2015 Flatiron-School. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AWSS3/AWSS3.h>
#import "Location.h"
#import "ImageObject.h"
#import "Comment.h"

@interface DataStore : NSObject

@property (nonatomic, strong)NSMutableArray *downloadedPictures;
@property (nonatomic, strong)NSMutableArray *comments;

+ (instancetype)sharedDataStore;
+(void)uploadPictureToAWS:(AWSS3TransferManagerUploadRequest*)uploadRequest WithCompletion:(void(^)(BOOL complete))completionBlock;

-(void)downloadPicturesToDisplay:(NSUInteger)imagesToDownloadFromParseQuery
                  WithCompletion:(void(^)(BOOL complete))completionBlock;

-(void)uploadImageWithImageObject:(ImageObject*)imageObject
                   WithCompletion:(void(^)(BOOL complete))completionBlock;

-(void)inputCommentWithComment:(NSString *)comment
                       imageID:(NSString *)imageID
                withCompletion:(void(^)(BOOL complete))completionBlock;

-(void)likeImageWithImageID:(NSString *)imageID
             withCompletion:(void(^)(BOOL complete))completionBlock;

-(void)logoutWithSuccess:(void(^)(BOOL success))success;

@end

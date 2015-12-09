////
//  ImagesViewController.m
//  Fax-Machine
//
//  Created by Selma NB on 11/18/15.
//  Copyright © 2015 Flatiron-School. All rights reserved.
//

#import "ImagesViewController.h"
#import "imagesCustomCell.h"
#import "ImagesDetailsViewController.h"
#import "DataStore.h"
#import <YYWebImage/YYWebImage.h>
#import "APIConstants.h"
#import <FontAwesomeKit/FontAwesomeKit.h>
#import "filterViewController.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <ParseTwitterUtils/ParseTwitterUtils.h>
#import "Reachability.h"
#import "AppDelegate.h"
#import <SCLAlertView-Objective-C/SCLAlertView.h>

@interface ImagesViewController () <RESideMenuDelegate, FilterImageProtocol>

@property (strong, nonatomic) NSArray *arrayWithImages;
@property (strong, nonatomic) NSArray *arrayWithDescriptions;
@property (nonatomic, strong) RESideMenu *sideMenuViewController;
@property (nonatomic) CGFloat scrollOffset;

@property (nonatomic)BOOL isFirstTime;
@property (nonatomic, strong) DataStore *dataStore;
@property (nonatomic) NSInteger isConnected;
@property (weak, nonatomic) IBOutlet UIView *scrollTopView;

@end

@implementation ImagesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //The below coding actively checking for network connection in a background thread.
    Reachability *reach = [Reachability reachabilityWithHostName:@"www.google.com"];
    reach.reachableBlock = ^(Reachability *reach){
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            //NSLog(@"There is network connection!");
            if (self.isConnected == -1) {
                //AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                SCLAlertView *alert = [[SCLAlertView alloc] initWithNewWindow];
                [alert showSuccess:@"Network is connected!" subTitle:@"" closeButtonTitle:@"Dimiss" duration:2];
                self.isConnected = 1;
            }
        }];
    };
    
    reach.unreachableBlock = ^(Reachability *reach){
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            self.isConnected = -1;
            //NSLog(@"There is no network connection!");
            SCLAlertView *alert = [[SCLAlertView alloc] initWithNewWindow];
            [alert showError:@"Network Failure!" subTitle:@"" closeButtonTitle:@"Dimiss" duration:2];
            //AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            
        }];
    };
    [reach startNotifier];
    //
    
    self.dataStore = [DataStore sharedDataStore];
    [DataStore checkUserFollow];
    
    //Initial call to fetch images to display
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"mountains_hd"]];
    self.imagesCollectionViewController.backgroundColor = [UIColor colorWithWhite:.15 alpha:.85];
    
    [[self imagesCollectionViewController]setDataSource:self];
    [[self imagesCollectionViewController]setDelegate:self];
    
    self.scrollOffset = 0;
    FAKFontAwesome *navIcon = [FAKFontAwesome naviconIconWithSize:35];
    FAKFontAwesome *filterIcon = [FAKFontAwesome filterIconWithSize:35];
    self.navigationItem.leftBarButtonItem.image = [navIcon imageWithSize:CGSizeMake(35, 35)];
    self.navigationItem.rightBarButtonItem.image = [filterIcon imageWithSize:CGSizeMake(35, 35)];
    self.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];
    self.navigationItem.rightBarButtonItem.tintColor = [UIColor whiteColor];
    
    if (!self.isFiltered && !self.isFirstTime) {
        [[HelperMethods new] parseVerifyEmailWithMessage:@"Please Verify Your Email!"];
        self.isFirstTime = YES;
        [self.dataStore.controllers addObject: self];
        [self.dataStore downloadPicturesToDisplay:12 WithCompletion:^(BOOL complete) {
            if (complete) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [self.imagesCollectionViewController reloadData];
                }];
            }
        }];
    }
    
    self.scrollTopView.backgroundColor = [UIColor clearColor];
    self.navigationController.navigationItem.title = @"Home";

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(navTapped:)];
    tapGesture.numberOfTapsRequired = 1;
    [self.scrollTopView addGestureRecognizer:tapGesture];
    self.scrollTopView.userInteractionEnabled = YES;
    
    if ([FBSDKAccessToken currentAccessToken]) {
        [[[FBSDKGraphRequest alloc] initWithGraphPath:@"me" parameters:@{@"fields":@"id, name, picture"}]
         
         startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
             if (!error) {
                 NSLog(@"fetched user:%@", result);
                 
                 
                 NSLog(@"result name:%@", result[@"name"]);
                 NSLog(@"_________");
                 NSString *username = result[@"name"];
                 [[PFUser currentUser] setUsername:username];
                 [[PFUser currentUser]saveEventually:^(BOOL succeeded, NSError * _Nullable error) {
                     NSLog(@"saved");
                 }];
                 
                 NSString *imageStringOfLoginUser = [[[result valueForKey:@"picture"] valueForKey:@"data"] valueForKey:@"url"];
                 NSURL *url = [NSURL URLWithString: imageStringOfLoginUser];
                 
                 
                 NSString *fileName = [NSString stringWithFormat:@"%@profilPic.png", [PFUser currentUser].objectId];
                 NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"upload-profilePic.tmp"];
                 NSLog(@"filepath %@", filePath);
                 NSData *imageData = [NSData dataWithContentsOfURL:url];
                 [imageData writeToFile:filePath atomically:YES];
                 AWSS3TransferManagerUploadRequest *uploadRequest = [AWSS3TransferManagerUploadRequest new];
                 uploadRequest.body = [NSURL fileURLWithPath:filePath];
                 uploadRequest.key = fileName;
                 uploadRequest.contentType = @"image/png";
                 uploadRequest.bucket = @"fissamplebucket";
                 NSLog(@"Profile picture uploadRequest: %@", uploadRequest);
                 
                 [DataStore uploadPictureToAWS:uploadRequest WithCompletion:^(BOOL complete) {
                     NSLog(@"Profile picture upload completed!");
                     [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                     }];
                 }];
                 
             }
         }];
        
    } else if ([PFTwitterUtils isLinkedWithUser:[PFUser currentUser]]){
        NSLog(@"twitter:%@",[PFTwitterUtils twitter].screenName);
        NSString *username  = [PFTwitterUtils twitter].screenName;
        [[PFUser currentUser] setUsername:username];
    }
    
    NSString *profileImageUrl = [[PFUser currentUser] objectForKey:@"profile_image_url"];
    
    //  As an example we could set an image's content to the image
    dispatch_async
    (dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
        NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:profileImageUrl]];
        
        UIImage *image = [UIImage imageWithData:imageData];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"profile picture: %@ %@",imageData,image);
        });
    });
}

-(void)viewWillAppear:(BOOL)animated{
    //self.isFiltered = NO;
    self.navigationController.navigationBarHidden = NO;
    [self.imagesCollectionViewController reloadData];
}

- (RESideMenu *)sideMenuViewController
{
    UIViewController *iter = self.parentViewController;
    while (iter) {
        if ([iter isKindOfClass:[RESideMenu class]]) {
            return (RESideMenu *)iter;
        } else if (iter.parentViewController && iter.parentViewController != iter) {
            iter = iter.parentViewController;
        } else {
            iter = nil;
        }
    }
    return nil;
}

- (IBAction)presentLeftMenu:(id)sender {
    
    [self.sideMenuViewController presentLeftMenuViewController];
}

#pragma Collection view protocal methods

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.isFavorite) {
        return self.dataStore.favoriteImages.count;
    } else if (self.isUserImageVC){
        return self.dataStore.userPictures.count;
    } else if (self.isFiltered){
        return self.dataStore.filteredImageList.count;
    } else if (self.isFollowing){
        return self.dataStore.followingOwnerImageList.count;
    }else{
        return self.dataStore.downloadedPictures.count;
    }
}
-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    imagesCustomCell *cell =[collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
    ImageObject *parseImage;
    NSString *location;
    if (self.isFavorite) {
        parseImage = self.dataStore.favoriteImages[indexPath.row];
        location = parseImage.location.city;
        
    } else if (self.isUserImageVC){
        parseImage = self.dataStore.userPictures[indexPath.row];
    } else if (self.isFiltered){
        parseImage = self.dataStore.filteredImageList[indexPath.row];
    }else if (self.isFollowing){
        parseImage = self.dataStore.followingOwnerImageList[indexPath.row];
    }else{
        parseImage = self.dataStore.downloadedPictures[indexPath.row];
        location = parseImage.location.city;
    }
    
    
    //NSString *urlString = [NSString stringWithFormat:@"%@%@", IMAGE_FILE_PATH, parseImage.imageID];
    NSString *urlString = [NSString stringWithFormat:@"%@thumbnail%@", IMAGE_FILE_PATH, parseImage.imageID];
    
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    cell.mydiscriptionLabel.text = [NSString stringWithFormat:@"❤️%@ 💬%lu",  parseImage.likes, parseImage.comments.count];
    cell.placeLabel.text = location;
    [cell.myImage yy_setImageWithURL:url placeholder:[UIImage imageNamed:@"placeholder"] options:YYWebImageOptionProgressive completion:^(UIImage *image, NSURL *url, YYWebImageFromType from, YYWebImageStage stage, NSError *error) {
        //        if (from == YYWebImageFromDiskCache) {
        //            NSLog(@"From Cache!");
        //        }
    }];
    cell.mydiscriptionLabel.textColor= [UIColor whiteColor];
    cell.mydiscriptionLabel.font=[UIFont boldSystemFontOfSize:16.0];
    
    cell.placeLabel.textColor= [UIColor whiteColor];
    cell.placeLabel.font=[UIFont boldSystemFontOfSize:16.0];
    return cell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat width = self.view.frame.size.width/2;
    CGFloat height = self.view.frame.size.height - self.navigationController.navigationBar.bounds.size.height;
    
    return CGSizeMake(width, height/3);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    return 0;
}

-(IBAction)navTapped:(id)sender{
    NSLog(@"navTapped@");
    [self.imagesCollectionViewController setContentOffset:CGPointMake(0, -self.imagesCollectionViewController.contentInset.top) animated:YES];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    
    [UIView animateWithDuration:0.25 animations:^{
        if (velocity.y <= -4) {
            self.navigationController.navigationBarHidden = NO;
            *targetContentOffset = CGPointMake(0, 0);
            self.scrollOffset = scrollView.contentOffset.y;
        }else if (scrollView.contentOffset.y <= 0){
            self.navigationController.navigationBarHidden = NO;
            self.scrollOffset = scrollView.contentOffset.y;
        }else if (fabs(velocity.y) >= 0.5) {
            self.navigationController.navigationBarHidden = YES;
            self.scrollOffset = scrollView.contentOffset.y;
        }else if (scrollView.contentOffset.y < self.scrollOffset){
            self.navigationController.navigationBarHidden = NO;
            self.scrollOffset = scrollView.contentOffset.y;
        }else{
            self.navigationController.navigationBarHidden = NO;
            self.scrollOffset = scrollView.contentOffset.y;
        }
        
        [self.view layoutIfNeeded];
    }];
    
    //NSLog(@"Filter params: %@", self.filterParameters);
    if (scrollView.contentSize.height > self.view.frame.size.height && (scrollView.contentOffset.y*2 + 700) > scrollView.contentSize.height) {
        if(self.isFiltered){
            Location *location = [[Location alloc] init];
            location.city = self.filterParameters[@"city"];
            location.country = self.filterParameters[@"country"];
            [self.dataStore downloadPicturesToDisplayWithMood:self.filterParameters[@"mood"]
                                                  andLocation:location
                                               numberOfImages:12
                                               WithCompletion:^(BOOL complete){
                                                   if (complete)
                                                   {
                                                       [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                                           [self.imagesCollectionViewController reloadData];
                                                       }];
                                                   }else
                                                   {
                                                       [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                                           [self.imagesCollectionViewController reloadData];
                                                           SCLAlertView *alert = [[SCLAlertView alloc] initWithNewWindow];
                                                           [alert showError:@"Oops!" subTitle:@"There was an error loading one or more comments" closeButtonTitle:@"Okay" duration:0];
                                                       }];
                                                   }
                                               }];
        }else{
            [self.dataStore downloadPicturesToDisplay:12 WithCompletion:^(BOOL complete) {
                if (complete) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        [self.imagesCollectionViewController reloadData];
                    }];
                }
            }];
        }
    }
}

-(void)filterImageWithDictionary:(NSMutableDictionary *)filterDict
                     andLocation:(Location *)location
{
    self.filterParameters = filterDict;
    self.isFiltered = YES;
    [self.dataStore downloadPicturesToDisplayWithMood:filterDict[@"mood"]
                                          andLocation:location
                                       numberOfImages:12
                                       WithCompletion:^(BOOL complete){
         if (complete)
         {
             [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                 [self.imagesCollectionViewController reloadData];
             }];
         }else
         {
             [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                 [self.imagesCollectionViewController reloadData];
                 SCLAlertView *alert = [[SCLAlertView alloc] initWithNewWindow];
                 [alert showError:@"Oops!" subTitle:@"There was an error loading one or more comments" closeButtonTitle:@"Okay" duration:0];
             }];
         }
     }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"filterSegue"]) {
        filterViewController *destVC = segue.destinationViewController;
        destVC.delegate = self;
    }else if ([segue.identifier isEqualToString:@"photoDetails"]){
        self.navigationController.navigationBarHidden = NO;
        UICollectionViewCell *cell = (UICollectionViewCell*)sender;
        NSIndexPath *indexPath = [self.imagesCollectionViewController indexPathForCell:cell];
        ImagesDetailsViewController *imageVC = segue.destinationViewController;
        if (self.isFavorite) {
            imageVC.image = self.dataStore.favoriteImages[indexPath.row];
        } else if (self.isUserImageVC) {
            imageVC.image = self.dataStore.userPictures[indexPath.row];
        } else if (self.isFiltered){
            imageVC.image = self.dataStore.filteredImageList[indexPath.row];
        } else if (self.isFollowing){
            imageVC.image = self.dataStore.followingOwnerImageList[indexPath.row];
        }else{
            imageVC.image = self.dataStore.downloadedPictures[indexPath.row];
        }
    }
}

-(void)filteringImagesCountryLevel:(NSDictionary *)filterParameters
{
   [[NSOperationQueue mainQueue] addOperationWithBlock:^
   {
      [self.imagesCollectionViewController reloadData]; 
   }];
}


@end

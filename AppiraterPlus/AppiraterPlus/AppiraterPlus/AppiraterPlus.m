

#import "AppiraterPlus.h"
#import "AppDelegate.h"

#import <SystemConfiguration/SCNetworkReachability.h>
#include <netinet/in.h>

NSString *const kAppiraterFirstUseDate				= @"kAppiraterFirstUseDate";
NSString *const kAppiraterUseCount					= @"kAppiraterUseCount";
NSString *const kAppiraterSignificantEventCount		= @"kAppiraterSignificantEventCount";
NSString *const kAppiraterCurrentVersion			= @"kAppiraterCurrentVersion";
NSString *const kAppiraterRatedCurrentVersion		= @"kAppiraterRatedCurrentVersion";
NSString *const kAppiraterDeclinedToRate			= @"kAppiraterDeclinedToRate";
NSString *const kAppiraterReminderRequestDate		= @"kAppiraterReminderRequestDate";

NSString *templateReviewURL = @"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=APP_ID";


@interface AppiraterPlus (hidden)
- (BOOL)connectedToNetwork;
+ (AppiraterPlus*)sharedInstance;
- (void)showRatingAlert;
- (BOOL)ratingConditionsHaveBeenMet;
- (void)incrementUseCount;
@end


@implementation AppiraterPlus (hidden)

- (BOOL)connectedToNetwork {
    // Create zero addy
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
	
    // Recover reachability flags
    SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityFlags flags;
	
    BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
    CFRelease(defaultRouteReachability);
	
    if (!didRetrieveFlags)
    {
        NSLog(@"Error. Could not recover network reachability flags");
        return NO;
    }
	
    BOOL isReachable = flags & kSCNetworkFlagsReachable;
    BOOL needsConnection = flags & kSCNetworkFlagsConnectionRequired;
	BOOL nonWiFi = flags & kSCNetworkReachabilityFlagsTransientConnection;
	
	NSURL *testURL = [NSURL URLWithString:@"http://www.apple.com/"];
	NSURLRequest *testRequest = [NSURLRequest requestWithURL:testURL  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20.0];
	NSURLConnection *testConnection = [[NSURLConnection alloc] initWithRequest:testRequest delegate:self];
	
    return ((isReachable && !needsConnection) || nonWiFi) ? (testConnection ? YES : NO) : NO;
}

+ (AppiraterPlus*)sharedInstance {
	static AppiraterPlus *appirater = nil;
	if (appirater == nil)
	{
		@synchronized(self) {
			if (appirater == nil) {
				appirater = [[AppiraterPlus alloc] init];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive) name:@"UIApplicationWillResignActiveNotification" object:nil];
            }
        }
	}
	
	return appirater;
}

- (void)showRatingAlert {
    
	//[self presentModalViewController:friendView animated:YES];


    AppDelegate *appDelegate = [[UIApplication sharedApplication]delegate];
    ratingView = [[AppiraterPlus alloc]initWithNibName:@"AppiraterPlus" bundle:nil];
    [ratingView.view setFrame:CGRectMake(0, 0, 320, 374)];

    [[[(AppDelegate*)appDelegate viewController] view] addSubview:ratingView.view];
    
    
}

- (BOOL)ratingConditionsHaveBeenMet {
	if (APPIRATER_DEBUG)
		return YES;
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	NSDate *dateOfFirstLaunch = [NSDate dateWithTimeIntervalSince1970:[userDefaults doubleForKey:kAppiraterFirstUseDate]];
	NSTimeInterval timeSinceFirstLaunch = [[NSDate date] timeIntervalSinceDate:dateOfFirstLaunch];
	NSTimeInterval timeUntilRate = 60 * 60 * 24 * APPIRATER_DAYS_UNTIL_PROMPT;
	if (timeSinceFirstLaunch < timeUntilRate)
		return NO;
	
	// check if the app has been used enough
	int useCount = [userDefaults integerForKey:kAppiraterUseCount];
	if (useCount <= APPIRATER_USES_UNTIL_PROMPT)
		return NO;
	
	// check if the user has done enough significant events
	int sigEventCount = [userDefaults integerForKey:kAppiraterSignificantEventCount];
	if (sigEventCount <= APPIRATER_SIG_EVENTS_UNTIL_PROMPT)
		return NO;
	
	// has the user previously declined to rate this version of the app?
	if ([userDefaults boolForKey:kAppiraterDeclinedToRate])
		return NO;
	
	// has the user already rated the app?
	if ([userDefaults boolForKey:kAppiraterRatedCurrentVersion])
		return NO;
	
	// if the user wanted to be reminded later, has enough time passed?
	NSDate *reminderRequestDate = [NSDate dateWithTimeIntervalSince1970:[userDefaults doubleForKey:kAppiraterReminderRequestDate]];
	NSTimeInterval timeSinceReminderRequest = [[NSDate date] timeIntervalSinceDate:reminderRequestDate];
	NSTimeInterval timeUntilReminder = 60 * 60 * 24 * APPIRATER_TIME_BEFORE_REMINDING;
	if (timeSinceReminderRequest < timeUntilReminder)
		return NO;
	
	return YES;
}

- (void)incrementUseCount {
	// get the app's version
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
	
	// get the version number that we've been tracking
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSString *trackingVersion = [userDefaults stringForKey:kAppiraterCurrentVersion];
	if (trackingVersion == nil)
	{
		trackingVersion = version;
		[userDefaults setObject:version forKey:kAppiraterCurrentVersion];
	}
	
	if (APPIRATER_DEBUG)
		NSLog(@"APPIRATER Tracking version: %@", trackingVersion);
	
	if ([trackingVersion isEqualToString:version])
	{
		// check if the first use date has been set. if not, set it.
		NSTimeInterval timeInterval = [userDefaults doubleForKey:kAppiraterFirstUseDate];
		if (timeInterval == 0)
		{
			timeInterval = [[NSDate date] timeIntervalSince1970];
			[userDefaults setDouble:timeInterval forKey:kAppiraterFirstUseDate];
		}
		
		// increment the use count
		int useCount = [userDefaults integerForKey:kAppiraterUseCount];
		useCount++;
		[userDefaults setInteger:useCount forKey:kAppiraterUseCount];
		if (APPIRATER_DEBUG)
			NSLog(@"APPIRATER Use count: %d", useCount);
	}
	else
	{
		// it's a new version of the app, so restart tracking
		[userDefaults setObject:version forKey:kAppiraterCurrentVersion];
		[userDefaults setDouble:[[NSDate date] timeIntervalSince1970] forKey:kAppiraterFirstUseDate];
		[userDefaults setInteger:1 forKey:kAppiraterUseCount];
		[userDefaults setInteger:0 forKey:kAppiraterSignificantEventCount];
		[userDefaults setBool:NO forKey:kAppiraterRatedCurrentVersion];
		[userDefaults setBool:NO forKey:kAppiraterDeclinedToRate];
		[userDefaults setDouble:0 forKey:kAppiraterReminderRequestDate];
	}
	
	[userDefaults synchronize];
}

- (void)incrementSignificantEventCount {
	// get the app's version
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
	
	// get the version number that we've been tracking
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSString *trackingVersion = [userDefaults stringForKey:kAppiraterCurrentVersion];
	if (trackingVersion == nil)
	{
		trackingVersion = version;
		[userDefaults setObject:version forKey:kAppiraterCurrentVersion];
	}
	
	if (APPIRATER_DEBUG)
		NSLog(@"APPIRATER Tracking version: %@", trackingVersion);
	
	if ([trackingVersion isEqualToString:version])
	{
		// check if the first use date has been set. if not, set it.
		NSTimeInterval timeInterval = [userDefaults doubleForKey:kAppiraterFirstUseDate];
		if (timeInterval == 0)
		{
			timeInterval = [[NSDate date] timeIntervalSince1970];
			[userDefaults setDouble:timeInterval forKey:kAppiraterFirstUseDate];
		}
		
		// increment the significant event count
		int sigEventCount = [userDefaults integerForKey:kAppiraterSignificantEventCount];
		sigEventCount++;
		[userDefaults setInteger:sigEventCount forKey:kAppiraterSignificantEventCount];
		if (APPIRATER_DEBUG)
			NSLog(@"APPIRATER Significant event count: %d", sigEventCount);
	}
	else
	{
		// it's a new version of the app, so restart tracking
		[userDefaults setObject:version forKey:kAppiraterCurrentVersion];
		[userDefaults setDouble:0 forKey:kAppiraterFirstUseDate];
		[userDefaults setInteger:0 forKey:kAppiraterUseCount];
		[userDefaults setInteger:1 forKey:kAppiraterSignificantEventCount];
		[userDefaults setBool:NO forKey:kAppiraterRatedCurrentVersion];
		[userDefaults setBool:NO forKey:kAppiraterDeclinedToRate];
		[userDefaults setDouble:0 forKey:kAppiraterReminderRequestDate];
	}
	
	[userDefaults synchronize];
}

@end


@interface AppiraterPlus ()
- (void)hideRatingAlert;
@end

@implementation AppiraterPlus

@synthesize ratingAlert, ratingView;

-(IBAction)rateNow:(id)sender{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *reviewURL = [templateReviewURL stringByReplacingOccurrencesOfString:@"APP_ID" withString:[NSString stringWithFormat:@"%d", APPIRATER_APP_ID]];
    [userDefaults setBool:YES forKey:kAppiraterRatedCurrentVersion];
    [userDefaults synchronize];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:reviewURL]];

    [self.view removeFromSuperview];
}

-(IBAction)remindLater:(id)sender{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setDouble:[[NSDate date] timeIntervalSince1970] forKey:kAppiraterReminderRequestDate];
    [userDefaults synchronize];

    [self.view removeFromSuperview];
}

-(IBAction)noThanks:(id)sender{

    
   
    [self.view removeFromSuperview];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    // they don't want to rate it
    [userDefaults setBool:YES forKey:kAppiraterDeclinedToRate];
    [userDefaults synchronize];
    

}

- (void)incrementAndRate:(NSNumber*)_canPromptForRating {

	
	[self incrementUseCount];
	
	if ([_canPromptForRating boolValue] == YES &&
		[self ratingConditionsHaveBeenMet] &&
		[self connectedToNetwork])
	{
		[self performSelectorOnMainThread:@selector(showRatingAlert) withObject:nil waitUntilDone:NO];
	}

}

- (void)incrementSignificantEventAndRate:(NSNumber*)_canPromptForRating {

	[self incrementSignificantEventCount];
	
	if ([_canPromptForRating boolValue] == YES &&
		[self ratingConditionsHaveBeenMet] &&
		[self connectedToNetwork])
	{
		[self performSelectorOnMainThread:@selector(showRatingAlert) withObject:nil waitUntilDone:NO];
	}
	

}

+ (void)appLaunched {
	[AppiraterPlus appLaunched:YES];
}

+ (void)appLaunched:(BOOL)canPromptForRating {
	NSNumber *_canPromptForRating = [[NSNumber alloc] initWithBool:canPromptForRating];
	[NSThread detachNewThreadSelector:@selector(incrementAndRate:)
							 toTarget:[AppiraterPlus sharedInstance]
						   withObject:_canPromptForRating];

}

- (void)hideRatingAlert {
	if (self.ratingAlert.visible) {
		if (APPIRATER_DEBUG)
			NSLog(@"APPIRATER Hiding Alert");
		[self.ratingAlert dismissWithClickedButtonIndex:-1 animated:NO];
	}	
}

+ (void)appWillResignActive {
	if (APPIRATER_DEBUG)
		NSLog(@"APPIRATER appWillResignActive");
	[[AppiraterPlus sharedInstance] hideRatingAlert];
}

+ (void)appEnteredForeground:(BOOL)canPromptForRating {
	NSNumber *_canPromptForRating = [[NSNumber alloc] initWithBool:canPromptForRating];
	[NSThread detachNewThreadSelector:@selector(incrementAndRate:)
							 toTarget:[AppiraterPlus sharedInstance]
						   withObject:_canPromptForRating];

}

+ (void)userDidSignificantEvent:(BOOL)canPromptForRating {
	NSNumber *_canPromptForRating = [[NSNumber alloc] initWithBool:canPromptForRating];
	[NSThread detachNewThreadSelector:@selector(incrementSignificantEventAndRate:)
							 toTarget:[AppiraterPlus sharedInstance]
						   withObject:_canPromptForRating];

}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	switch (buttonIndex) {
		case 0:
		{
			// they don't want to rate it
			[userDefaults setBool:YES forKey:kAppiraterDeclinedToRate];
			[userDefaults synchronize];
			break;
		}
		case 1:
		{
#if TARGET_IPHONE_SIMULATOR
			NSLog(@"APPIRATER NOTE: iTunes App Store is not supported on the iOS simulator. Unable to open App Store page.");
#else
			// they want to rate it
			NSString *reviewURL = [templateReviewURL stringByReplacingOccurrencesOfString:@"APP_ID" withString:[NSString stringWithFormat:@"%d", APPIRATER_APP_ID]];
			[userDefaults setBool:YES forKey:kAppiraterRatedCurrentVersion];
			[userDefaults synchronize];
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:reviewURL]];
#endif
			break;
		}
		case 2:
			// remind them later
			[userDefaults setDouble:[[NSDate date] timeIntervalSince1970] forKey:kAppiraterReminderRequestDate];
			[userDefaults synchronize];
			break;
		default:
			break;
	}
}

@end

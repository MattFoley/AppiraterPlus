//
//  ViewController.m
//  AppiraterPlus
//
//  Created by Martell Wilburn on 5/23/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}
-(IBAction)launchMoreApps:(id)sender{
    NSString *iTunesLink = @"itms-apps://itunes.com/apps/foleyproductions";
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:iTunesLink]];
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

@end

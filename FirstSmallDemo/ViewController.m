//
//  ViewController.m
//  FirstSmallDemo
//
//  Created by admin on 2018/9/29.
//  Copyright © 2018年 clcw. All rights reserved.
//

#import <Small/Small.h>
#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    // Optional - define a base URI for multi-platforms (HTML etc)
    [Small setBaseUri:@"http://code.wequick.net/"];

    // Set up all the bundles declare in bundle.json
    [Small setUpWithComplection:^{
        [Small openUri:@"main" fromController:self];
//        UIViewController *mainController = [Small controllerForUri:@"main"];
//        [self presentViewController:mainController animated:NO completion:nil];
    }];
}


- (void)didReceiveMemoryWarning {
}


@end

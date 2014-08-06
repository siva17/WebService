//
//  ViewController.m
//  WebService
//
//  Created by admin on 06/08/14.
//  Copyright (c) 2014 www.siva4u.com. All rights reserved.
//

#import "ViewController.h"
#import "WebServiceExampleVC.h"

@interface ViewController ()

@end

@implementation ViewController

-(void)pushWebServiceController:(id)sender {
    WebServiceExampleVC *wsVC = [[WebServiceExampleVC alloc]init];
    [self.navigationController pushViewController:wsVC animated:YES];
}

-(void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.title = @"Web Service Component";
    
    UIButton *btnSignup = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [btnSignup addTarget:self action:@selector(pushWebServiceController:) forControlEvents:UIControlEventTouchUpInside];
    [btnSignup setTitle:@"Click here for WebService Component" forState:UIControlStateNormal];
    [btnSignup setTintColor:[UIColor whiteColor]];
    [btnSignup setBackgroundColor:[UIColor grayColor]];
    btnSignup.frame = CGRectMake(20, 70, 280, 34);
	[self.view addSubview:btnSignup];

    [self pushWebServiceController:nil];
}
-(void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end

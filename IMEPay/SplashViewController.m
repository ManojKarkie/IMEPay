//
//  SplashViewController.m
//  IMEPay
//
//  Created by Manoj Karki on 7/12/17.
//  Copyright © 2017 Manoj Karki. All rights reserved.
//

#import "SplashViewController.h"
#import "IMPApiManager.h"
#import "PinConfirmPaymentViewController.h"
#import "Helper.h"
#import "UIViewController+Extensions.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface SplashViewController ()

//MARK:- API Manager

@property (nonatomic, strong) IMPApiManager *apiManager;

@end

@implementation SplashViewController

#pragma mark:- Vc Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupUI];
    _apiManager = [IMPApiManager new];
    [self fetchToken];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [UIView animateWithDuration:1 delay:0.2 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse animations:^{
         self.logoView.alpha = 1.0;
    } completion:^(BOOL finished) {
        
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupUI {
    _logoView.alpha = 0.0;
     [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeBlack];
}

#pragma mark:- Vc Dissmissal

- (void)dissmiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark:- API Calls

- (void)fetchToken {
    
    NSDictionary *params = @{ @"MerchantCode": _paymentParams[@"merchantCode"],
                              @"Amount" : _paymentParams[@"amount"],
                              @"RefId" : _paymentParams[@"referenceId"],
                              };
    NSLog(@"payment params fetch token %@", params);
    [SVProgressHUD showWithStatus:@"Preparing for payment.."];

    [_apiManager getToken:params success:^(NSDictionary *tokenInfo) {
        NSString *tokenId = tokenInfo[@"TokenId"];
        [self.paymentParams setValue:tokenId forKey:@"token"];
        [self postToMerchant];
    } failure:^(NSString *error) {
        [SVProgressHUD dismiss];
        [self showTryAgain:@"Oops!" message:error cancelHandler:^{
            [self dissmiss];
        } tryAgainHandler:^{
            [self fetchToken];
        }];
    }];
}

- (void)postToMerchant {
    
    NSDictionary *params = @{ @"TokenId": _paymentParams[@"token"],
                              @"MerchantCode": _paymentParams[@"merchantCode"],
                              @"Amount" : _paymentParams[@"amount"],
                              @"ReferenceId" : _paymentParams[@"referenceId"]
                              };
    NSLog(@"mercharnt URL post params %@", params);

    NSLog(@"PAYMENT PARAMS BEFORE POST TO MERCHANT %@", _paymentParams);

    NSString *merchantPaymentUrl = _paymentParams[@"merchantUrl"];

    NSString *cleanUrl = [merchantPaymentUrl stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    NSLog(@"Merchant Payment URL %@", cleanUrl);

    if (merchantPaymentUrl == nil) {
        return;
    }

    [_apiManager postToMerchant:cleanUrl parameters:params success:^{
        [SVProgressHUD dismiss];
        [self gotoPinConfirmationVc];
    } failure:^(NSString *error) {
        [SVProgressHUD dismiss];
//        [self gotoPinConfirmationVc];
//        return;
        [self showTryAgain:@"Oops!" message:error cancelHandler:^{
            [self dissmiss];
        } tryAgainHandler:^{
            [self postToMerchant];
        }];
    }];
}

#pragma mark:- Goto Pin confirmation

- (void)gotoPinConfirmationVc {

    NSBundle *bundle = [NSBundle bundleForClass:[IMPPaymentManager class]];
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:bundle];
    PinConfirmPaymentViewController *paymentVc = (PinConfirmPaymentViewController *) [sb instantiateViewControllerWithIdentifier:@"PinConfirmPaymentViewController"];
    paymentVc.paymentParams = self.paymentParams;
//    paymentVc.success = self.successBlock;
//    paymentVc.failure = self.failureBlock;
    [topViewController() presentViewController:paymentVc animated:YES completion:nil];

}

@end

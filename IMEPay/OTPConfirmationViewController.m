//
//  OTPConfirmationViewController.m
//  IMEPay
//
//  Created by Manoj Karki on 12/29/17.
//  Copyright © 2017 Manoj Karki. All rights reserved.
//

#import "OTPConfirmationViewController.h"
#import "IMPApiManager.h"
#import "UIViewController+Extensions.h"
#import "Config.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "PinConfirmPaymentViewController.h"
#import "TransactionResultViewController.h"
#import "Helper.h"

@interface OTPConfirmationViewController ()<UITextFieldDelegate>

//MARK:- API MANAGER

@property (nonatomic, strong) IMPApiManager *apiManager;

//MARK:- STATES

@property (nonatomic, strong) NSString *transactionId;
@property (nonatomic, assign) BOOL isFailedForFirstTime;

@end

@implementation OTPConfirmationViewController

#define OTP_FIELD_PLACEHOLDER @"Enter OTP"

#pragma mark:- Vc Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self addLogoTitle];
    [self addCancelButtonWithAlert];

    [_otpField setThemedPlaceholder:OTP_FIELD_PLACEHOLDER];

    _apiManager = [IMPApiManager new];
    _otpField.delegate = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark:- IBAction

- (IBAction)confirmClicked:(id)sender {

    [self.view endEditing:YES];
    if ([_OTP isEqualToString:_otpField.text]) {
       [self makePayment];
        return;
    }

    NSString *mobileNumber = _paymentParams[@"mobileNumber"];
    [self showAlert:@"Invalid OTP!" message:[NSString stringWithFormat:@"Please enter 4 digit OTP Code sent to %@", mobileNumber] okayHandler:^{
    }];
}

#pragma mark:- Payment and confirmation

- (void)makePayment {
    NSDictionary *params = @{ @"MerchantCode": _paymentParams[@"merchantCode"],
                              @"Amount" : _paymentParams[@"amount"],
                              @"RefId" : _paymentParams[@"referenceId"],
                              @"TokenId": _paymentParams[@"token"],
                              @"Pin" : _PIN,
                              @"Msisdn" : _paymentParams[@"mobileNumber"]
                              };

    [self showHud:@"Performing payment.."];

    [_apiManager makePayment:params success:^(NSDictionary *info) {
        [self dissmissHud];
        self.transactionId = info[@"TransactionId"];
        NSNumber *responseCode = info[@"ResponseCode"];

        if (responseCode.integerValue == TRAN_SUCCESS_CODE) {
            [self gotoFinalPage:info];
        }else {
            [self showAlert:@"Error!" message:info[@"ResponseDescription"] okayHandler:^{

                NSString *amount = (NSString *)[self.paymentParams valueForKey:@"amount"];

                IMPTransactionInfo *tranInfo = [[IMPTransactionInfo alloc]initWithDictionary:info totalAmount:amount];

                [self transactionFailed:tranInfo error:info[@"ResponseDescription"]];
            }];
        }
    } failure:^(NSString *error) {
        [self dissmissHud];
        [self showTryAgain:@"Error!" message:error cancelHandler:^{
//            NSString *amount = (NSString *)[self.paymentParams valueForKey:@"amount"];
//            IMPTransactionInfo *tranInfo = [[IMPTransactionInfo alloc]initWithDictionary:[NSDictionary new] totalAmount:amount];
//            [self transactionFailed:tranInfo error: error];
        } tryAgainHandler:^{
            [self makePayment];
        }];

    }];
}

#pragma  mark:- Handle failure

- (void)transactionFailed: (IMPTransactionInfo *)info error: (NSString *)errorMessage {

    if (_failure) {
        _failure(info, errorMessage);
    }

    [[NSNotificationCenter defaultCenter]postNotificationName:NOTIF_SHOULD_QUIT object:nil];

}

//- (void)setUpTimer {
//    [SVProgressHUD showWithStatus:@"Processing payment.."];
//    //[NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(confirmPayment) userInfo:nil repeats:NO];
//}

//- (void)confirmPayment {
//    NSDictionary *params = @{ @"MerchantCode": _paymentParams[@"merchantCode"],
//                              @"TransactionId" : _transactionId,
//                              @"Amount" : _paymentParams[@"amount"],
//                              @"RefId" : _paymentParams[@"referenceId"],
//                              @"Msisdn" : _paymentParams[@"mobileNumber"]
//                              };
//    [SVProgressHUD showWithStatus:@"Confirming.."];
//    [_apiManager confirmPayment:params success:^(NSDictionary *info) {
//        [SVProgressHUD dismiss];
//
//    } failure:^(NSString *error) {
//        [SVProgressHUD dismiss];
//        if (self.isFailedForFirstTime){
//            self.isFailedForFirstTime = NO;
//            [self setUpTimer];
//            return;
//        }
//
//        [self showTryAgain:@"Oops!" message:error cancelHandler:^{
//            [self dissmissAndNotify];
//        } tryAgainHandler:^{
//            [self confirmPayment];
//        }];
//    }];
//}

#pragma mark:- UITextField Delegates

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    return newString.length <= PIN_MAX_LENGTH;
}

#pragma mark:- Goto Success Page

- (void)gotoFinalPage :(NSDictionary *)info {

    NSLog(@"transaction info before final result view %@", info);

    NSBundle *bundle = [NSBundle bundleForClass:[IMPPaymentManager class]];
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:bundle];
    TransactionResultViewController *resultVc = (TransactionResultViewController *) [sb instantiateViewControllerWithIdentifier:@"TransactionResultViewController"];
    resultVc.transactionInfo = info;
    resultVc.paymentParams = self.paymentParams;

    UINavigationController *resultNav = baseNav(resultVc);

    resultVc.failure = self.failure;
    resultVc.success  = self.success;

    [self.navigationController presentViewController:resultNav animated:true completion:nil];
}

@end

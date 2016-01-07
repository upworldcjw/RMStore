//
//  RMStoreManager.m
//  RMStore
//
//  Created by jianwei.chen on 15/12/24.
//  Copyright © 2015年 Robot Media. All rights reserved.
//

#import "RMStoreManager.h"
#import "RMStore.h"
#import "RMStoreTransactionReceiptVerifier.h"
#import "RMStoreKeychainPersistence.h"

NSString *const kRMStoreManagerErrorDomine = @"kRMErrorDomine";

NS_ENUM(NSInteger,_RMStoreManagerErrorCode){
    kRMStoreManagerCanNotPayError = 100,  //设备限制，不能支付
    kRMStoreManagerInvaliadProduct, //商品不存在，还没有在appstore 上线
    kRMStoreManagerRequestProductError,//从苹果服务器获取商品失败
//    kRMStoreManager
//    kRMStoreManager
};

typedef NSInteger RMStoreManagerErrorCode;


@implementation RMStoreManager{
    id<RMStoreReceiptVerifier> _receiptVerifier;
    RMStoreKeychainPersistence *_persistence;
}

-(instancetype)init{
    if (self = [super init]) {
        _receiptVerifier = [[RMStoreTransactionReceiptVerifier alloc] init];
        [RMStore defaultStore].receiptVerifier = _receiptVerifier;
        
        _persistence = [[RMStoreKeychainPersistence alloc] init];
        [RMStore defaultStore].transactionPersistor = _persistence;
    }
    return self;
}

+ (NSError *)errorWithCode:(RMStoreManagerErrorCode)code{
    return [NSError errorWithDomain:kRMStoreManagerErrorDomine code:code userInfo:nil];
}

+ (instancetype)share{
    static dispatch_once_t onceToken;
    static RMStoreManager *shareInstance;
    dispatch_once(&onceToken, ^{
        shareInstance = [[self alloc] init];
    });
    return shareInstance;
}

+(void)purchasedRegister{
    [RMStoreManager share];
}

//根据productID 从appStore返回对应的信息
+(void)localPriceOfProductID:(NSString *)productID asyBlock:(void (^)(NSString *localPrice))asyBlock{
    [[RMStore defaultStore] requestProducts:[NSSet setWithArray:@[productID]]
                                    success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
                                        NSString *localPrice = [RMStoreManager localPriceOfProductID:productID];
                                        asyBlock(localPrice);
                                    } failure:^(NSError *error) {
                                        asyBlock(nil);
                                    }];
}


//根据productID 从appStore返回对应的信息
+(NSString *)localPriceOfProductID:(NSString *)productID{
    SKProduct *product = [[RMStore defaultStore]productForIdentifier:productID];
    if (product) {
        return [RMStore localizedPriceOfProduct:product];
    }
    return nil;
}


+(void)purchasedPruductID:(NSString *)productID
                   userID:(NSString *)userID
                  success:(void (^)(SKPaymentTransaction *transaction,SKProduct *product))successBlock
                  failure:(void (^)(SKPaymentTransaction *transaction, NSError *error,SKProduct *product))failureBlock{
    [self customedPurchasedPruductID:productID userID:userID success:successBlock failure:^(SKPaymentTransaction *transaction, NSError *error, SKProduct *product) {
        if (error) {
            [self showAlertWithError:error];
        }
        failureBlock(transaction,error,product);
    }];
}

//payment.applicationUsername
//error 首先如果errorDomain 为RMStoreErrorDomain，则error.code 可能为0，300，100，200，或者其他验证过程中产生的错误码
//error 如果errorDomain 为kRMStoreManagerErrorDomine，则error.code可能为100，101，102
+(void)customedPurchasedPruductID:(NSString *)productID
                   userID:(NSString *)userID
                  success:(void (^)(SKPaymentTransaction *transaction,SKProduct *product))successBlock
                  failure:(void (^)(SKPaymentTransaction *transaction, NSError *error,SKProduct *product))failureBlock{
    if (![RMStore canMakePayments]) {//这个同步返回
        failureBlock(nil,[self errorWithCode:kRMStoreManagerCanNotPayError],nil);
        return;
    }
    //获取商品信息
    NSArray *products = @[productID];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [[RMStore defaultStore] requestProducts:[NSSet setWithArray:products] success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        if(products.count == 0){
            failureBlock(nil,[self errorWithCode:kRMStoreManagerInvaliadProduct],nil);
            return;
        }else{
            SKProduct *product = [products firstObject];
            NSAssert([productID isEqualToString:product.productIdentifier], @"product some error");
            
            [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
            [[RMStore defaultStore] addPayment:productID user:userID success:^(SKPaymentTransaction *transaction) {
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                successBlock(transaction,product);
                //
            } failure:^(SKPaymentTransaction *transaction, NSError *error) {
                //验证收据网络错误等(包括苹果返回来的错误)
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                //Payment Transaction Failed
                failureBlock(transaction,error,product);//RMStoreErrorDomain
                return ;
            }];
        }
    } failure:^(NSError *error) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        failureBlock(nil,[self errorWithCode:kRMStoreManagerRequestProductError],nil);
        return ;
    }];
}


+ (void)showAlertWithError:(NSError *)error{
    if ([error.domain isEqualToString:kRMStoreManagerErrorDomine]) {
        switch (error.code) {
            case kRMStoreManagerCanNotPayError:
                [self showAlertTitle:@"提示" message:@"不支持支付，请确定是否开启家长限制" cancelBtnTitle:@"我知道了"];
                break;
            case kRMStoreManagerInvaliadProduct:
                [self showAlertTitle:@"提示" message:@"此商品暂时不支持购买" cancelBtnTitle:@"我知道了"];
                break;
            case kRMStoreManagerRequestProductError:
                [self showAlertTitle:@"提示" message:@"网络出错了，请稍后重试" cancelBtnTitle:@"我知道了"];
                break;
            default:
                break;
        }
    }else if([error.domain isEqualToString:RMStoreErrorDomain]){
        if (error.code == RMStoreErrorCodeUnknownProductIdentifier) {//
            //RMStoreErrorCodeUnknownProductIdentifier
            [self showAlertTitle:@"提示" message:@"此商品暂时不支持购买" cancelBtnTitle:@"我知道了"];
        }else if(error.code == RMStoreErrorCodeUnableToCompleteVerification){
            [self showAlertTitle:@"提示" message:@"网络出错了，请稍后重试" cancelBtnTitle:@"我知道了"];
        }else{
            
        }
    }else{
        
    }
}


+ (void)showAlertTitle:(NSString *)title message:(NSString *)message cancelBtnTitle:(NSString *)btnTitle{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:btnTitle
                                              otherButtonTitles:nil];
    [alertView show];
}

@end

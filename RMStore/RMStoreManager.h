//
//  RMStoreManager.h
//  RMStore
//
//  Created by jianwei.chen on 15/12/24.
//  Copyright © 2015年 Robot Media. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMStore.h"
@class SKPaymentTransaction;
@class SKProduct;
@interface RMStoreManager : NSObject

+(void)purchasedRegister;

///如果商品存在（product !=nil）,网络好的话会获取transaction，如果网络不好transaction==nil，error会有说明
///理想情况下，通过productID 获取SKProduct，通过SKProduct购买商品，苹果返回transaction。
+(void)purchasedPruductID:(NSString *)productID
                   userID:(NSString *)userID
                  success:(void (^)(SKPaymentTransaction *transaction,SKProduct *product))successBlock
                  failure:(void (^)(SKPaymentTransaction *transaction, NSError *error,SKProduct *product))failureBlock;
@end

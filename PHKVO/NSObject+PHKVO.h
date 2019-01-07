//
//  NSObject+PHKVO.h
//  PHKVO
//
//  Created by Phoenix on 2018/2/26.
//  Copyright © 2018年 Phoenix. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^PHObservingBlock)(id observerObject,
                                NSString *observeredKey,
                                id oldValue,
                                id newValue);

@interface NSObject (PHKVO)
- (void)ph_addObserver:(id)observer
                forKey:(NSString *)key
             withBlock:(PHObservingBlock)block;

- (void)ph_removeObserver:(id)observer
                   forKey:(NSString *)key;
@end

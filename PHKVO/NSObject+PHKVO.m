//
//  NSObject+PHKVO.m
//  PHKVO
//
//  Created by Phoenix on 2018/2/26.
//  Copyright © 2018年 Phoenix. All rights reserved.
//

#import "NSObject+PHKVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

NSString * const kPHKVOClassPrefix = @"PHKVOClassPrefix_";
NSString * const kPHKVOAssociatedObservers = @"PHKVOAssociatedObservers";

@interface PHObservationInfo : NSObject
@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) PHObservingBlock block;
@end

@implementation PHObservationInfo
- (instancetype)initWithObserver:(NSObject *)observer
                             key:(NSString *)key
                           block:(PHObservingBlock)block {
    self = [super init];
    if (self) {
        _observer = observer;
        _key = key;
        _block = block;
    }
    return self;
}
@end


static NSString * getterFromSetter(NSString *setter) {
    if (setter.length <= 0
        || ![setter hasPrefix:@"set"]
        || ![setter hasSuffix:@":"]) {
        return nil;
    }
    
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *key = [setter substringWithRange:range];
    
    NSString *firstLetter = [[key substringToIndex:1] lowercaseString];
    key = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                       withString:firstLetter];
    
    return key;
}


static NSString * setterFromGetter(NSString *getter) {
    if (getter.length <= 0) {
        return nil;
    }
    
    NSString *initial = [[getter substringToIndex:1] uppercaseString];
    NSString *otherLetters = [getter substringFromIndex:1];
    
    NSString *setter = [NSString stringWithFormat:@"set%@%@:", initial, otherLetters];
    
    return setter;
}

static Class kvo_class(id self, SEL _cmd) {
    return class_getSuperclass(object_getClass(self));
}

static void kvo_setter(id self, SEL _cmd, id newValue) {
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = getterFromSetter(setterName);
    
    if (!getterName) {
#ifdef DEBUG
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have setter %@", self, setterName];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
#endif
        return;
    }
    
    id oldValue = [self valueForKey:getterName];
    
    struct objc_super superClass = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    void (*objc_msgSendSuperCasted)(void *, SEL, id) = (void *)objc_msgSendSuper;

    objc_msgSendSuperCasted(&superClass, _cmd, newValue);
    
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kPHKVOAssociatedObservers));
    for (PHObservationInfo *info in observers) {
        if ([info.key isEqualToString:getterName]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if (info.block) {
                    info.block(self, getterName, oldValue, newValue);
                }
            });
        }
    }
}

@implementation NSObject (PHKVO)
- (void)ph_addObserver:(id)observer
                forKey:(NSString *)key
             withBlock:(PHObservingBlock)block {
    
    SEL setterSelector = NSSelectorFromString(setterFromGetter(key));
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    if (!setterMethod) {
#ifdef DEBUG
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have a setter for key %@", self, key];
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
#endif
        return;
    }
    
    Class class = object_getClass(self);
    NSString *className = NSStringFromClass(class);
    
    if (![className hasPrefix:kPHKVOClassPrefix]) {
        class = [self generateKvoClassFromOriginal:class];
        object_setClass(self, class);
    }

    if (![self hasSelector:setterSelector]) {
        const char *types = method_getTypeEncoding(setterMethod);
        class_addMethod(class, setterSelector, (IMP)kvo_setter, types);
    }
    
    PHObservationInfo *info = [[PHObservationInfo alloc] initWithObserver:observer
                                                                      key:key
                                                                    block:block];
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kPHKVOAssociatedObservers));
    if (!observers) {
        observers = [NSMutableArray array];
        objc_setAssociatedObject(self,
                                 (__bridge const void *)(kPHKVOAssociatedObservers),
                                 observers,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observers addObject:info];
    
}

- (void)ph_removeObserver:(id)observer
                   forKey:(NSString *)key {
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kPHKVOAssociatedObservers));
    
    PHObservationInfo *infoToRemove;
    for (PHObservationInfo *info in observers) {
        if (info.observer == observer && [info.key isEqual:key]) {
            infoToRemove = info;
            break;
        }
    }
    
    [observers removeObject:infoToRemove];
}

- (BOOL)hasSelector:(SEL)selector {
    Class clazz = object_getClass(self);
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(clazz, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL thisSelector = method_getName(methodList[i]);
        if (thisSelector == selector) {
            free(methodList);
            return YES;
        }
    }
    
    free(methodList);
    return NO;
}

- (Class)generateKvoClassFromOriginal:(Class)originalClass {
    NSString *kvoClassName = [kPHKVOClassPrefix stringByAppendingString:NSStringFromClass(originalClass)];
    Class kvoClass = NSClassFromString(kvoClassName);
    
    if (kvoClass) {
        return kvoClass;
    }
    
    kvoClass = objc_allocateClassPair(originalClass, kvoClassName.UTF8String, 0);
    
    Method classMethod = class_getInstanceMethod(originalClass, @selector(class));
    const char *types = method_getTypeEncoding(classMethod);
    class_addMethod(kvoClass, @selector(class), (IMP)kvo_class, types);

    objc_registerClassPair(kvoClass);
    return kvoClass;
}


@end

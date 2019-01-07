# PHKVO
KVO with runtime api.

## How to use

```objc
@interface Message : NSObject
@property (nonatomic, copy) NSString *text;
@end

[self.message ph_addObserver:self
                      forKey:@"text"
                   withBlock:^(id observerObject,
                               NSString *observeredKey,
                               id oldValue,
                               id newValue) {
        // do something.
    }];
```
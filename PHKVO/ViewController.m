//
//  ViewController.m
//  PHKVO
//
//  Created by Phoenix on 2018/2/26.
//  Copyright © 2018年 Phoenix. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+PHKVO.h"

@interface Message : NSObject
@property (nonatomic, copy) NSString *text;
@end

@implementation Message
@end

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *button;
@property (nonatomic, strong) Message *message;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.message = [Message new];
    self.message.text = @"2";
    __weak __typeof(self) weakSelf = self;
    [self.message ph_addObserver:self
                          forKey:@"text"
                       withBlock:^(id observerObject,
                                   NSString *observeredKey,
                                   id oldValue,
                                   id newValue) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.button setTitle:(NSString *)newValue forState:UIControlStateNormal];
        });
    }];
}

- (void)dealloc {
    NSLog(@"dealloc");
    [self.message ph_removeObserver:self
                             forKey:@"text"];
}

- (IBAction)click:(UIButton *)sender {
    self.message.text = [NSString stringWithFormat:@"%d", arc4random_uniform(100)];
}


@end

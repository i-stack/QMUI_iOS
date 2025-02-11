/*****
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2019 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 *****/

//
//  UISearchBar+QMUI.m
//  qmui
//
//  Created by QMUI Team on 16/5/26.
//

#import "UISearchBar+QMUI.h"
#import "QMUICore.h"
#import "UIImage+QMUI.h"
#import "UIView+QMUI.h"

#define SearchBarActiveHeightIOS11Later (IS_NOTCHED_SCREEN ? 55.0f : 50.0f)
#define SearchBarNormalHeightIOS11Later 56.0f
#define HasDismissingAnimationBUG (IOS_VERSION > 11.0)

@implementation UISearchBar (QMUI)

QMUISynthesizeBOOLProperty(qmui_usedAsTableHeaderView, setQmui_usedAsTableHeaderView)
QMUISynthesizeUIEdgeInsetsProperty(qmui_textFieldMargins, setQmui_textFieldMargins)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        ExtendImplementationOfVoidMethodWithTwoArguments([UISearchBar class], @selector(setShowsCancelButton:animated:), BOOL, BOOL, ^(UISearchBar *selfObject, BOOL firstArgv, BOOL secondArgv) {
            if (selfObject.qmui_cancelButton && selfObject.qmui_cancelButtonFont) {
                selfObject.qmui_cancelButton.titleLabel.font = selfObject.qmui_cancelButtonFont;
            }
        });
        
        ExtendImplementationOfVoidMethodWithSingleArgument([UISearchBar class], @selector(setPlaceholder:), NSString *, (^(UISearchBar *selfObject, NSString *placeholder) {
            if (selfObject.qmui_placeholderColor || selfObject.qmui_font) {
                NSMutableDictionary<NSString *, id> *attributes = [[NSMutableDictionary alloc] init];
                if (selfObject.qmui_placeholderColor) {
                    attributes[NSForegroundColorAttributeName] = selfObject.qmui_placeholderColor;
                }
                if (selfObject.qmui_font) {
                    attributes[NSFontAttributeName] = selfObject.qmui_font;
                }
                selfObject.qmui_textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:attributes];
            }
        }));
        
        if (HasDismissingAnimationBUG) {
            // -[_UISearchBarLayout applyLayout] 是 iOS 13 系统新增的方法，它会在 UISearchBar 后继续执行进行一些布局
            OverrideImplementation(NSClassFromString(@"_UISearchBarLayout"), NSSelectorFromString(@"applyLayout"), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^(UIView *selfObject) {
                    
                    // call super
                    void (^callSuperBlock)(void) = ^{
                        void (*originSelectorIMP)(id, SEL);
                        originSelectorIMP = (void (*)(id, SEL))originalIMPProvider();
                        originSelectorIMP(selfObject, originCMD);
                    };

                    UISearchBar *searchBar = (UISearchBar *)((UIView *)[selfObject qmui_valueForKey:@"_searchBarBackground"]).superview.superview;
                    
                    NSAssert(searchBar == nil || [searchBar isKindOfClass:[UISearchBar class]], @"not a searchBar");

                    if (searchBar && searchBar.qmui_searchController.isBeingDismissed && searchBar.qmui_usedAsTableHeaderView) {
                        CGRect previousRect = searchBar.qmui_backgroundView.frame;
                        callSuperBlock();
                        // applyLayout 方法中会修改 _searchBarBackground  的 frame ，从而覆盖掉 qmui_usedAsTableHeaderView 做出的调整，所以这里还原本次修改。
                        searchBar.qmui_backgroundView.frame = previousRect;
                    } else {
                        callSuperBlock();
                    }
                };
                
            });
        }
        
        OverrideImplementation(NSClassFromString(@"UISearchBarTextField"), @selector(setFrame:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UITextField *textField, CGRect frame) {
                
                UISearchBar *searchBar = nil;
                if (@available(iOS 13.0, *)) {
                    searchBar = (UISearchBar *)textField.superview.superview.superview;
                } else {
                    searchBar = (UISearchBar *)textField.superview.superview;
                }
                
                NSAssert(searchBar == nil || [searchBar isKindOfClass:[UISearchBar class]], @"not a searchBar");
                
                if (searchBar) {
                    if (HasDismissingAnimationBUG && searchBar.qmui_usedAsTableHeaderView && searchBar.qmui_searchController.isBeingDismissed) {
                        frame.origin.y = 14; // default value
                    }
                    
                    if (!UIEdgeInsetsEqualToEdgeInsets(searchBar.qmui_textFieldMargins, UIEdgeInsetsZero)) {
                        frame = CGRectInsetEdges(frame, searchBar.qmui_textFieldMargins);
                    }
                    
                    CGFloat textFieldCornerRadius = SearchBarTextFieldCornerRadius;
                    if (textFieldCornerRadius != 0) {
                        textFieldCornerRadius = textFieldCornerRadius > 0 ? textFieldCornerRadius : CGRectGetHeight(frame) / 2.0;
                    }
                    searchBar.qmui_textField.layer.cornerRadius = textFieldCornerRadius;
                    searchBar.qmui_textField.clipsToBounds = textFieldCornerRadius != 0;
                }
                
                void (*originSelectorIMP)(id, SEL, CGRect);
                originSelectorIMP = (void (*)(id, SEL, CGRect))originalIMPProvider();
                originSelectorIMP(textField, originCMD, frame);

            };
        });
        
        
        ExtendImplementationOfVoidMethodWithoutArguments([UISearchBar class], @selector(layoutSubviews), ^(UISearchBar *selfObject) {
            // 修复 iOS 13 backgroundView 没有撑开到顶部的问题
            if (IOS_VERSION >= 13.0 && selfObject.qmui_usedAsTableHeaderView && selfObject.qmui_isActive) {
                selfObject.qmui_backgroundView.qmui_height = StatusBarHeightConstant + selfObject.qmui_height;
                selfObject.qmui_backgroundView.qmui_top = -StatusBarHeightConstant;
            }
            [selfObject fixLandscapeStyle];
            [selfObject fixDismissingAnimation];
        });
        
        OverrideImplementation([UISearchBar class], @selector(setFrame:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UISearchBar *selfObject, CGRect frame) {
                
                // call super
                void (^callSuperBlock)(CGRect) = ^void(CGRect aFrame) {
                    void (*originSelectorIMP)(id, SEL, CGRect);
                    originSelectorIMP = (void (*)(id, SEL, CGRect))originalIMPProvider();
                    originSelectorIMP(selfObject, originCMD, aFrame);
                };
                
                if (!selfObject.qmui_usedAsTableHeaderView) {
                    callSuperBlock(frame);
                    return;
                }
                
                // 重写 setFrame: 是为了这个 issue：https://github.com/Tencent/QMUI_iOS/issues/233
                
                if (@available(iOS 11, *)) {
                    // iOS 11 下用 tableHeaderView 的方式使用 searchBar 的话，进入搜索状态时 y 偏上了，导致间距错乱
                    
                    // iOS 13 iPad 在退出动画时 y 值可能为负，需要修正
                    if (selfObject.qmui_searchController.isBeingDismissed && CGRectGetMinY(frame) < 0) {
                        frame = CGRectSetY(frame, 0);
                    }
                    
                    if (![selfObject qmui_isActive]) {
                        callSuperBlock(frame);
                        return;
                    }
                    
                    if (IS_NOTCHED_SCREEN) {
                        // 竖屏
                        if (CGRectGetMinY(frame) == 38) {
                            // searching
                            frame = CGRectSetY(frame, 44);
                        }
                        
                        // 横屏
                        if (CGRectGetMinY(frame) == -6) {
                            frame = CGRectSetY(frame, 0);
                        }
                    } else {
                        
                        // 竖屏
                        if (CGRectGetMinY(frame) == 14) {
                            frame = CGRectSetY(frame, 20);
                        }
                        
                        // 横屏
                        if (CGRectGetMinY(frame) == -6) {
                            frame = CGRectSetY(frame, 0);
                        }
                    }
                    // 强制在激活状态下 高度也为 56，方便后续做平滑过渡动画 (iOS 11 默认下，非刘海屏的机器激活后为 50，刘海屏激活后为 55)
                    if (frame.size.height != 56) {
                        frame.size.height = 56;
                    }
                }
                callSuperBlock(frame);
            };
        });
    });
}

static char kAssociatedObjectKey_PlaceholderColor;
- (void)setQmui_placeholderColor:(UIColor *)qmui_placeholderColor {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_PlaceholderColor, qmui_placeholderColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.placeholder) {
        // 触发 setPlaceholder 里更新 placeholder 样式的逻辑
        self.placeholder = self.placeholder;
    }
}

- (UIColor *)qmui_placeholderColor {
    return (UIColor *)objc_getAssociatedObject(self, &kAssociatedObjectKey_PlaceholderColor);
}

static char kAssociatedObjectKey_TextColor;
- (void)setQmui_textColor:(UIColor *)qmui_textColor {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_TextColor, qmui_textColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.qmui_textField.textColor = qmui_textColor;
}

- (UIColor *)qmui_textColor {
    return (UIColor *)objc_getAssociatedObject(self, &kAssociatedObjectKey_TextColor);
}

static char kAssociatedObjectKey_font;
- (void)setQmui_font:(UIFont *)qmui_font {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_font, qmui_font, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (self.placeholder) {
        // 触发 setPlaceholder 里更新 placeholder 样式的逻辑
        self.placeholder = self.placeholder;
    }
    
    // 更新输入框的文字样式
    self.qmui_textField.font = qmui_font;
}

- (UIFont *)qmui_font {
    return (UIFont *)objc_getAssociatedObject(self, &kAssociatedObjectKey_font);
}

- (UITextField *)qmui_textField {
    UITextField *textField = [self qmui_valueForKey:@"searchField"];
    return textField;
}

- (UIButton *)qmui_cancelButton {
    UIButton *cancelButton = [self qmui_valueForKey:@"cancelButton"];
    return cancelButton;
}

static char kAssociatedObjectKey_cancelButtonFont;
- (void)setQmui_cancelButtonFont:(UIFont *)qmui_cancelButtonFont {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_cancelButtonFont, qmui_cancelButtonFont, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.qmui_cancelButton.titleLabel.font = qmui_cancelButtonFont;
}

- (UIFont *)qmui_cancelButtonFont {
    return (UIFont *)objc_getAssociatedObject(self, &kAssociatedObjectKey_cancelButtonFont);
}

- (UISegmentedControl *)qmui_segmentedControl {
    // 注意，segmentedControl 只是整条 scopeBar 里的一部分，虽然它的 key 叫做“scopeBar”
    UISegmentedControl *segmentedControl = [self qmui_valueForKey:@"scopeBar"];
    return segmentedControl;
}

- (BOOL)qmui_isActive {
    return (self.qmui_searchController.isBeingPresented || self.qmui_searchController.isActive);
}

- (UISearchController *)qmui_searchController {
    return [self qmui_valueForKey:@"_searchController"];
}

- (void)fixLandscapeStyle {
    if (self.qmui_usedAsTableHeaderView) {
        if (@available(iOS 11, *)) {
            if ([self qmui_isActive] && IS_LANDSCAPE) {
                // 11.0 及以上的版本，横屏时，searchBar 内部的内容布局会偏上，所以这里强制居中一下
                CGFloat fixedOffset = (SearchBarActiveHeightIOS11Later - SearchBarNormalHeightIOS11Later) / 2.0;
                self.qmui_textField.frame = CGRectSetY(self.qmui_textField.frame, self.qmui_textField.qmui_topWhenCenterInSuperview + fixedOffset);
                self.qmui_cancelButton.frame = CGRectSetY(self.qmui_cancelButton.frame, self.qmui_cancelButton.qmui_topWhenCenterInSuperview + fixedOffset);
                if (self.qmui_segmentedControl.superview.qmui_top < self.qmui_textField.qmui_bottom) {
                    // scopeBar 显示在搜索框右边
                    self.qmui_segmentedControl.superview.qmui_top = self.qmui_segmentedControl.superview.qmui_topWhenCenterInSuperview + fixedOffset;
                }
            }
        }
    }
}

- (void)fixDismissingAnimation {
    if (!HasDismissingAnimationBUG || !self.qmui_usedAsTableHeaderView) return;
    
    if (self.qmui_searchController.isBeingDismissed) {
        
        if (IS_NOTCHED_SCREEN && self.frame.origin.y == 43) { // 修复刘海屏下，系统计算少了一个 pt
            self.frame = CGRectSetY(self.frame, StatusBarHeightConstant);
        }
        
        UIView *searchBarContainerView = self.superview;
    
        // 每次激活搜索框，searchBarContainerView 都会重新创建一个
        if (searchBarContainerView.layer.masksToBounds == YES) {
            searchBarContainerView.layer.masksToBounds = NO;
            
            if (@available(iOS 13.0, *)) {
                // iOS 13 在 layoutSubview 并没有对 qmui_textField 进行布局调整，此处手动设置一下 frame 从而触发 Swizzle 的修正逻辑
                [self.qmui_textField setFrame:self.qmui_textField.frame];
            }

            // 不修改 searchBar y 的时候，clipedTop 是有值的
            CGFloat clipedTop = MAX(0, -[self.qmui_backgroundView.superview convertRect:self.qmui_backgroundView.frame toView:searchBarContainerView].origin.y);
            CGFloat top = [self.qmui_textField.superview convertRect:self.qmui_textField.frame toView:searchBarContainerView].origin.y;
            CGFloat height = clipedTop + top - self.qmui_textFieldMargins.top + 28 + 14;
            // 计算出 qmui_backgroundView 满足动画过渡的最大高度
            self.qmui_backgroundView.qmui_height = height;
            
            CGFloat diff = self.qmui_backgroundView.qmui_height - searchBarContainerView.qmui_height;
            if (diff > 0) {
                CAShapeLayer *maskLayer = [CAShapeLayer layer];
                CGMutablePathRef path = CGPathCreateMutable();
                CGPathAddRect(path, NULL, CGRectMake(0, 0, searchBarContainerView.qmui_width, searchBarContainerView.qmui_height));
                maskLayer.path = path;
                searchBarContainerView.layer.mask = maskLayer;
                
                CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"path"];
                CGMutablePathRef animationPath = CGPathCreateMutable();
                CGPathAddRect(animationPath, NULL, CGRectMake(0, 0, searchBarContainerView.qmui_width, self.qmui_backgroundView.qmui_height));
                animation.toValue   = (__bridge id)animationPath;
                animation.removedOnCompletion = NO;
                animation.fillMode = kCAFillModeForwards;
                [searchBarContainerView.layer.mask addAnimation:animation forKey:nil];
            }
        }
        
    }

}

- (UIView *)qmui_backgroundView {
    BeginIgnorePerformSelectorLeaksWarning
    UIView *backgroundView = [self performSelector:NSSelectorFromString(@"_backgroundView")];
    EndIgnorePerformSelectorLeaksWarning
    return backgroundView;
}


- (void)qmui_styledAsQMUISearchBar {
    if (!QMUICMIActivated) {
        return;
    }
    
    // 搜索框的字号及 placeholder 的字号
    UIFont *font = SearchBarFont;
    if (font) {
        self.qmui_font = font;
    }

    // 搜索框的文字颜色
    UIColor *textColor = SearchBarTextColor;
    if (textColor) {
        self.qmui_textColor = textColor;
    }

    // placeholder 的文字颜色
    UIColor *placeholderColor = SearchBarPlaceholderColor;
    if (placeholderColor) {
        self.qmui_placeholderColor = placeholderColor;
    }

    self.placeholder = @"搜索";
    self.autocorrectionType = UITextAutocorrectionTypeNo;
    self.autocapitalizationType = UITextAutocapitalizationTypeNone;

    // 设置搜索icon
    UIImage *searchIconImage = SearchBarSearchIconImage;
    if (searchIconImage) {
        if (!CGSizeEqualToSize(searchIconImage.size, CGSizeMake(14, 14))) {
            NSLog(@"搜索框放大镜图片（SearchBarSearchIconImage）的大小最好为 (14, 14)，否则会失真，目前的大小为 %@", NSStringFromCGSize(searchIconImage.size));
        }
        [self setImage:searchIconImage forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
    }

    // 设置搜索右边的清除按钮的icon
    UIImage *clearIconImage = SearchBarClearIconImage;
    if (clearIconImage) {
        [self setImage:clearIconImage forSearchBarIcon:UISearchBarIconClear state:UIControlStateNormal];
    }

    // 设置SearchBar上的按钮颜色
    self.tintColor = SearchBarTintColor;

    // 输入框背景图
    UIColor *textFieldBackgroundColor = SearchBarTextFieldBackground;
    if (textFieldBackgroundColor) {
        [self setSearchFieldBackgroundImage:[[UIImage qmui_imageWithColor:textFieldBackgroundColor size:CGSizeMake(60, 28) cornerRadius:0] resizableImageWithCapInsets:UIEdgeInsetsMake(10, 10, 10, 10)] forState:UIControlStateNormal];
    }
    
    // 输入框边框
    UIColor *textFieldBorderColor = SearchBarTextFieldBorderColor;
    if (textFieldBorderColor) {
        self.qmui_textField.layer.borderWidth = PixelOne;
        self.qmui_textField.layer.borderColor = textFieldBorderColor.CGColor;
    }
    
    // 整条bar的背景
    // 为了让 searchBar 底部的边框颜色支持修改，背景色不使用 barTintColor 的方式去改，而是用 backgroundImage
    UIImage *backgroundImage = nil;
    
    UIColor *barTintColor = SearchBarBarTintColor;
    if (barTintColor) {
        backgroundImage = [UIImage qmui_imageWithColor:barTintColor size:CGSizeMake(10, 10) cornerRadius:0];
    }
    
    UIColor *bottomBorderColor = SearchBarBottomBorderColor;
    if (bottomBorderColor) {
        if (!backgroundImage) {
            backgroundImage = [UIImage qmui_imageWithColor:UIColorWhite size:CGSizeMake(10, 10) cornerRadius:0];
        }
        backgroundImage = [backgroundImage qmui_imageWithBorderColor:bottomBorderColor borderWidth:PixelOne borderPosition:QMUIImageBorderPositionBottom];
    }
    
    if (backgroundImage) {
        backgroundImage = [backgroundImage resizableImageWithCapInsets:UIEdgeInsetsMake(1, 1, 1, 1)];
        [self setBackgroundImage:backgroundImage forBarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
        [self setBackgroundImage:backgroundImage forBarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefaultPrompt];
    }
}

@end

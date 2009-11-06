#import "Three20/TTView.h"

@interface TTTableHeaderView : TTView {
  UILabel* _label;
}

@property (nonatomic,readonly) UILabel *label;

- (id)initWithTitle:(NSString*)title;

@end

#import "Three20/TTTableViewDelegate.h"
#import "Three20/TTTableViewDataSource.h"
#import "Three20/TTTableViewController.h"
#import "Three20/TTTableItem.h"
#import "Three20/TTTableItemCell.h"
#import "Three20/TTTableHeaderView.h"
#import "Three20/TTTableView.h"
#import "Three20/TTStyledTextLabel.h"
#import "Three20/TTNavigator.h"
#import "Three20/TTDefaultStyleSheet.h"
#import "Three20/TTURLRequestQueue.h"

///////////////////////////////////////////////////////////////////////////////////////////////////
// global

static const CGFloat kEmptyHeaderHeight = 1;
static const CGFloat kSectionHeaderHeight = 35;

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation TTTableViewDelegate

@synthesize controller = _controller;

///////////////////////////////////////////////////////////////////////////////////////////////////
// NSObject

- (id)initWithController:(TTTableViewController*)controller {
  if (self = [super init]) {
    _controller = controller;
    _headers = nil;
  }
  return self;
}

- (void)dealloc {
  TT_RELEASE_SAFELY(_headers);
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// UITableViewDelegate

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
  TTStyle *tableHeaderStyle = nil;
  UIColor *tableHeaderTextColor = nil;
  UIColor *tableHeaderShadowColor = nil;
  UIFont *tableHeaderFont = nil;
  BOOL customView = NO;
  
  if (tableView.style == UITableViewStylePlain && TTSTYLEVAR(tableHeaderTintColor)) {
    tableHeaderStyle = TTSTYLE(tableHeader);
    tableHeaderTextColor = TTSTYLEVAR(tableHeaderTextColor)
                            ? TTSTYLEVAR(tableHeaderTextColor)
                            : TTSTYLEVAR(linkTextColor);
    tableHeaderShadowColor = TTSTYLEVAR(tableHeaderShadowColor)
                              ? TTSTYLEVAR(tableHeaderShadowColor)
                              : [UIColor clearColor];
    tableHeaderFont = TTSTYLEVAR(tableHeaderPlainFont);
    customView = YES;
  } else if (tableView.style == UITableViewStyleGrouped && TTSTYLEVAR(tableHeaderGroupedTextColor)) {
    tableHeaderStyle = TTSTYLE(tableHeaderGrouped);
    tableHeaderTextColor = TTSTYLEVAR(tableHeaderGroupedTextColor)
                            ? TTSTYLEVAR(tableHeaderGroupedTextColor)
                            : TTSTYLEVAR(linkTextColor);
    tableHeaderShadowColor = TTSTYLEVAR(tableHeaderGroupedShadowColor)
                              ? TTSTYLEVAR(tableHeaderGroupedShadowColor)
                              : [UIColor clearColor];
    tableHeaderFont = TTSTYLEVAR(tableHeaderGroupedFont);
    customView = YES;
  }
  
  if (customView) {
    if ([tableView.dataSource respondsToSelector:@selector(tableView:titleForHeaderInSection:)]) {
      NSString* title = [tableView.dataSource tableView:tableView titleForHeaderInSection:section];
      if (title.length) {
        TTTableHeaderView* header = [_headers objectForKey:title];
        if (!header) {
          if (!_headers) {
            _headers = [[NSMutableDictionary alloc] init];
          }
          header = [[[TTTableHeaderView alloc] initWithTitle:title] autorelease];
          header.style = tableHeaderStyle;
          header.label.textColor = tableHeaderTextColor;
          header.label.shadowColor = tableHeaderShadowColor;
          header.label.font = tableHeaderFont;
          [_headers setObject:header forKey:title];
        }
        return header;
      }
    }
  }
  return nil;
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  id<TTTableViewDataSource> dataSource = (id<TTTableViewDataSource>)tableView.dataSource;
  id object = [dataSource tableView:tableView objectForRowAtIndexPath:indexPath];
  if ([object isKindOfClass:[TTTableLinkedItem class]]) {
    TTTableLinkedItem* item = object;
    if (item.URL && [_controller shouldOpenURL:item.URL]) {
      [[TTNavigator navigator] openURL:item.URL query:item.query animated:YES];
    }
    if ([object isKindOfClass:[TTTableButton class]]) {
      [tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else if ([object isKindOfClass:[TTTableMoreButton class]]) {
      TTTableMoreButton* moreLink = (TTTableMoreButton*)object;
      moreLink.isLoading = YES;
      TTTableMoreButtonCell* cell
        = (TTTableMoreButtonCell*)[tableView cellForRowAtIndexPath:indexPath];
      cell.animating = YES;
      [tableView deselectRowAtIndexPath:indexPath animated:YES];
      
      [_controller.model load:TTURLRequestCachePolicyDefault more:YES];
    }
  }

  [_controller didSelectObject:object atIndexPath:indexPath];
}

- (void)tableView:(UITableView*)tableView
        accessoryButtonTappedForRowWithIndexPath:(NSIndexPath*)indexPath {
  id<TTTableViewDataSource> dataSource = (id<TTTableViewDataSource>)tableView.dataSource;
  id object = [dataSource tableView:tableView objectForRowAtIndexPath:indexPath];
  if ([object isKindOfClass:[TTTableLinkedItem class]]) {
    TTTableLinkedItem* item = object;
    if (item.accessoryURL && [_controller shouldOpenURL:item.accessoryURL]) {
      TTOpenURL(item.accessoryURL);
    }
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// UIScrollViewDelegate

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
  [TTURLRequestQueue mainQueue].suspended = YES;
  return YES;
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
  [TTURLRequestQueue mainQueue].suspended = NO;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
  if (_controller.menuView) {
    [_controller hideMenu:YES];
  }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
  [TTURLRequestQueue mainQueue].suspended = YES;

  [_controller didBeginDragging];
  
  if ([scrollView isKindOfClass:[TTTableView class]]) {
    TTTableView* tableView = (TTTableView*)scrollView;
    tableView.highlightedLabel.highlightedNode = nil;
    tableView.highlightedLabel = nil;
  }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
  if (!decelerate) {
    [TTURLRequestQueue mainQueue].suspended = NO;
  }

  [_controller didEndDragging];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
  [TTURLRequestQueue mainQueue].suspended = NO;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// TTTableViewDelegate

- (void)tableView:(UITableView*)tableView touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
  if (_controller.menuView) {
    [_controller hideMenu:YES];
  }
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation TTTableViewVarHeightDelegate

///////////////////////////////////////////////////////////////////////////////////////////////////
// UITableViewDelegate

- (CGFloat)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath {
  id<TTTableViewDataSource> dataSource = (id<TTTableViewDataSource>)tableView.dataSource;

  id object = [dataSource tableView:tableView objectForRowAtIndexPath:indexPath];
  Class cls = [dataSource tableView:tableView cellClassForObject:object];
  return [cls tableView:tableView rowHeightForObject:object];
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation TTTableViewPlainDelegate
@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation TTTableViewPlainVarHeightDelegate
@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@implementation TTTableViewGroupedVarHeightDelegate

///////////////////////////////////////////////////////////////////////////////////////////////////
// UITableViewDelegate

- (CGFloat)tableView:(UITableView*)tableView heightForHeaderInSection:(NSInteger)section {
  NSString* title = nil;
  if ([tableView.dataSource respondsToSelector:@selector(tableView:titleForHeaderInSection:)]) {
    title = [tableView.dataSource tableView:tableView titleForHeaderInSection:section];
  }
  if (!title.length) {
    return kEmptyHeaderHeight;
  } else {
    return kSectionHeaderHeight;
  }
}

@end

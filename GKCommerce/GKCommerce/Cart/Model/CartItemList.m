//
//  CartItemCollection.m
//  GKCommerce
//
//  Created by 小悟空 on 12/2/14.
//  Copyright (c) 2014 GKCommerce. All rights reserved.
//

#import "CartItemList.h"

@implementation CartItemList
{
    BOOL isBatchOperation;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.items = [[NSMutableArray alloc] init];
        self.selected = [[NSMutableArray alloc] init];
        isBatchOperation = NO;
    }
    return self;
}

- (CartItem *)itemAtIndex:(NSInteger)index
{
    return [self.items objectAtIndex:index];
}

- (void)addItem:(CartItem *)item
{
    [item addObserver:self forKeyPath:@"quantity"
              options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
              context:nil];
    [self.items addObject:item];
    
    @weakify(self);
    [RACObserve(item, selected) subscribeNext:^(id x) {
        @strongify(self);
        BOOL selected = [x boolValue];
        if (selected)
            [self.selected addObject:item];
        else
            [self.selected removeObject:item];
        self.price = [[NSDecimalNumber alloc]
                      initWithFloat:[self wantTotalPrice]];
        if (!isBatchOperation) {
            [self willChangeValueForKey:@"selected"];
            [self didChangeValueForKey:@"selected"];
        }
    }];
    
    [RACObserve(item, quantity) subscribeNext:^(id x) {
        @strongify(self);
        
        self.price = [[NSDecimalNumber alloc]
                      initWithFloat:[self wantTotalPrice]];
    }];
    item.list = self;
  
  Cart *cart = item.list.cart;
  [cart willChangeValueForKey:@"itemsOfStore"];
  [cart didChangeValueForKey:@"itemsOfStore"];
}

- (void)addItems:(NSArray *)items
{
    isBatchOperation = YES;
    for (CartItem *item in items) {
        [self addItem:item];
    }
    isBatchOperation = NO;
    [self willChangeValueForKey:@"selected"];
    [self didChangeValueForKey:@"selected"];
}

- (void)removeItem:(CartItem *)item
{
    [item removeObserver:self forKeyPath:@"quantity"];
    [item removeObserver:self forKeyPath:@"selected"];
    [self willChangeValueForKey:@"items"];
    [self.items removeObject:item];
    [self didChangeValueForKey:@"items"];
}

- (void)removeItemWithID:(NSInteger)itemID
{
    [self.items removeObject:[self itemWithID:itemID]];
}

- (CartItem *)itemWithID:(NSInteger)itemID
{
    __block CartItem *found = nil;
    [self.items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx,
                                                    BOOL *stop) {
        CartItem *item = (CartItem *)obj;
        if (item.itemID == itemID)
            found = item;
    }];
    
    return found;
}

// TODO: 观察CartItem的selected属性，维护selected集合

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([@"quantity" isEqualToString:keyPath] &&
        [object isKindOfClass: [CartItem class]] &&
        0 == ((CartItem *)object).quantity) {
        [self removeItem:object];
    }
}

- (BOOL)isAllSelected
{
    return self.items.count == self.selected.count;
}

- (void)selectAllItems:(BOOL)select
{
    isBatchOperation = YES;
    for (CartItem *item in self.items) {
        if (item.selected != select)
            item.selected = select;
    }
    [self willChangeValueForKey:@"selected"];
    [self didChangeValueForKey:@"selected"];
    isBatchOperation = NO;
}

- (float)wantTotalPrice
{
    float total = 0;
    for (CartItem *item in self.selected)
        total += item.price.floatValue * item.quantity;
    return total;
}
@end

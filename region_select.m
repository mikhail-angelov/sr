#import <Cocoa/Cocoa.h>
#include "region_select.h"

// Expose this function to Go
struct Region select_region() {
    __block struct Region region = {0, 0, 0, 0};
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSWindow *window = [[NSWindow alloc] initWithContentRect:[[NSScreen mainScreen] frame]
                                                       styleMask:NSWindowStyleMaskBorderless
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        [window setOpaque:NO];
        [window setBackgroundColor:[NSColor colorWithCalibratedWhite:0 alpha:0.2]];
        [window setLevel:NSStatusWindowLevel];
        [window setIgnoresMouseEvents:NO];
        [window makeKeyAndOrderFront:nil];

        __block NSPoint startPoint = NSZeroPoint;
        __block NSPoint endPoint = NSZeroPoint;
        __block BOOL selecting = NO;

        NSView *contentView = [window contentView];
        NSView *frameView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        [frameView setWantsLayer:YES];
        frameView.layer.borderColor = [[NSColor colorWithCalibratedRed:0 green:0.5 blue:1 alpha:0.8] CGColor];
        frameView.layer.borderWidth = 3.0;
        frameView.layer.backgroundColor = [[NSColor colorWithCalibratedRed:0 green:0.5 blue:1 alpha:0.2] CGColor];
        [contentView addSubview:frameView];
        [window display];

        NSEvent *event = nil;
        while ((event = [NSApp nextEventMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged
                                           untilDate:[NSDate distantFuture]
                                              inMode:NSEventTrackingRunLoopMode
                                             dequeue:YES])) {
            if ([event type] == NSEventTypeLeftMouseDown) {
                startPoint = [event locationInWindow];
                endPoint = startPoint;
                selecting = YES;
                // Show initial frame
                int x = (int)fmin(startPoint.x, endPoint.x);
                int y = (int)fmin(startPoint.y, endPoint.y);
                int w = (int)fabs(endPoint.x - startPoint.x);
                int h = (int)fabs(endPoint.y - startPoint.y);
                [frameView setFrame:NSMakeRect(x, y, w, h)];
                [window display];
            } else if ([event type] == NSEventTypeLeftMouseDragged && selecting) {
                endPoint = [event locationInWindow];
                int x = (int)fmin(startPoint.x, endPoint.x);
                int y = (int)fmin(startPoint.y, endPoint.y);
                int w = (int)fabs(endPoint.x - startPoint.x);
                int h = (int)fabs(endPoint.y - startPoint.y);
                [frameView setFrame:NSMakeRect(x, y, w, h)];
                [window display];
            } else if ([event type] == NSEventTypeLeftMouseUp && selecting) {
                endPoint = [event locationInWindow];
                selecting = NO;
                int x = (int)fmin(startPoint.x, endPoint.x);
                int y = (int)fmin(startPoint.y, endPoint.y);
                int w = (int)fabs(endPoint.x - startPoint.x);
                int h = (int)fabs(endPoint.y - startPoint.y);
                [frameView setFrame:NSMakeRect(x, y, w, h)];
                [window display];
                // Show selected frame for 1 second
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
                break;
            }
        }
        int x = (int)fmin(startPoint.x, endPoint.x);
        int y = (int)fmin(startPoint.y, endPoint.y);
        int w = (int)fabs(endPoint.x - startPoint.x);
        int h = (int)fabs(endPoint.y - startPoint.y);
        region.x = x;
        region.y = y;
        region.width = w;
        region.height = h;
        [window orderOut:nil];
    });
    return region;
}

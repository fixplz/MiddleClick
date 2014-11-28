//
//  Controller.m
//  MiddleClick
//
//  Created by Alex Galonsky on 11/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "Controller.h"
#import <Cocoa/Cocoa.h>
#import "TrayMenu.h"
#include <math.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h> 
#import "WakeObserver.h"

/***************************************************************************
 *
 * Multitouch API
 *
 ***************************************************************************/

typedef struct { float x,y; } mtPoint;
typedef struct { mtPoint pos,vel; } mtReadout;

typedef struct {
    int frame;
    double timestamp;
    int identifier, state, foo3, foo4;
    mtReadout normalized;
    float size;
    int zero1;
    float angle, majorAxis, minorAxis; // ellipsoid
    mtReadout mm;
    int zero2[2];
    float unk2;
} Finger;

typedef void *MTDeviceRef;
typedef int (*MTContactCallbackFunction)(int,Finger*,int,double,int);

MTDeviceRef MTDeviceCreateDefault();
CFMutableArrayRef MTDeviceCreateList(void); 
void MTRegisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
void MTDeviceStart(MTDeviceRef, int); // thanks comex
void MTDeviceStop(MTDeviceRef);


MTDeviceRef dev;

NSDate *touchStartTime;

BOOL maybeMiddleClick;
BOOL pressed;

float mouseDelta, mouseLastX, mouseLastY;

@implementation Controller

- (void) start
{
	pressed = NO;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
    [NSApplication sharedApplication];
	
	
	//Get list of all multi touch devices
	NSMutableArray* deviceList = (NSMutableArray*)MTDeviceCreateList(); //grab our device list
	
	
	//Iterate and register callbacks for multitouch devices.
	for(int i = 0; i<[deviceList count]; i++) //iterate available devices
	{
        MTRegisterContactFrameCallback((MTDeviceRef)[deviceList objectAtIndex:i], callback); //assign callback for device
        MTDeviceStart((MTDeviceRef)[deviceList objectAtIndex:i],0); //start sending events
	}
	
	//register a callback to know when osx come back from sleep
	WakeObserver *wo = [[WakeObserver alloc] init];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: wo selector: @selector(receiveWakeNote:) name: NSWorkspaceDidWakeNotification object: NULL];
	
	
	//add traymenu
    TrayMenu *menu = [[TrayMenu alloc] initWithController:self];
    [NSApp setDelegate:menu];
    [NSApp run];
	
	[pool release];
}



int callback(int device, Finger *data, int nFingers, double timestamp, int frame) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
	
    if (nFingers==0){
        
        if(mouseDelta != 0. && mouseDelta < 0.07f && -[touchStartTime timeIntervalSinceNow] < 0.3) {
            // Emulate a middle click
            
            // get the current pointer location
            CGEventRef ourEvent = CGEventCreate(NULL);
            CGPoint ourLoc = CGEventGetLocation(ourEvent);
            
            /*
             // CMD+Click code
             CGPostKeyboardEvent( (CGCharCode)0, (CGKeyCode)55, true );
             CGPostMouseEvent( ourLoc, 1, 1, 1);
             CGPostMouseEvent( ourLoc, 1, 1, 0);
             CGPostKeyboardEvent( (CGCharCode)0, (CGKeyCode)55, false );
             */
            
            // Real middle click
            #if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
                CGEventPost (kCGHIDEventTap, CGEventCreateMouseEvent (NULL,kCGEventOtherMouseDown,ourLoc,kCGMouseButtonCenter));
                CGEventPost (kCGHIDEventTap, CGEventCreateMouseEvent (NULL,kCGEventOtherMouseUp,ourLoc,kCGMouseButtonCenter));
            #else
                CGPostMouseEvent( ourLoc, 1, 3, 0, 0, 1);
                CGPostMouseEvent( ourLoc, 1, 3, 0, 0, 0);
            #endif
        }
        
        touchStartTime = NULL;
        
    } else if (nFingers>0 && touchStartTime == NULL){		
        NSDate *now = [[NSDate alloc] init];
        touchStartTime = [now retain];
        [now release];
        
        maybeMiddleClick = YES;
        mouseDelta = 0;
    } else {
        if (maybeMiddleClick==YES){
            NSTimeInterval elapsedTime = -[touchStartTime timeIntervalSinceNow];  
            if (elapsedTime > 0.5f)
                maybeMiddleClick = NO;
        }
    }
    
    if (nFingers>2) {
        maybeMiddleClick = NO;
        mouseDelta = 0;
    }
    
    if (nFingers==2) {
        Finger *f1 = &data[0];
        Finger *f2 = &data[1];
        
        float curX = (f1->normalized.pos.x+f2->normalized.pos.x);
        float curY = (f1->normalized.pos.y+f2->normalized.pos.y);
        
        if (maybeMiddleClick==YES) {
            mouseLastX = curX;
            mouseLastY = curY;
            mouseDelta = 0;
            maybeMiddleClick=NO;
        } else {
            mouseDelta += ABS(curX-mouseLastX)+ABS(curY-mouseLastY);
            mouseLastX = curX;
            mouseLastY = curY;
        }
    }
	
	[pool release];
	return 0;
}

@end

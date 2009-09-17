/**
 * Copyright 2003-2009, Mike Solomon <mas63@cornell.edu>
 * SIMBL is released under the GNU General Public License v2.
 * http://www.opensource.org/licenses/gpl-2.0.php
 */

#import "SIMBLApplication.h"

@implementation SIMBLApplication

+ (SIMBLApplication*) applicationWithNotification: (NSNotification*)_note {
	NSDictionary *info = [_note userInfo];
	return [[[self alloc]
			 initWithBundle: [NSBundle bundleWithPath: [info objectForKey: @"NSApplicationPath"]] 
			 runningApp: [info objectForKey: @"NSWorkspaceApplicationKey"]
			 pid: (pid_t)[[info objectForKey: @"NSApplicationProcessIdentifier"] intValue]
			 ] autorelease];
}

+ (SIMBLApplication*) currentApplication {
	Class clNSRunningApplication = NSClassFromString(@"NSRunningApplication");
	id rapp = clNSRunningApplication
		? [clNSRunningApplication currentApplication]
		: nil;
	
	return [[[self alloc]
			 initWithBundle: [NSBundle mainBundle] 
			 runningApp: rapp
			 pid: getpid()
			 ] autorelease];
}

- (id) initWithBundle: (NSBundle*)_bundle
		   runningApp: (id)_runningApp
				  pid: (pid_t)_pid {
	if ((self = [super init])) {
		bundle = [_bundle retain];
		runningApp = [_runningApp retain];
		pid = _pid;
	}
	return self;
}

- (void) dealloc {
	[bundle release];
	[runningApp release];
	[super dealloc];
}

@synthesize bundle, runningApp, pid;

@end

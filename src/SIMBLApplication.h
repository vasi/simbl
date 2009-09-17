/**
 * Copyright 2003-2009, Mike Solomon <mas63@cornell.edu>
 * SIMBL is released under the GNU General Public License v2.
 * http://www.opensource.org/licenses/gpl-2.0.php
 */

#import <Cocoa/Cocoa.h>


// A wrapper for NSWorkspace notification info
@interface SIMBLApplication : NSObject {
	NSBundle *bundle;
	id runningApp; // NSRunningApplication*
	pid_t pid;
}

+ (SIMBLApplication*) applicationWithNotification:(NSNotification *)_note;
+ (SIMBLApplication*) currentApplication;

- (id) initWithBundle: (NSBundle*)_bundle
		   runningApp: (id)_runningApp
				  pid: (pid_t)_pid;

@property (readonly) NSBundle *bundle;
@property (readonly) id runningApp; // NSRunningApplication*, nil if none
@property (readonly) pid_t pid;

@end

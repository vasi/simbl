/**
 * Copyright 2003-2009, Mike Solomon <mas63@cornell.edu>
 * SIMBL is released under the GNU General Public License v2.
 * http://www.opensource.org/licenses/gpl-2.0.php
 */

#import <Foundation/Foundation.h>
#import "SIMBLPlugin.h"

#define SIMBLPluginPath @"Application Support/SIMBL/Plugins"
#define SIMBLStringTable @"SIMBLStringTable"
#define SIMBLApplicationIdentifier @"SIMBLApplicationIdentifier"
#define SIMBLTargetApplications @"SIMBLTargetApplications"
#define SIMBLBundleIdentifier @"BundleIdentifier"
#define SIMBLMinBundleVersion @"MinBundleVersion"
#define SIMBLMaxBundleVersion @"MaxBundleVersion"
#define SIMBLTargetApplicationPath @"TargetApplicationPath"
#define SIMBLRequiredFrameworks @"RequiredFrameworks"

@class SIMBLApplication;

@protocol SIMBLPlugin
+ (void) install;
@end

@interface SIMBL : NSObject
{
}

+ (void) installPlugins;
+ (BOOL) shouldInstallPluginsIntoApplication:(SIMBLApplication*)_app;
+ (BOOL) loadBundleAtPath:(NSString*)_bundlePath;
+ (BOOL) shouldLoadBundleAtPath:(NSString*)_bundlePath;
+ (BOOL) shouldApplication:(SIMBLApplication*)_app loadBundleAtPath:(NSString*)_bundlePath;
+ (BOOL) shouldApplication:(NSBundle*)_appBundle loadBundle:(SIMBLPlugin*)_bundle withApplicationIdentifiers:(NSArray*)_applicationIdentifiers;
+ (BOOL) shouldApplication:(NSBundle*)_appBundle loadBundle:(SIMBLPlugin*)_bundle withTargetApplications:(NSArray*)_targetApplications;
+ (BOOL) loadBundle:(SIMBLPlugin*)_bundle;

+ (void) missingArch: (NSInteger)_arch inPlugin: (SIMBLPlugin*)_plugin;

@end

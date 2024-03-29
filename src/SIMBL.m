/**
 * Copyright 2003-2009, Mike Solomon <mas63@cornell.edu>
 * SIMBL is released under the GNU General Public License v2.
 * http://www.opensource.org/licenses/gpl-2.0.php
 */

#import "DTMacros.h"
#import "SIMBL.h"
#import "SIMBLPlugin.h"
#import "SIMBLApplication.h"
#import "NSAlert_SIMBL.h"

#import <objc/objc-class.h>

#import <mach-o/arch.h>
#import <mach-o/loader.h>
#import <crt_externs.h>

/*
	<key>SIMBLTargetApplications</key>
	<array>
		<dict>
			<key>BundleIdentifier</key>
			<string>com.apple.Safari</string>
			<key>MinBundleVersion</key>
			<integer>125</integer>
			<key>MaxBundleVersion</key>
			<integer>125</integer>
		</dict>
	</array>
*/

@implementation SIMBL

static NSMutableDictionary* loadedBundleIdentifiers = nil;

OSErr InjectEventHandler(const AppleEvent *ev, AppleEvent *reply, long refcon)
{
	OSErr resultCode = noErr;
	NSLog(@"InjectEventHandler");
	[SIMBL installPlugins];			
	return resultCode;	
}


+ (NSArray*) pluginPathList
{
	NSMutableArray* pluginPathList = [NSMutableArray array];
	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,  NSUserDomainMask | NSLocalDomainMask | NSNetworkDomainMask, YES);
	for (NSString* libraryPath in paths) {
		NSString* simblPath = [libraryPath stringByAppendingPathComponent:SIMBLPluginPath];
		NSArray* simblBundles = [[[NSFileManager defaultManager] directoryContentsAtPath:simblPath] pathsMatchingExtensions:[NSArray arrayWithObject:@"bundle"]];
		for (NSString* bundleName in simblBundles) {
			[pluginPathList addObject:[simblPath stringByAppendingPathComponent:bundleName]];
		}
	}
	return pluginPathList;
}


+ (void) installPlugins
{
	if (loadedBundleIdentifiers == nil)
		loadedBundleIdentifiers = [[NSMutableDictionary alloc] init];
	
	DTLog(DTLog_Developer, @"SIMBL loaded by path %@ <%@>", [[NSBundle mainBundle] bundlePath], [[NSBundle mainBundle] bundleIdentifier]);
	
	for (NSString* path in [SIMBL pluginPathList]) {
		BOOL bundleLoaded = [SIMBL loadBundleAtPath:path];
		if (bundleLoaded)
			DTLog(DTLog_Developer, @"loaded %@", path);
	}
}


+ (BOOL) shouldInstallPluginsIntoApplication:(SIMBLApplication*)_app
{
	for (NSString* path in [SIMBL pluginPathList]) {
		BOOL bundleLoaded = [SIMBL shouldApplication:_app loadBundleAtPath:path];
		if (bundleLoaded)
			return YES;
	}
	return NO;
}


/**
 * get this list of allowed application identifiers from the plugin's Info.plist
 * the special value * will cause any Cocoa app to load a bundle
 * @return YES if this should be loaded
 */
+ (BOOL) shouldLoadBundleAtPath:(NSString*)_bundlePath
{
	return [SIMBL shouldApplication: [SIMBLApplication currentApplication]
				   loadBundleAtPath:_bundlePath];
}


/**
 * get this list of allowed application identifiers from the plugin's Info.plist
 * the special value * will cause any Cocoa app to load a bundle
 * @return YES if this should be loaded
 */
+ (BOOL) shouldApplication:(SIMBLApplication*)_app loadBundleAtPath:(NSString*)_bundlePath
{
	DTLog(DTLog_Developer, @"checking bundle %@", _bundlePath);
	_bundlePath = [_bundlePath stringByStandardizingPath];
	SIMBLPlugin* pluginBundle = [SIMBLPlugin bundleWithPath:_bundlePath];
	if (pluginBundle == nil) {
		NSLog(@"Unable to load bundle at path '%@'", _bundlePath);
		return NO;
	}
	
	NSString* pluginIdentifier = [pluginBundle bundleIdentifier];
	if (pluginIdentifier == nil) {
		NSLog(@"No identifier for bundle at path '%@'", _bundlePath);
		return NO;
	}
	
	// Check for architecture compatibility
	if (_app.architecture != ArchitectureNotAvailable) {
		NSBundle *bundle = [NSBundle bundleWithPath: [pluginBundle path]];
		if ([[bundle executableArchitectures] containsObject:
			 [NSNumber numberWithInt: _app.architecture]] == NO) {
			[self missingArch: _app.architecture inPlugin: pluginBundle];
			return NO;
		}
	}
	
	// this is the new way of specifying when to load a bundle
	NSArray* targetApplications = [pluginBundle objectForInfoDictionaryKey:SIMBLTargetApplications];
	if (targetApplications)
		return [self shouldApplication: _app.bundle loadBundle:pluginBundle withTargetApplications:targetApplications];
	
	// fall back to the old method for older plugins - we should probably throw a depreaction warning
	NSArray* applicationIdentifiers = [pluginBundle objectForInfoDictionaryKey:SIMBLApplicationIdentifier];
	if (applicationIdentifiers)
		return [self shouldApplication: _app.bundle loadBundle:pluginBundle withApplicationIdentifiers:applicationIdentifiers];
	
	return NO;
}


/**
 * get this list of allowed application identifiers from the plugin's Info.plist
 * the special value * will cause any Cocoa app to load a bundle
 * if there is a match, this calls the main bundle's load method
 * @return YES if this bundle was loaded
 */
+ (BOOL) loadBundleAtPath:(NSString*)_bundlePath
{
	if ([SIMBL shouldLoadBundleAtPath:_bundlePath] == NO) {
		return NO;
	}
	
	SIMBLPlugin* pluginBundle = [SIMBLPlugin bundleWithPath:_bundlePath];

	// check to see if we already loaded code for this identifier (keeps us from double loading)
	// this is common if you have User vs. System-wide installs - probably mostly for developers
	// "physician, heal thyself!"
	NSString* pluginIdentifier = [pluginBundle bundleIdentifier];
	if ([loadedBundleIdentifiers objectForKey:pluginIdentifier] != nil)
		return NO;
	return [SIMBL loadBundle:pluginBundle];
}


/**
 * get this list of allowed application identifiers from the plugin's Info.plist
 * the special value * will cause any Cocoa app to load a bundle
 * if there is a match, this calls the main bundle's load method
 * @return YES if this bundle was loaded
 */
+ (BOOL) shouldApplication:(NSBundle*)_appBundle loadBundle:(SIMBLPlugin*)_bundle withApplicationIdentifiers:(NSArray*)_applicationIdentifiers
{	
	NSString* appIdentifier = [_appBundle bundleIdentifier];
	for (NSString* specifiedIdentifier in _applicationIdentifiers) {
		DTLog(DTLog_Developer, @"checking bundle %@ for identifier %@", [_bundle bundleIdentifier], specifiedIdentifier);
		if ([specifiedIdentifier isEqualToString:appIdentifier] == YES ||
			[specifiedIdentifier isEqualToString:@"*"] == YES) {
			DTLog(DTLog_Developer, @"load bundle %@", [_bundle bundleIdentifier]);
			NSLog(@"The plugin %@ (%@) is using a deprecated interface to SIMBL. Please contact the appropriate developer (not the SIMBL author) and refer them to http://culater.net/wiki/moin.cgi/CocoaReverseEngineering", [_bundle path], [_bundle bundleIdentifier]);
			return YES;
		}
	}
	
	return NO;
}


/**
 * get this list of allowed target applications from the plugin's Info.plist
 * the special value * will cause any Cocoa app to load a bundle
 * if there is a match, this calls the main bundle's load method
 * @return YES if this bundle was loaded
 */
+ (BOOL) shouldApplication:(NSBundle*)_appBundle loadBundle:(SIMBLPlugin*)_bundle withTargetApplications:(NSArray*)_targetApplications
{
	NSString* appIdentifier = [_appBundle bundleIdentifier];
	for (NSDictionary* targetAppProperties in _targetApplications) {
		NSString* targetAppIdentifier = [targetAppProperties objectForKey:SIMBLBundleIdentifier];
		DTLog(DTLog_Developer, @"checking target identifier %@", targetAppIdentifier);
		if ([targetAppIdentifier isEqualToString:appIdentifier] == NO &&
				[targetAppIdentifier isEqualToString:@"*"] == NO)
			continue;

		NSString* targetAppPath = [targetAppProperties objectForKey:SIMBLTargetApplicationPath];
		if (targetAppPath && [targetAppPath isEqualToString:[_appBundle bundlePath]] == NO)
			continue;

		NSArray* requiredFrameworks = [targetAppProperties objectForKey:SIMBLRequiredFrameworks];
		// NSLog(@"requiredFrameworks: %@", requiredFrameworks);
		BOOL missingFramework = NO;
		if (requiredFrameworks)
		{
			NSEnumerator* requiredFrameworkEnum = [requiredFrameworks objectEnumerator];
			NSDictionary* requiredFramework;
			while ((requiredFramework = [requiredFrameworkEnum nextObject]) && missingFramework == NO)
			{
				NSBundle* framework = [NSBundle bundleWithIdentifier:[requiredFramework objectForKey:@"BundleIdentifier"]];
				NSString* frameworkPath = [framework bundlePath];
				NSString* requiredPath = [requiredFramework objectForKey:@"BundlePath"];
				if ([frameworkPath isEqualToString:requiredPath] == NO) {				
					missingFramework = YES;
				}
			}
		}
		
		if (missingFramework)
			continue;
		
		int appVersion = [[_appBundle _dt_bundleVersion] intValue];
		
		int minVersion = 0;
		NSNumber* number;
		if ((number = [targetAppProperties objectForKey:SIMBLMinBundleVersion]))
			minVersion = [number intValue];
			
		int maxVersion = 0;
		if ((number = [targetAppProperties objectForKey:SIMBLMaxBundleVersion]))
			maxVersion = [number intValue];
		
		if ((maxVersion && appVersion > maxVersion) || (minVersion && appVersion < minVersion))
		{
			DTLog(DTLog_Developer, @"max: %d, min: %d, app: %d", maxVersion, minVersion, appVersion);
			[NSAlert errorAlert:NSLocalizedStringFromTableInBundle(@"SIMBL Error", SIMBLStringTable, DTOwnerBundle, @"Error alert primary message") withDetails:NSLocalizedStringFromTableInBundle(@"%@ %@ (v%@) has not been tested with the plugin %@ %@ (v%@). As a precaution, it has not been loaded. Please contact the plugin developer (not the SIMBL author) for further information.", SIMBLStringTable, DTOwnerBundle, @"Error alert details, substitute application and plugin version strings"), [_appBundle _dt_name], [_appBundle _dt_version], [_appBundle _dt_bundleVersion], [_bundle _dt_name], [_bundle _dt_version], [_bundle _dt_bundleVersion]];
			continue;
		}
		
		return YES;
	}
	
	return NO;
}


+ (BOOL) loadBundle:(SIMBLPlugin*)_plugin
{
	@try
	{
		NSBundle* bundle = [NSBundle bundleWithPath:[_plugin path]];
		
		// Handle common errors without spewing to the console
		NSError* err = nil;
		[bundle loadAndReturnError: &err];
		if (err) {
			switch ([err code]) {
				case NSExecutableArchitectureMismatchError:
					[self missingArch: _NSGetMachExecuteHeader()->cputype inPlugin: _plugin];
					break;
				default:
					NSLog(@"SIMBL: Can't load plugin %@: %@",
						  [_plugin _dt_name],
						  [err localizedDescription]);
			}
			return NO;
		}
		
		// getting the principalClass should force the bundle to load
		Class principalClass = [bundle principalClass];
		
		// if the principal class has an + (void) install message, call it
		if (principalClass && class_getClassMethod(principalClass, @selector(install)))
			[principalClass install];
		
		// set that we've loaded this bundle to prevent collisions
		[loadedBundleIdentifiers setObject:@"loaded" forKey:[bundle bundleIdentifier]];
		
		return YES;
	}
	@catch (NSException* exception)
	{
		[NSAlert errorAlert:NSLocalizedStringFromTableInBundle(@"SIMBL Error", SIMBLStringTable, DTOwnerBundle, @"Error alert primary message") withDetails:NSLocalizedStringFromTableInBundle(@"Failed to load the %@ plugin.\n%@", SIMBLStringTable, DTOwnerBundle, @"Error alert details, sub plugin name and error reason"), [_plugin _dt_name], [exception reason]];
	}
	
	return NO;
}

+ (void) missingArch: (NSInteger)_arch inPlugin: (SIMBLPlugin*)_plugin {
	NSLog(@"SIMBL: Can't load plugin %@ because it doesn't support the architecture \"%s\". Please contact the plugin developer for an update.",
		  [_plugin _dt_name],
		  NXGetArchInfoFromCpuType(_arch, CPU_SUBTYPE_MULTIPLE)->name
	);
}

@end

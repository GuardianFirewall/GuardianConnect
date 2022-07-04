//
//  GRDLogger.m
//  Guardian
//
//  Created by Constantin Jacob on 31.10.21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "GRDLogger.h"
#import "stdarg.h"

@interface GRDLogger ()
@end


@implementation GRDLogger

+ (NSArray<NSString *> *)allLogs {
	return [[NSUserDefaults standardUserDefaults] arrayForKey:kGRDPersistentLog];
}

+ (NSString *) allLogsFormatted {
	NSArray *allLogs = [GRDLogger allLogs];
	NSString *formattedLogString = [NSString new];
	for (NSString *log in allLogs) {
		formattedLogString = [formattedLogString stringByAppendingString:log];
	}
	return  formattedLogString;
}

+ (void)deleteAllLogs {
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kGRDPersistentLog];
	GRDLog(@"All log entries deleted!");
}

+ (void)togglePersistentLogging:(BOOL)enabled {
	GRDLog(@"Setting device diagnostic logs enabled to: %@", enabled ? @"YES" : @"NO");
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kGRDPersistentLogEnabled];
}


void zzz_GRDLog(const char *functionName, int lineNumber, BOOL preventPersistentLog, NSString *format, ...) {
	va_list vargs;
	va_start(vargs, format);
	if ([format hasSuffix:@"\n"] == NO) {
		format = [format stringByAppendingString:@"\n"];
	}
	
	NSString *formattedLog = [[NSString alloc] initWithFormat:format arguments:vargs];
	va_end(vargs);
	
	NSString *name;
	NSArray *classNameComp = [[NSString stringWithUTF8String:functionName] componentsSeparatedByString:@" "];
	NSString *classNamePlusSyntax = [classNameComp objectAtIndex:0];
	// Instance method
	if ([classNamePlusSyntax hasPrefix:@"-["]) {
		name = [[classNamePlusSyntax componentsSeparatedByString:@"-["] objectAtIndex:1];
		
	// Class method
	} else if ([classNamePlusSyntax hasPrefix:@"+["]) {
		name = [[classNamePlusSyntax componentsSeparatedByString:@"+["] objectAtIndex:1];
		
	// Safety rescue to prevent a crash
	} else {
		name = [NSString stringWithUTF8String:functionName];
	}
	
	NSDateFormatter *timestampFormatter = [[NSDateFormatter alloc] init];
	[timestampFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
	[timestampFormatter setTimeZone:[NSTimeZone systemTimeZone]];
	
	NSString *finalLog = [NSString stringWithFormat:@"%@ [%s:%d] %@", [timestampFormatter stringFromDate:[NSDate date]], [name UTF8String], lineNumber, formattedLog];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	BOOL persistentLogsEnabled = [userDefaults boolForKey:kGRDPersistentLogEnabled];
	if (persistentLogsEnabled == YES && preventPersistentLog == NO) {
		NSMutableArray *currentLogs = [NSMutableArray arrayWithArray:[userDefaults arrayForKey:kGRDPersistentLog]];
		// Never let the array grow past 200 logs
		if ([currentLogs count] > 199) {
			// The array is growing from oldest to newest since the latest
			// log entry is appended to the back not inserted at the front
			// so the first object in the array is kicked out
			[currentLogs removeObjectAtIndex:0];
		}
		[currentLogs addObject:finalLog];
		[userDefaults setObject:currentLogs forKey:kGRDPersistentLog];
	}
	
	NSLog(@"%s", [finalLog UTF8String]);
}

@end

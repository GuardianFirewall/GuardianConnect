//
//  GRDLogger.h
//  Guardian
//
//  Created by Constantin Jacob on 31.10.21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Macros to expose the various function format so that we can pickup the line numbers etc.
// For compatibility reasons and to prevent any unwanted user details ending up in our persistent logs GRDLog is not stored persistently
#define GRDLog(format, ...) zzz_GRDLog(__PRETTY_FUNCTION__, __LINE__, YES, format, ## __VA_ARGS__)
#define GRDLogg(format, ...) zzz_GRDLog(__PRETTY_FUNCTION__, __LINE__, NO, format, ## __VA_ARGS__)

#define GRDWarningLog(format, ...) zzz_GRDLog(__PRETTY_FUNCTION__, __LINE__, YES, [NSString stringWithFormat:@"[DEBUG][WARNING] %@", format], ## __VA_ARGS__)
#define GRDWarningLogg(format, ...) zzz_GRDLog(__PRETTY_FUNCTION__, __LINE__, NO, [NSString stringWithFormat:@"[WARNING] %@", format], ## __VA_ARGS__)

#define GRDErrorLog(format, ...) zzz_GRDLog(__PRETTY_FUNCTION__, __LINE__, YES, [NSString stringWithFormat:@"[DEBUG][ERROR] %@", format], ## __VA_ARGS__)
#define GRDErrorLogg(format, ...) zzz_GRDLog(__PRETTY_FUNCTION__, __LINE__, NO, [NSString stringWithFormat:@"[ERROR] %@", format], ## __VA_ARGS__)

#ifdef DEBUG
#define GRDDebugLog(format, ...) zzz_GRDLog(__PRETTY_FUNCTION__, __LINE__, YES, [NSString stringWithFormat:@"[DEBUG] %@", format], ## __VA_ARGS__)
#else
#define GRDDebugLog(format, ...) /* Doing nothing if not in debug mode */
#endif

#define LOG_SELF zzz_GRDLog(__PRETTY_FUNCTION__, __LINE__, NO, @"%@ %@", self, NSStringFromSelector(_cmd))
#define LOG_SELF_DEBUG zzz_GRDLog(__PRETTY_FUNCTION__, __LINE__, YES, @"[DEBUG] %@ %@", self, NSStringFromSelector(_cmd))


// Key definitions for these objects in NSUserDefaults
static NSString * const kGRDPersistentLog 			= @"kGRDPersistentLog";
static NSString * const kGRDPersistentLogEnabled 	= @"kGRDPersistentLogEnabled";


@interface GRDLogger : NSObject

/// Returns all recorded persistent logs (200 log lines max)
+ (NSArray <NSString *>*)allLogs;

/// Returns all recorded persistent logs (200 log lines max) already pre-formatted in a single string
/// The individual log lines are appended to a string along with a \n character
+ (NSString *)allLogsFormatted;

/// Deletes all log lines out of the NSUserDefaults
+ (void)deleteAllLogs;

/// Set the persistent log state to enable or disable persistent logging
/// Persistent logging is disabled by default and needs to enabled explicitly by calling this function once and passing YES/true
/// - Parameter enabled: indicator to enable or disable persistent logging
+ (void)togglePersistentLogging:(BOOL)enabled;

/// C function (like NSLog) that actually writes the log
void zzz_GRDLog(const char *functionName, int lineNumber, BOOL preventPersistentLog, NSString *format, ...);

@end

NS_ASSUME_NONNULL_END


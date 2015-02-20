//
//  MKCrashReporterHelper.h
//  MKCrashReporter
//
//  Created by Manju Kiran on 20/02/2015.
//  Copyright (c) 2015 Manju Kiran. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MKCrashReporterHelper : NSObject

@property BOOL crashReportComplete;

/*Method descriptions available in implementation*/

/**
 To Integrate into your app, call the following method in your AppDelegate.m's "didFinishLaunchingWithOptions" method

 [MKCrashReporterHelper  initCrashReporterWithReportingURL:reportingURLString
                                             forDeviceUUID:(NSString*)deviceUUID //Ideally you will link this with a user
                                              reportingKey:(NSString*)key
                                            additionalData:(NSDictionary*)additionalData;
 */

+ (void) initCrashReporterWithReportingURL:(NSString*)url
                             forDeviceUUID:(NSString*)deviceUUID //Ideally you will link this with a user
                              reportingKey:(NSString*)key
                            additionalData:(NSDictionary*)additionalData;
@end


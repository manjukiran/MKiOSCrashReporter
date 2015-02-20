//
//  MKCrashReporterHelper.m
//  MKCrashReporter
//
//  Created by Manju Kiran on 20/02/2015.
//  Copyright (c) 2015 Manju Kiran. All rights reserved.
//

#import "MKCrashReporterHelper.h"
#import <CrashReporter/CrashReporter.h>
#include <sys/utsname.h>

@interface MKCrashReporterHelper()

@property (strong) NSURL *reportingURL;
@property (strong) NSString *apiKey;
@property (strong) NSDictionary *additionalDataDict;
@property (strong) NSString *deviceUUID;

@end

@implementation MKCrashReporterHelper


static NSString *crashPath;
static MKCrashReporterHelper *_sharedManager = nil;
static BOOL _hasCrashReportPending;

#define kCrashFileName @"CrashReport"

#pragma mark Shared Instance

/**
 Singleton Shared Instance of App Crash Helper
 */

+ (MKCrashReporterHelper *)sharedCrashHelper {
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        if (_sharedManager == nil) {
            _sharedManager = [[self alloc] init];
            _sharedManager.crashReportComplete = NO;
            
            NSError *error;
            
            // Enable the Crash Reporter
            if (![[PLCrashReporter sharedReporter] enableCrashReporterAndReturnError:&error])
                NSLog(@"Warning: Could not enable crash reporter: %@", error);
        }
    });
    return _sharedManager;
}

+ (void) initCrashReporterWithReportingURL:(NSString*)url
                             forDeviceUUID:(NSString*)deviceUUID
                              reportingKey:(NSString*)key
                            additionalData:(NSDictionary*)additionalData{
    
    
    [[MKCrashReporterHelper sharedCrashHelper] setReportingURL:[NSURL URLWithString:url]];
    [[MKCrashReporterHelper sharedCrashHelper] setApiKey:key.length?key:nil];
    [[MKCrashReporterHelper sharedCrashHelper] setAdditionalDataDict:additionalData.allKeys.count?additionalData:nil];
    [[MKCrashReporterHelper sharedCrashHelper] setDeviceUUID:deviceUUID];
    [[MKCrashReporterHelper sharedCrashHelper]checkForCrashes];
    
    
}

//+ (BOOL)hasCrashReportPending;
//- (void)checkForCrashes;

/**
 Method to handle a pending crash report
 */
- (void)handleCrashReport {
    PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
    NSData *crashData;
    NSError *error;
    
    // Try loading the crash report
    crashData = [crashReporter loadPendingCrashReportDataAndReturnError:&error];
    if (crashData == nil) {
        NSLog(@"Could not load crash report: %@", error);
        [self finishCrashReporter:crashReporter];
        return;
    }
    
    // We could send the report from here, but we'll just print out
    // some debugging info instead
    PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
    if (report == nil) {
        NSLog(@"Could not parse crash report");
        [self finishCrashReporter:crashReporter];
        return;
    }
    
    NSLog(@"Crashed on %@", report.systemInfo.timestamp);
    NSLog(@"Crashed with signal %@ (code %@, address=0x%" PRIx64 ")", report.signalInfo.name, report.signalInfo.code, report.signalInfo.address);
    
    [self saveCrashReport:crashReporter];
    
    [self submitCrashReportWithData:crashData andReport:report];
    
    return;
}


-(NSData*) getAllInfoForCrashWithData:(NSData*)crashData andReport:(PLCrashReport*)report{
    
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    NSString *crashLog = [PLCrashReportTextFormatter stringValueForCrashReport:report withTextFormat:PLCrashReportTextFormatiOS];
    
    NSMutableDictionary *crashLogDictionary;
    
    NSString *appTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if(appTitle.length<1){
        appTitle = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleNameKey];
    }
    
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if(appVersion.length<1){
        appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
    }
    

    NSString *appBuild = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    if(appBuild.length<1){
        appBuild = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
    }
    
    crashLogDictionary = [NSMutableDictionary dictionaryWithDictionary:@{
                         @"deviceUUID":self.deviceUUID,
                         @"crashDate":[NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:report.systemInfo.timestamp]],
                         @"appTitle":appTitle,
                         @"appVersion":appVersion,
                         @"appBuild":appBuild,
                         @"deviceModel":[NSString stringWithFormat:@"%@",[UIDevice currentDevice].model],
                         @"deviceLocalizedModel":[NSString stringWithFormat:@"%@",[UIDevice currentDevice].localizedModel],
                         @"deviceName":[NSString stringWithFormat:@"%@",[UIDevice currentDevice].name],
                         @"systemVersion":[NSString stringWithFormat:@"%@",[UIDevice currentDevice].systemVersion],
                         @"batteryLevel":[NSString stringWithFormat:@"%@",[NSString stringWithFormat:@"%f",[UIDevice currentDevice].batteryLevel]],
                         @"devicePlatform":[NSString stringWithFormat:@"%@",[self getCurrentPlatform]],
                         @"crashLog":[NSString stringWithFormat:@"%@",crashLog],
                         @"signalInfo_name":[NSString stringWithFormat:@"%@ : %@",[report.exceptionInfo exceptionName], [report.exceptionInfo exceptionReason]],
                         @"signalInfo_code":[NSString stringWithFormat:@"%@",report.signalInfo.code],
                         @"signalInfo_address":[NSString stringWithFormat:@"%@",[NSString stringWithFormat:@"%llu",report.signalInfo.address]],
                         @"crashReportedDate":[NSString stringWithFormat:@"%@",[NSDate date]]
                                                                         }];
    if(self.additionalDataDict){
        [crashLogDictionary addEntriesFromDictionary:self.additionalDataDict];
    }
    
    
    
    NSData * bodyData = [NSJSONSerialization dataWithJSONObject:crashLogDictionary options:NSJSONWritingPrettyPrinted error:nil];
    return bodyData;
}


-(NSString*) getCurrentPlatform{
    
    struct utsname systemInfo;
    uname(&systemInfo);
    
    NSString *platform = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    if ([platform isEqualToString:@"iPhone1,1"])    return @"iPhone 1G";
    if ([platform isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([platform isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([platform isEqualToString:@"iPhone3,1"])    return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone3,2"])    return @"iPhone 4 CDMA";
    if ([platform isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    if ([platform isEqualToString:@"iPhone5,1"])    return @"iPhone 5";
    if ([platform isEqualToString:@"iPod1,1"])      return @"iPod Touch 1G";
    if ([platform isEqualToString:@"iPod2,1"])      return @"iPod Touch 2G";
    if ([platform isEqualToString:@"iPod3,1"])      return @"iPod Touch 3G";
    if ([platform isEqualToString:@"iPod4,1"])      return @"iPod Touch 4G";
    if ([platform isEqualToString:@"iPod5,1"])      return @"iPod Touch 5G";
    if ([platform isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([platform isEqualToString:@"iPad2,1"])      return @"iPad 2 WiFi";
    if ([platform isEqualToString:@"iPad2,2"])      return @"iPad 2 GSM";
    if ([platform isEqualToString:@"iPad2,3"])      return @"iPad 2 CDMA";
    if ([platform isEqualToString:@"iPad2,4"])      return @"iPad 2 CDMAS";
    if ([platform isEqualToString:@"iPad2,5"])      return @"iPad Mini Wifi";
    if ([platform isEqualToString:@"iPad2,6"])      return @"iPad Mini (Wi-Fi + Cellular)";
    if ([platform isEqualToString:@"iPad2,7"])      return @"iPad Mini (Wi-Fi + Cellular MM)";
    if ([platform isEqualToString:@"iPad3,1"])      return @"iPad 3 WiFi";
    if ([platform isEqualToString:@"iPad3,2"])      return @"iPad 3 CDMA";
    if ([platform isEqualToString:@"iPad3,3"])      return @"iPad 3 GSM";
    if ([platform isEqualToString:@"iPad3,4"])      return @"iPad 4 Wifi";
    if ([platform isEqualToString:@"i386"])         return @"Simulator";
    if ([platform isEqualToString:@"x86_64"])       return @"Simulator";
    return @"Unknown";
    
}


-(void)submitCrashReportWithData:(NSData*)crashData andReport:(PLCrashReport*)report{
    
    @try
    {
        
        
        NSData *postData =[self getAllInfoForCrashWithData:crashData andReport:report];
        
        if(self.apiKey.length>0){
            self.reportingURL = [NSURL URLWithString:[self.reportingURL.absoluteString stringByAppendingString:[NSString stringWithFormat:@"?key=%@",self.apiKey]]];
        }
        
        NSURL *url = self.reportingURL;
        
        NSMutableURLRequest *request = [self getMutableURLRequest:url postData:postData];
        
        
        NSURLSession *crashLogSubmissionSession = [NSURLSession sharedSession];
        NSURLSessionDataTask *crashLogSubmissionTask = [crashLogSubmissionSession dataTaskWithRequest:request completionHandler:^(NSData *data,
                                                                                                                                  NSURLResponse *response,
                                                                                                                                  NSError *error) {
            if (nil != error)
            {
                
            }
            else
            {
                NSLog(@"Crash Submission Successfull");
                [self finishCrashReporter:[PLCrashReporter sharedReporter]];
            }
        }];
        
        [crashLogSubmissionTask resume];
        
    }
    @catch (NSException * e)
    {
        NSLog(@"Crash Report Exception: %@", e);
        
    }
}


- (NSMutableURLRequest*)getMutableURLRequest:(NSURL*)url postData:(NSData*)postData
{
    if (nil != postData && nil != url)
    {
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setURL:url];
        [request setHTTPMethod:@"POST"];
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postData length]] forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:30.0];
        
        return request;
    }
    else
    {
        return (nil == url) ? [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@""]] : [NSMutableURLRequest requestWithURL:url];
    }
}

/**
 Method to purge any pending reports
 @param crashReporter:PLCrashReporter instance to be used
 */
- (void)finishCrashReporter:(PLCrashReporter *)crashReporter {
    [crashReporter purgePendingCrashReport];
    _hasCrashReportPending = false;
}

/** Method runs, if a crash report exists, make it accessible via iTunes document sharing. This is a no-op on Mac OS X.
 @param crashReporter:PLCrashReporter instance to be used
 */
- (void)saveCrashReport:(PLCrashReporter *)reporter {
    if (![reporter hasPendingCrashReport])
        return;
    
#if TARGET_OS_IPHONE
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    if (![fm createDirectoryAtPath:documentsDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"Could not create documents directory: %@", error);
        return;
    }
    
    
    NSData *data = [[PLCrashReporter sharedReporter] loadPendingCrashReportDataAndReturnError:&error];
    if (data == nil) {
        NSLog(@"Failed to load crash report data: %@", error);
        return;
    }
    
    NSString *outputPath = [documentsDirectory stringByAppendingPathComponent:kCrashFileName];
    if (![data writeToFile:outputPath atomically:YES]) {
        NSLog(@"Failed to write crash report");
        return;
    }
    
    crashPath = outputPath;
    [reporter purgePendingCrashReport];
    self.crashReportComplete = YES;
    
#endif
}


/**
 Method to check for any crashes, only call from UIApplicationDelegate
 */
- (void)checkForCrashes {

    PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
    
    // Check if we previously crashed
    _hasCrashReportPending = [crashReporter hasPendingCrashReport];
    if (_hasCrashReportPending) {
        self.crashReportComplete = NO;
        [self handleCrashReport];
    }
}

/** getter for hasCrashReportPending */
+ (BOOL)hasCrashReportPending {
    return _hasCrashReportPending;
}


@end

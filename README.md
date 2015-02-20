# MKiOSCrashReporter

A simple single line to report crashes to from iOS devices to your own server. Uses PLCrashReporter

This project is simply not possible without the folks at  [Plausible Labs Cooperative, Inc.](http://www.plausible.coop/) , who develop and maintain this gem of a framework for us developers who want to keep our crash reports away from other 3rd party servers.

Massive Thanks to Stuart Clark for introducing me to this framework and for the motivation to develop a wrapper around the PLCrashReporter framework
 
## Pre-integration:
 
 The framework has two targets to build the required framework for either 
    Production (MKiOSCrashReporter)  // or // Developement (MKCrashReporter_i386 : has simulator support)
 Build the appropriate framework and locate the .framework File
 
## To Integrate into your app
 
 Step 1 : Integrate the built appropriate framework in your project 
    ** Ensure you add the framework in the Embedded Libraries of your project. It is accessible in the General Tab of your app target
 
 Step 2 : Import "MKCrashReporter.h" in your app Delegate
 
 Step 3 : Call the following method in your AppDelegate.m's "didFinishLaunchingWithOptions" method
 
 [MKCrashReporterHelper  initCrashReporterWithReportingURL:reportingURLString
 forDeviceUUID:(NSString*)deviceUUID //Ideally you will link this with a user
 reportingKey:(NSString*)key
 additionalData:(NSDictionary*)additionalData;
 
### Thats all folks. Sit back and watch the magic unfold (unless you dont have a backend that is going to receive this data; in such case please refer to the data being uploaded section of this document to see the various values being submitted in the POST data
 

 
## Post Data:
 
 "deviceUUID"               : Remote Notification UUID of the device to link user to device
 "crashDate"                : Date of Crash
 "appTitle"                 : Title of App (if you are using the same backend for multiple apps)
 "appVersion"               : Version of App
 "appBuild"                 : Build version of the app
 "deviceModel"              : Model of the device
 "deviceLocalizedModel"     : Localized Description of the device model
 "deviceName"               : Name of Device
 "systemVersion"            : iOS Version
 "batteryLevel"             : Level of Battery
 "devicePlatform"           : Description of the device model
 "crashLog"                 : CrashLog captured by PLCrashReporter : Its better to write this Log to a file on your server and store the location of file in DB
 "signalInfo_name"          : Crash Signal Name
 "signalInfo_code"          : Crash Signal Code
 "signalInfo_address"       : Crash Signal Memory Address
 "crashReportedDate         : Date when the crash was reported
 
  Any additional data can be supplied when the framework is being initialized in the didFinishLaunchingWithOptions method in 
 "additionalData" NSDictionary


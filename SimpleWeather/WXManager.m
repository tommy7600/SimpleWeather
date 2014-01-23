//
//  WXManager.m
//  SimpleWeather
//
//  Created by Stephanie Sharp on 22/01/2014.
//  Copyright (c) 2014 RU Advertising. All rights reserved.
//

#import "WXManager.h"
#import "WXClient.h"
#import <TSMessages/TSMessage.h>

@interface WXManager ()

// Declare the same properties you added in the public interface, but this time
// declare them as readwrite so you can change the values behind the scenes.
@property (nonatomic, strong, readwrite) WXCondition *currentCondition;
@property (nonatomic, strong, readwrite) CLLocation *currentLocation;
@property (nonatomic, strong, readwrite) NSArray *hourlyForecast;
@property (nonatomic, strong, readwrite) NSArray *dailyForecast;

// Declare a few other private properties for location finding and data fetching
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, assign) BOOL isFirstUpdate;
@property (nonatomic, strong) WXClient *client;

@end

@implementation WXManager

+ (instancetype)sharedManager
{
    static id _sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc] init];
    });

    return _sharedManager;
}

- (id)init
{
    if (self = [super init])
    {
        // Creates a location manager and sets it’s delegate to self
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;

        // Creates the WXClient object for the manager. This handles all networking
        // and data parsing, following our separation of concerns best practice.
        _client = [[WXClient alloc] init];

        // The manager observes the currentLocation key on itself using a ReactiveCocoa macro
        // which returns a signal. This is similar to Key-Value Observing but is far more powerful.
        [[[[RACObserve(self, currentLocation)
            // In order to continue down the method chain, currentLocation must not be nil
            ignore:nil]
           // Flatten and subscribe to all 3 signals when currentLocation updates.
           // -flattenMap: is very similar to -map:, but instead of mapping each value,
           // it flattens the values and returns one object containing all three signals.
           // In this way, you can consider all three processes as a single unit of work.
           flattenMap:^(CLLocation *newLocation) {
               return [RACSignal merge:@[
                                         [self updateCurrentConditions],
                                         [self updateDailyForecast],
                                         [self updateHourlyForecast]
                                         ]];
               // Deliver the signal to subscribers on the main thread
           }] deliverOn:RACScheduler.mainThreadScheduler]
         // It’s not good practice to interact with the UI from inside your model,
         // but for demonstration purposes you’ll display a banner whenever an error occurs.
         subscribeError:^(NSError *error) {
             [TSMessage showNotificationWithTitle:@"Error"
                                         subtitle:@"There was a problem fetching the latest weather."
                                             type:TSMessageNotificationTypeError];
         }];
    }
    return self;
}

@end

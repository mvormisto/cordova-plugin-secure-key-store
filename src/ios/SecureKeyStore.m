/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "SecureKeyStore.h"
#import <Cordova/CDV.h>

@implementation SecureKeyStore

- (void) writeToSecureKeyStore:(NSMutableDictionary*) dict service:(NSString *) service
{
    // get keychain
    KeychainItemWrapper * keychain = [[KeychainItemWrapper alloc] initWithIdentifier:@"cordova.plugins.SecureKeyStore" service:service accessGroup:nil];
    NSString *error;
    // Serialize dictionary and store in keychain
    NSData *serializedDict = [NSPropertyListSerialization dataFromPropertyList:dict format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
    [keychain setObject:serializedDict forKey:(__bridge id)(kSecValueData)];
    if (error) {
        NSLog(@"%@", error);
    }
}

- (NSMutableDictionary *) readFromSecureKeyStore:(NSString *) service
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    // get keychain
    KeychainItemWrapper * keychain = [[KeychainItemWrapper alloc] initWithIdentifier:@"cordova.plugins.SecureKeyStore" service:service accessGroup:nil];
    NSError *error;
    @try
    {
        NSData *serializedDict = [keychain objectForKey:(__bridge id)(kSecValueData)];
        NSUInteger dictLength = [serializedDict length];
        if (dictLength) {
            // de-serialize dictionary
            dict = [NSPropertyListSerialization propertyListFromData:serializedDict mutabilityOption:NSPropertyListImmutable format:nil errorDescription:&error];
            if (error) {
                NSLog(@"Read process Exception: %@", error);
            }
        }
    }
    @catch (NSException * exception)
    {
        NSLog(@"Read exception: %@", exception);
    }
    return [dict mutableCopy];
}

- (BOOL) removeKeyFromSecureKeyStore:(NSString*) key service:(NSString *) service
{
    @try
    {
        // get mutable dictionary and remove key from store
        NSMutableDictionary *dict = [self readFromSecureKeyStore:service];
        [dict removeObjectForKey:key];
        [self writeToSecureKeyStore:dict service:service];
        return YES;
    }
    @catch (NSException * exception)
    {
        NSLog(@"Remove exception: %@", exception.reason);
        return NO;
    }
}

- (void) resetSecureKeyStore:(NSString *) service
{
    [[[KeychainItemWrapper alloc] initWithIdentifier:@"cordova.plugins.SecureKeyStore" service:service accessGroup:nil] resetKeychainItem];
}

- (void)handleAppUninstallation:(NSString *) service
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"RnSksIsAppInstalled"]) {
        [self resetSecureKeyStore: service];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"RnSksIsAppInstalled"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void) set:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* service = [command.arguments objectAtIndex:0];
    NSString* key = [command.arguments objectAtIndex:1];
    NSString* value = [command.arguments objectAtIndex:2];

    @try {
        // handle app uninstallation
        [self handleAppUninstallation:service];
        // get mutable dictionary and store data
        [self.commandDelegate runInBackground:^{
            @synchronized(self) {
                @try {
                    NSMutableDictionary *dict = [self readFromSecureKeyStore:service];
                    [dict setValue: value forKey: key];
                    [self writeToSecureKeyStore:dict service:service];

                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"key saved successfully"];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }
                @catch (NSException* exception)
                {
                    NSString* errorMessage = [NSString stringWithFormat:@"{\"code\":9,\"message\":\"error saving key, please try to un-install and re-install app again\",\"actual-error\":%@}", exception];
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }
            }
        }];
    }
    @catch (NSException* exception)
    {
        NSString* errorMessage = [NSString stringWithFormat:@"{\"code\":9,\"message\":\"error saving key\",\"actual-error\":%@}", exception];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) get:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* service = [command.arguments objectAtIndex:0];
    NSString* key = [command.arguments objectAtIndex:1];

    @try {
        // handle app uninstallation
        [self handleAppUninstallation:service];
        [self.commandDelegate runInBackground:^{
            @synchronized(self) {
                // get mutable dictionaly and retrieve store data
                NSMutableDictionary *dict = [self readFromSecureKeyStore:service];
                NSString *value = nil;

                if (dict != nil) {
                    value =[dict valueForKey:key];
                }

                if (value != nil) {
                    value =[dict valueForKey:key];
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:value];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                } else {
                    NSString* errorMessage = @"{\"code\":1,\"message\":\"key does not exist\"}";
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }
            }
        }];
    }
    @catch (NSException* exception)
    {
        NSString* errorMessage = [NSString stringWithFormat:@"{\"code\":1,\"message\":\"key does not exist\",\"actual-error\":%@}", exception];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) remove:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* service = [command.arguments objectAtIndex:0];
    NSString* key = [command.arguments objectAtIndex:1];
    @try {
        // handle app uninstallation
        [self handleAppUninstallation:service];
        [self.commandDelegate runInBackground:^{
            @synchronized(self) {
                BOOL status = [self removeKeyFromSecureKeyStore:key service:service];
                if (status) {
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Key removed successfully"];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                } else {
                    NSString* errorMessage = @"{\"code\":6,\"message\":\"could not delete key\"}";
                    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }
            }
        }];
    }
    @catch(NSException *exception) {
        NSString* errorMessage = [NSString stringWithFormat:@"{\"code\":6,\"message\":\"could not delete key\",\"actual-error\":%@}", exception];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

@end

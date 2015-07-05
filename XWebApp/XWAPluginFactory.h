/*
 Copyright 2015 XWebView

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

#ifndef XWebApp_XWAPluginFactory_h
#define XWebApp_XWAPluginFactory_h

@protocol XWAPluginFactory

+ (id __nullable)createInstance;

@optional
+ (id __nullable)createInstanceWithArgument:(id __nullable)argument;

@end

@protocol XWAPluginSingleton

+ (id __nullable)instance;

@optional
+ (NSString * __nullable)channelName;
+ (BOOL)stickOnMainThread;

@end

#endif

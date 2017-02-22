//
//  WebServiceClient.m
//  WebService
//
//  Created by Siva RamaKrishna Ravuri
//  Copyright (c) 2014 www.siva4u.com. All rights reserved.
//
// The MIT License (MIT)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

#import <objc/runtime.h>
#import "WebServiceClient.h"

@interface WebServiceClient ()
@property(nonatomic,assign) id delegate;
@property(nonatomic,retain) DownloadClient	*dcRequest;
@property(nonatomic,retain) DMWebservice	*wscDataModel;
@end

@implementation WebServiceClient

@synthesize delegate;
@synthesize dcRequest;
@synthesize wscDataModel;

#pragma mark - De-Allocs

-(void) releaseMem {
    RELEASE_MEM(dcRequest);
}

-(void) dealloc {
    [self releaseMem];
#if !(__has_feature(objc_arc))
    [super dealloc];
#endif
}

#pragma mark - Local APIs

-(void) callDelegateWithStatus:(WS_STATUS)status response:(DMWebservice *)response {
	if((self.delegate) && ([delegate respondsToSelector:@selector(webServiceClient: response:)])) {
		response.status = status;
		[delegate webServiceClient:self response:response];
	}
}
-(char *)getClassNameFromVar:(Ivar)var {
    if(var) {
        const char* className = ivar_getTypeEncoding(var);
        if(className) {
	        unsigned long strLen = strlen(className);
    	    if(strLen > 3) {
                unsigned long actualStrLen = strLen - 3;
        	    char* returnString = calloc(actualStrLen+1,1);
            	memcpy(returnString, className+2, actualStrLen);
	            returnString[actualStrLen] = 0;
    	        return returnString;
        	}
        }
    }
    return nil;
}

-(Ivar) getIvarWithName:(const char *)name fromIvars:(Ivar *)vars varCount:(unsigned int)varCount {
    unsigned int index = 0;
    while(index < varCount) {
        Ivar var = vars[index];
        const char* varName = ivar_getName(var);
        if(strcmp(name, varName) == 0) return var;
        index++;
    }
    return nil;
}

-(id)encodeFromDataModel:(id)dataModel {
    if(([dataModel isKindOfClass:[NSArray class]]) || ([dataModel isKindOfClass:[NSMutableArray class]])) {
        NSMutableArray *postArray = [[NSMutableArray alloc]init];
        if(postArray) {
            NSArray *arrayObject = (NSArray *)dataModel;
            for (id singleItem in arrayObject) {
                [postArray addObject:[self encodeFromDataModel:singleItem]];
            }
        }
        return postArray;
    } else {
        NSMutableDictionary *postData = [[NSMutableDictionary alloc]init];
        unsigned int varCount;
        unsigned int subVarCount;
        Ivar *vars = class_copyIvarList([dataModel class], &varCount);
        NSArray *dmDefines = [self allPropertyNames:dataModel];
        NSDictionary *mapping = [self getMappingFromDataModel:dataModel];
        for (NSString *propName in dmDefines) {
            if(propName) {
                NSString *arrayType=nil;
                NSString *jsonKey = propName;
                if(mapping) {
                    id mapKey = [mapping objectForKey:propName];
                    if(mapKey) {
                        if([mapKey isKindOfClass:[NSDictionary class]]) {
                            arrayType = [mapKey objectForKey:DM_DEFINE_PROP_TYPE];
                            mapKey = [mapKey objectForKey:DM_DEFINE_PROP_NAME];
                            if(mapKey) {
                                jsonKey = [NSString stringWithString:mapKey];
                            }
                        } else {
                            jsonKey = [NSString stringWithString:mapKey];
                        }
                    }
                }
                Ivar var = [self getIvarWithName:[propName cStringUsingEncoding:NSUTF8StringEncoding] fromIvars:vars varCount:varCount];
                if(var) {
                    char *className = [self getClassNameFromVar:var];
                    id object = object_getIvar(dataModel,var);
                    if(object) {
                        NSString *classNameNSStr = [NSString stringWithUTF8String:className];
                        if([classNameNSStr rangeOfString:@"Array"].location != NSNotFound) {
                            NSMutableArray *postArray = [[NSMutableArray alloc]init];
                            if(postArray) {
                                NSArray *arrayObject = (NSArray *)object;
                                for (id singleItem in arrayObject) {
                                    [postArray addObject:[self encodeFromDataModel:singleItem]];
                                }
                                [postData setObject:postArray forKey:jsonKey];
                            }
                        } else {
                            Ivar *subVars = class_copyIvarList([objc_getClass(className) class], &subVarCount);
                            if(subVarCount > 0) {
                                [postData setObject:[self encodeFromDataModel:object] forKey:jsonKey];
                            } else {
                                [postData setObject:object forKey:jsonKey];
                            }
                            free(subVars);
                        }
                    }
                    free(className);
                }
            }
        }
        free(vars);
        return postData;
    }
    return nil;
}

-(NSArray *)allPropertyNames:(id)owner {
    unsigned count;
    objc_property_t *properties = class_copyPropertyList([owner class], &count);
    NSMutableArray *rv = [NSMutableArray array];
    unsigned i;
    for (i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        NSString *name = [NSString stringWithUTF8String:property_getName(property)];
        [rv addObject:name];
    }
    free(properties);
    return rv;
}

-(NSDictionary *)getMappingFromDataModel:(id)dataModel {
    Class dataModelCls = [dataModel class];
    SEL sel = NSSelectorFromString(DM_DEFINE_PROP_MAP);
    NSDictionary *mapping = nil;
    if([dataModelCls respondsToSelector:sel]) {
        mapping = [dataModelCls performSelector:sel];
    }
    return mapping;
}

-(void)decodeToDataModel:(id)dataModel jsonData:(NSDictionary *)jsonData {
    unsigned int varCount;
    Ivar *vars = class_copyIvarList([dataModel class], &varCount);
    NSArray *dmDefines = [self allPropertyNames:dataModel];
    NSDictionary *mapping = [self getMappingFromDataModel:dataModel];
    for (NSString *propName in dmDefines) {
        if(propName) {
            NSString *arrayType=nil;
            NSString *jsonKey = propName;
            if(mapping) {
                id mapKey = [mapping objectForKey:propName];
                if(mapKey) {
                    if([mapKey isKindOfClass:[NSDictionary class]]) {
                        arrayType = [mapKey objectForKey:DM_DEFINE_PROP_TYPE];
                        mapKey = [mapKey objectForKey:DM_DEFINE_PROP_NAME];
                        if(mapKey) {
                            jsonKey = [NSString stringWithString:mapKey];
                        }
                    } else {
                        jsonKey = [NSString stringWithString:mapKey];
                    }
                }
            }
            id responseData = [jsonData objectForKey:jsonKey];
            if(responseData) {
                Ivar var = [self getIvarWithName:[propName cStringUsingEncoding:NSUTF8StringEncoding] fromIvars:vars varCount:varCount];
                if(var) {
                    id propValue = nil;
                    if([responseData isKindOfClass:[NSDictionary class]]) {
                        char *className = [self getClassNameFromVar:var];
                        if(className) {
                            NSString *classNameNSString = [NSString stringWithUTF8String:className];
                            free(className);
                            propValue = [[NSClassFromString(classNameNSString) alloc]init];
                            [self decodeToDataModel:propValue jsonData:responseData];
                        }
                    } else if([responseData isKindOfClass:[NSArray class]]) {
                        if(arrayType) {
                            NSMutableArray *returnArray = [[NSMutableArray alloc]init];
                            NSArray *jsonArray = (NSArray *)responseData;
                            for(id localJsonData in jsonArray) {
                                id returnObject = [[NSClassFromString(arrayType) alloc]init];
                                [self decodeToDataModel:returnObject jsonData:localJsonData];
                                [returnArray addObject:returnObject];
                            }
                            propValue = returnArray;
                        }
                    } else {
                        // Basic Value and is assigned directly
                        propValue = responseData;
                    }
                    if(propValue) {
                        object_setIvar(dataModel, var, propValue);
                    }
                }
            }

        }
    }
    free(vars);
}

-(void)validateAndUpdateHttpMethod {
    NSString *httpMethod = [wscDataModel.httpMethod uppercaseString];
    if(httpMethod == nil) httpMethod = HTTP_REQUEST_METHOD_GET;
    wscDataModel.httpMethod = httpMethod;
}

#pragma mark - Public APIs

-(id)initWithDelegate:(id)wscDelegate {
    self = [super init];
    if (self) {
        // Custom initialization
        [self releaseMem];
        self.delegate = wscDelegate;
    }
    return self;
}

-(void)sendRequest:(DMWebservice *)dataModel {
    wscDataModel = dataModel;
    dcRequest = [[DownloadClient alloc]initWithDelegate:self];
    if (dcRequest) {
        [dcRequest setHeaderOptions:wscDataModel.httpHeaders];
        [self validateAndUpdateHttpMethod];
        NSData *postData = nil;
        if(![wscDataModel.httpMethod isEqualToString:HTTP_REQUEST_METHOD_GET]) {
            id postDataDefinition = [self encodeFromDataModel:wscDataModel.requestDM];
            if(postDataDefinition) {
                NSError *error;
                postData = [NSJSONSerialization dataWithJSONObject:postDataDefinition
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error];
                if(error) AppLog(APP_LOG_ERR,@"Error:%@\n",[error localizedDescription]);
            }
        }
        [dcRequest startDownloadWithUrl:wscDataModel.url httpMethod:wscDataModel.httpMethod data:postData];
    } else {
        wscDataModel.errorMsg = WS_RSP_MSG_CONNECTION_ERROR;
        [self callDelegateWithStatus:WS_STATUS_FAIL response:wscDataModel];
    }
}

- (void) cancelRequest {
    RELEASE_MEM(dcRequest);
    NSLog(@"Request cancelled!!");
}


#pragma - Download Client delegate methods

-(void)downloadClient:(DownloadClient *)downloadClient data:(NSData *)data dataModel:(DownloadClientDM *)dataModel {
    EnumDownloadClientStatus status = dataModel.status;
    if (status == EnumDownloadClientStatusCompleted) {
        wscDataModel.responseCode = dataModel.statusCode;
        if (data) {
            NSError *error;
            id jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONWritingPrettyPrinted error:&error];
            if(error) AppLog(APP_LOG_ERR,@"Error:%@\n",[error localizedDescription]);
            if(jsonData) {
                [self decodeToDataModel:wscDataModel.responseDM jsonData:jsonData];
                AppLog(APP_LOG_INFO,@"DataModel:%@\n",wscDataModel.responseDM);
            }
        }
        [self callDelegateWithStatus:WS_STATUS_SUCCESS response:wscDataModel];
    } else if(status == EnumDownloadClientStatusFail) {
        [self callDelegateWithStatus:WS_STATUS_FAIL response:nil];
    } else if(status == EnumDownloadClientStatusTimeOut) {
        [self callDelegateWithStatus:WS_STATUS_TIMEOUT response:nil];
    } else if(status == EnumDownloadClientStatusNoNetwork) {
        [self callDelegateWithStatus:WS_STATUS_NO_NETWORK response:nil];
    }
}

@end

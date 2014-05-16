//
//  SQLiteUploader.h
//  SQLiteUploader
//
//  Created by Armand Van der Walt on 2014/05/16.
//  Copyright (c) 2014 Yotta. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SQLiteUploadDelegate <NSObject>

@optional

- (void) didFinishUpload:(NSData *)data;
- (void) didFailWithError:(NSError *)error;

@end

@interface SQLiteUploader : NSObject

{
    NSString *sqliteLocationPath;
    NSURL* serverUrl;
    NSMutableArray* sqlFiles;
}

-(id) initWithSqliteLocationPath:(NSString*)path andServerUrl:(NSURL*)url;
-(void) upload;

@property (nonatomic, weak) id <SQLiteUploadDelegate> delegate;

@end

//
//  SQLiteUploader.m
//  SQLiteUploader
//
//  Created by Armand Van der Walt on 2014/05/16.
//  Copyright (c) 2014 Yotta. All rights reserved.
//

#import "SQLiteUploader.h"
#import "ZipArchive.h"

@implementation SQLiteUploader {
    struct {
        unsigned int didFinishUpload:1;
        unsigned int didFailWithError:1;
    } delegateRespondsTo;
}

-(id) initWithSqliteLocationPath:(NSString *)path andServerUrl:(NSURL *)url
{
    self = [super init];
    if(self) {
        sqliteLocationPath = path;
        serverUrl = url;
        sqlFiles = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)setDelegate:(id <SQLiteUploadDelegate>)aDelegate {
    if (_delegate != aDelegate) {
        _delegate = aDelegate;
        
        delegateRespondsTo.didFinishUpload = [_delegate respondsToSelector:@selector(didFinishUpload:)];
        delegateRespondsTo.didFailWithError = [_delegate respondsToSelector:@selector(didFailWithError:)];
    }
}

-(BOOL) checkExtension:(NSString*) fileName
{
    NSRange isRange = [[@"sqlite" lowercaseString] rangeOfString:fileName options:NSCaseInsensitiveSearch];
    if(isRange.location == 0) {
        return YES;
    } else {
        NSRange isSpacedRange = [[@"sqlite" lowercaseString] rangeOfString:fileName options:NSCaseInsensitiveSearch];
        if(isSpacedRange.location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

- (BOOL) createZipFile: (NSString**) archivePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString *docDirectory = [paths objectAtIndex:0];
    
    BOOL isDir = NO;
    
    NSArray *subpaths;
    
    NSString *exportPath = docDirectory;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:exportPath isDirectory:&isDir] && isDir){
        subpaths = [fileManager subpathsAtPath:sqliteLocationPath];
    }
    
    *archivePath = [docDirectory stringByAppendingString:@".zip"];
    
    ZipArchive *archiver = [[ZipArchive alloc] init];
    
    [archiver CreateZipFile2:*archivePath];
    
    for(NSString *path in subpaths)
    {
        if([self checkExtension:path])
        {
            NSString *longPath = [exportPath stringByAppendingPathComponent:path];
            if([fileManager fileExistsAtPath:longPath isDirectory:&isDir] && !isDir)
            {
                [archiver addFileToZip:longPath newname:path];
            }
        }
    }
    
    return [archiver CloseZipFile2];
}

- (void)upload
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *archivePath = @"";
        if([self createZipFile:&archivePath])
        {
            NSData *fileData = [NSData dataWithContentsOfFile:archivePath];
            
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc]
                                            initWithURL:serverUrl];
            
            [request setTimeoutInterval:30.0];
            
            [request setHTTPMethod:@"POST"];
            
            NSString *boundary = @"780808070779786865757";
            
            /* Header */
            NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
            [request addValue:contentType forHTTPHeaderField:@"Content-Type"];
            
            /* Body */
            NSMutableData *postData = [NSMutableData data];
            
            [postData appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            
            [postData appendData:[[NSString stringWithFormat:@"Content-Disposition:form-data; name=\"file\"; filename=\"database.zip\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
            
            [postData appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            
            [postData appendData:fileData];
            
            [postData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            
            [request setHTTPBody:postData];
            
            NSURLResponse *response;
            NSError *error = nil;
            NSData *receivedData  = [NSURLConnection sendSynchronousRequest:request
                                                          returningResponse:&response
                                                                      error:&error];
            
            if(error)
            {
                [self performSelectorOnMainThread:@selector(uploadFailed:) withObject:error waitUntilDone:NO];
            }
            else
            {
                
                [self performSelectorOnMainThread:@selector(doneUpload:) withObject:receivedData waitUntilDone:NO];
            }
        }
    });
}

-(void) uploadFailed: (NSError*) error
{
    if(delegateRespondsTo.didFailWithError)
    {
        [_delegate didFailWithError:error];
    }
}

-(void) doneUpload:(NSData*) data
{
    if(delegateRespondsTo.didFinishUpload)
    {
        [_delegate didFinishUpload:data];
    }
}

@end




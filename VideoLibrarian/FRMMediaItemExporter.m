//
//  FRMAssetExporter.m
//  VideoLibrarian
//
//  Created by Friedrich Markgraf on 25.06.16.
//  Copyright © 2016 Friedrich Markgraf. All rights reserved.
//

#import "FRMMediaItemExporter.h"
#import <MediaPlayer/MPMediaItem.h>
#import <AVFoundation/AVFoundation.h>


@interface FRMMediaItemExporter()
@property (nonatomic, strong, readwrite) MPMediaItem *mediaItem;
@property (nonatomic, strong, readwrite) NSURL *outputURL;
@property (atomic) BOOL isExporting;
@end


@implementation FRMMediaItemExporter


- (instancetype)initWithMediaItem:(MPMediaItem *)mediaItem
{
    self = [super init];
    self.mediaItem = mediaItem;
    return self;
}


- (BOOL)isExportable
{
    return [self.mediaItem valueForProperty:MPMediaItemPropertyAssetURL] != nil;
}


- (void)exportToURL:(NSURL *)URL
    completionBlock:(FRMMediaItemExporterCompletionBlock)completionBlock
{
    NSAssert(!self.isExporting, @"can not run multiple exports concurrently");
    self.isExporting = YES;
    
    NSURL *assetURL = [self.mediaItem valueForProperty:MPMediaItemPropertyAssetURL];
    AVURLAsset *asset = [AVURLAsset assetWithURL:assetURL];
    if (!asset) {
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                             code:NSURLErrorFileDoesNotExist
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Failed to instantiate AVAsset from MediaItem asset URL",
                                                     NSURLErrorKey: assetURL ?: [NSNull null] }];
        self.isExporting = NO;
        self.outputURL = nil;
        completionBlock(self, NO, error);
        return;
    }

    [asset loadValuesAsynchronouslyForKeys:@[ @"tracks" ] completionHandler:^{
        if ([asset statusOfValueForKey:@"tracks" error:nil] != AVKeyValueStatusLoaded) {
            //found no tracks
            NSError *error = [NSError errorWithDomain:AVFoundationErrorDomain
                                                 code:AVErrorIncompatibleAsset
                                             userInfo:@{ NSLocalizedDescriptionKey: @"Unable to load asset tracks" }];
            self.isExporting = NO;
            self.outputURL = nil;
            completionBlock(self, NO, error);
            return;
        }
        
        BOOL isVideo = NO;
        for (AVAssetTrack *track in asset.tracks) {
            if ([track.mediaType isEqualToString:AVMediaTypeVideo]) {
                isVideo = YES;
                break;
            }
        }
        
        // I'm not sure this assumption always holds
        NSString *extension = isVideo ? @"m4v" : @"m4a";
        self.outputURL = URL.pathExtension ? URL : [URL URLByAppendingPathExtension:extension];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.outputURL.path]) {
            [[NSFileManager defaultManager] removeItemAtPath:self.outputURL.path error:NULL];
        }
        
        // NOTE: Even though compatiblePresets does not contain AVAssetExportPresetPassthrough, that still seems to work.
        NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
        NSLog(@"Compatible presets: %@", compatiblePresets);
        
        NSString *presetName = AVAssetExportPresetPassthrough;
        
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset
                                                                               presetName:presetName];
        exportSession.outputURL = self.outputURL;

        [exportSession determineCompatibleFileTypesWithCompletionHandler:^(NSArray *compatibleFileTypes) {
            // It may be possible to infer a better file extension and output file type from this.
            NSLog(@"compatible file types:\n%@", compatibleFileTypes);
            exportSession.outputFileType = isVideo ? AVFileTypeMPEG4 : AVFileTypeAppleM4A;
            
            // Export.
            // NOTE: Export typically takes several seconds. It is possible to query progress during export to display a progress bar.
            // I did not do that in this example because it would obscure the important parts even more.
            [exportSession exportAsynchronouslyWithCompletionHandler:^{
                if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                    self.isExporting = NO;
                    self.outputURL = nil;
                    completionBlock(self, YES, NULL);
                }
                else if (exportSession.status == AVAssetExportSessionStatusCancelled ||
                         exportSession.status == AVAssetExportSessionStatusFailed) {
                    self.isExporting = NO;
                    self.outputURL = nil;
                    completionBlock(self, NO, exportSession.error);
                }
            }];
        }];
    }];

}

@end

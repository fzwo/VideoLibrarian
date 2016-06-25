//
//  FRMAssetExporter.h
//  VideoLibrarian
//
//  Created by Friedrich Markgraf on 25.06.16.
//  Copyright © 2016 Friedrich Markgraf. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MPMediaItem;
@class FRMMediaItemExporter;

typedef void (^FRMMediaItemExporterProgressBlock)(FRMMediaItemExporter *exporter, float progress);
typedef void (^FRMMediaItemExporterCompletionBlock)(FRMMediaItemExporter *exporter, BOOL success, NSError *error);

@interface FRMMediaItemExporter : NSObject

@property (nonatomic, readonly) MPMediaItem *mediaItem;
@property (nonatomic, readonly) NSURL *outputURL;

/**
 * Fast check if item is exportable at all.
 *
 * @warning *important:*
 *   A TRUE return value does not guarantee export will be successful. A NO return value does guarantee it will fail, however.
 * @return
 *   TRUE if the media item is exportable as a file, NO if it isn't.
 */
@property (nonatomic, readonly) BOOL isExportable;

- (instancetype)init __attribute__((unavailable("Use initWithMediaItem: instead.")));
- (instancetype)initWithMediaItem:(MPMediaItem *)mediaItem;

/**
 * Asynchronously export mediaItem to specified URL.
 *
 * @warning *important:*
 *   Only one export can run from each exporter instance at a time.
 * @warning *important:*
 *   Ensure that the exporter is not deallocated while an export is running.
 * @param URL
 *   The URL of the file to be created. If the URL does not contain an extension, a fitting one is automatically appended.
 * @param completionBlock
 *   Called when export finishes successfully or fails.
 */
- (void)exportToURL:(NSURL *)URL

    completionBlock:(FRMMediaItemExporterCompletionBlock)completionBlock;

@end

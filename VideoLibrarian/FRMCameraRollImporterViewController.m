//
//  SecondViewController.m
//  VideoLibrarian
//
//  Created by Friedrich Markgraf on 25.06.16.
//  Copyright © 2016 Friedrich Markgraf. All rights reserved.
//

#import "FRMCameraRollImporterViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface FRMCameraRollImporterViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;
#pragma clang diagnostic pop
@end

@implementation FRMCameraRollImporterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)showVideoPicker:(id)sender
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.mediaTypes = @[ (NSString *)kUTTypeMovie ];
    picker.videoQuality = UIImagePickerControllerQualityTypeHigh; //original quality
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:NULL];
}


#pragma mark - UIImagePickerControllerDelegate Methods

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    NSLog(@"Info: %@", info);
    NSURL *assetURL = info[UIImagePickerControllerReferenceURL];
    if (assetURL) {
        // NOTE: This method works with the old ALAssetsLibrary framework for backward compatibility.
        // On iOS 9 and newer, this should be much, much easier with PHAssetResourceManager (but I haven't tried that)
        if (!self.assetsLibrary) {
            self.assetsLibrary = [[ALAssetsLibrary alloc] init];
        }
        [self.assetsLibrary assetForURL:assetURL
                            resultBlock:^(ALAsset *asset) {
                                __autoreleasing NSError *error;
                                __block ALAssetRepresentation *representation = asset.defaultRepresentation;
                                
                                //determine file extension
                                CFStringRef extensionCFString = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)(representation.UTI), kUTTagClassFilenameExtension);
                                NSString *extension = CFBridgingRelease(extensionCFString);
                                
                                //create target file
                                NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
                                NSURL *URL = [[documentsDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"%lf", [NSDate date].timeIntervalSince1970]] URLByAppendingPathExtension:extension];
                                [[NSFileManager defaultManager] createFileAtPath:URL.path contents:nil attributes:nil];
                                NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:URL error:&error];
                                if (error) {
                                    NSLog(@"could not create file handle for URL %@: %@", URL, error);
                                    [self dismissViewControllerAnimated:YES completion:NULL];
                                    return;
                                }
                                
                                dispatch_async(dispatch_get_main_queue(), ^(void){
                                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Exporting… vh vcc"
                                                                                                   message:nil
                                                                                            preferredStyle:UIAlertControllerStyleAlert];
                                    [picker presentViewController:alert animated:YES completion:NULL];
                                });

                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                    //bytewise copy original data
                                    long long size = representation.size;
                                    
                                    __autoreleasing NSError *copyError;
                                    long long copiedBytes = 0;
                                    int16_t chunkSize = 1024;
                                    while (copiedBytes < size) {
                                        Byte *buffer = (Byte*)malloc(chunkSize);
                                        int16_t length = MIN(chunkSize, size - copiedBytes);
                                        [representation getBytes:buffer fromOffset:copiedBytes length:length error:&copyError];
                                        
                                        if (copyError) {
                                            free(buffer);
                                            NSLog(@"error copying bytes: %@", copyError);
                                            [self dismissViewControllerAnimated:YES completion:NULL];
                                            return;
                                        }
                                        NSData *assetData = [NSData dataWithBytesNoCopy:buffer length:length freeWhenDone:YES];
                                        
                                        [fileHandle writeData:assetData];
                                        [fileHandle seekToEndOfFile];
                                        copiedBytes += length;
                                    }
                                    [fileHandle closeFile];
                                    NSLog(@"Copied %lld of %lld bytes", copiedBytes, size);
                                    dispatch_async(dispatch_get_main_queue(), ^(void){
                                        NSString *message = [NSString stringWithFormat:@"File exported to\n%@", URL.lastPathComponent];
                                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Export Successful"
                                                                                                       message:message
                                                                                                preferredStyle:UIAlertControllerStyleAlert];
                                        UIAlertAction *OKButtonAction = [UIAlertAction actionWithTitle:@"OK"
                                                                                                 style:UIAlertActionStyleDefault
                                                                                               handler:^(UIAlertAction * _Nonnull action) {
                                                                                                   [self dismissViewControllerAnimated:YES completion:NULL];
                                                                                               }];
                                        [alert addAction:OKButtonAction];
                                        [self dismissViewControllerAnimated:YES completion:^{
                                            [self presentViewController:alert animated:YES completion:NULL];
                                        }];
                                    });
                                });
                            }
                           failureBlock:^(NSError *error) {
                               NSLog(@"could not get asset for picked media: %@", error);
                               [self dismissViewControllerAnimated:YES completion:NULL];
                           }];
    }
    
}
#pragma clang diagnostic pop

@end

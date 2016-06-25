//
//  FRMMoviePickerViewController.m
//  VideoLibrarian
//
//  Created by Friedrich Markgraf on 25.06.16.
//  Copyright © 2016 Friedrich Markgraf. All rights reserved.
//

#import "FRMMoviePickerViewController.h"
#import "FRMMediaItemExporter.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@interface FRMMoviePickerViewController ()
@property (nonatomic, strong) MPMediaLibrary *library;
@property (nonatomic, strong) MPMediaQuery *query;
@property (nonatomic, strong) NSMutableSet *exporters;
@end

static NSString *cellIdentifier = @"FRMMovieCell";

@implementation FRMMoviePickerViewController

- (void)loadView
{
    self.exporters = [NSMutableSet new];
    [self loadMediaLibrary];
    [super loadView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadMediaLibrary
{
    self.library = [MPMediaLibrary defaultMediaLibrary];
    
    MPMediaPropertyPredicate *predicate = [MPMediaPropertyPredicate predicateWithValue:@(MPMediaTypeAnyVideo)
                                                                           forProperty:MPMediaItemPropertyMediaType];
    self.query = [[MPMediaQuery alloc] initWithFilterPredicates:[NSSet setWithObject:predicate]];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSArray *sections = self.query.collectionSections;
    return sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    MPMediaQuerySection *querySection = self.query.collectionSections[section];
    return querySection.range.length;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [self.query.collectionSections[section] title];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    MPMediaQuerySection *querySection = self.query.collectionSections[indexPath.section];
    MPMediaItem *item = self.query.items[querySection.range.location + indexPath.row];
    
    BOOL loadable = [item valueForProperty:MPMediaItemPropertyAssetURL] != nil;
    
    NSString *title = [item valueForProperty:MPMediaItemPropertyTitle];
    cell.textLabel.text = title ?: @"Unnamed Movie";
    
    if (loadable) {
        cell.textLabel.textColor = [UIColor blackColor];
        NSString *artist = [item valueForProperty:MPMediaItemPropertyArtist];
        cell.detailTextLabel.text = artist ?: @"Unknown Artist";
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
    else {
        cell.textLabel.textColor = [UIColor lightGrayColor];
        cell.detailTextLabel.text = @"Not Loadable";
        cell.detailTextLabel.textColor = [[UIColor redColor] colorWithAlphaComponent:0.4];
    }
    
    MPMediaItemArtwork *artwork = [item valueForProperty:MPMediaItemPropertyArtwork];
    UIImage *coverImage = nil;
    if (artwork) {
        coverImage = [artwork imageWithSize:CGSizeMake(1.0, 60.0)];
    }
    cell.imageView.image = coverImage;
    cell.imageView.alpha = loadable ? 1.0 : 0.2;
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60.0;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MPMediaQuerySection *section = self.query.collectionSections[indexPath.section];
    MPMediaItem *item = self.query.items[section.range.location + indexPath.row];
    FRMMediaItemExporter *exporter = [[FRMMediaItemExporter alloc] initWithMediaItem:item];
    [self.exporters addObject:exporter];
   
    NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    UITableViewCell *currentCell = [self.tableView cellForRowAtIndexPath:indexPath];
    NSURL *URL = [documentsDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@ - %@", currentCell.detailTextLabel.text, currentCell.textLabel.text]];
    UIAlertController *exportingAlert = [UIAlertController alertControllerWithTitle:@"Exporting..."
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:exportingAlert animated:YES completion:NULL];

    [exporter exportToURL:URL
          completionBlock:^(FRMMediaItemExporter *exporter, BOOL success, NSError *error) {
              dispatch_async(dispatch_get_main_queue(), ^{
                  NSString *title;
                  NSString *message;
                  if (success) {
                      title = @"Export successful";
                      message = [NSString stringWithFormat:@"File exported to\n%@", URL.lastPathComponent];
                  }
                  else {
                      title = @"Export failed";
                      message = error.localizedDescription;
                  }
                  UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
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
                      [self.exporters removeObject:exporter];
                      [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
                  }];
              });
          }];
}


@end

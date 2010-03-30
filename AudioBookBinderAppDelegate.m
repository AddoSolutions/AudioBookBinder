//
//  AudioBookBinderAppDelegate.m
//  AudioBookBinder
//
//  Created by Oleksandr Tymoshenko on 10-02-04.
//  Copyright 2010 Bluezbox Software. All rights reserved.
//

#import "AudioBookBinderAppDelegate.h"
#import "AudioFile.h"
#import "MP4File.h"
#import "ExpandedPathToPathTransformer.h"
#import "ExpandedPathToIconTransformer.h"

enum abb_form_fields {
	ABBAuthor = 0,
	ABBTitle,
};

@implementation AudioBookBinderAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	fileList = [[[AudioFileList alloc] init] retain];
	[fileListView setDataSource:fileList];
	[fileListView setDelegate:fileList];
	[fileListView setAllowsMultipleSelection:YES];
	
	[fileListView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];
	[fileListView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
	// [fileListView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
	[fileListView setAutoresizesOutlineColumn:NO];
	
	_binder = [[[AudioBinder alloc] init] retain];
	[_binder setDelegate:self];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *appDefaults = [NSMutableDictionary
								 dictionaryWithObject:[NSNumber numberWithInt:1] forKey:@"Channels"];
	[appDefaults setObject:@"YES" forKey:@"AddToiTunes"];
	[appDefaults setObject:@"44100" forKey:@"SampleRateIndex"];
	NSString *homePath = NSHomeDirectory();
	[appDefaults setObject:homePath forKey:@"DestinationFolder"];
	[appDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"DestinationiTunes"];
	
	[defaults registerDefaults:appDefaults];
	
	//set custom value transformers	
	ExpandedPathToPathTransformer * pathTransformer = [[[ExpandedPathToPathTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer: pathTransformer forName: @"ExpandedPathToPathTransformer"];
	ExpandedPathToIconTransformer * iconTransformer = [[[ExpandedPathToIconTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer: iconTransformer forName: @"ExpandedPathToIconTransformer"];

}

- (IBAction) addFiles: (id)sender
{
	int i; // Loop counter.
	
	// Create the File Open Dialog class.
	NSOpenPanel *openDlg = [NSOpenPanel openPanel];
	
	[openDlg setCanChooseFiles:YES];
	[openDlg setCanChooseDirectories:YES];
	[openDlg setAllowsMultipleSelection:YES];
	
	if ( [openDlg runModalForDirectory:nil file:nil] == NSOKButton )
	{
		NSArray *files = [openDlg filenames];
		
		for( i = 0; i < [files count]; i++ )
		{
			NSString* fileName = [files objectAtIndex:i];
			BOOL isDir;
			if ([[NSFileManager defaultManager] fileExistsAtPath:fileName isDirectory:&isDir])
			{
				if (isDir)
					// add file recursively
					[fileList addFilesInDirectory:fileName];
				else 
					[fileList addFile:fileName];

			}
		}
		
		[fileListView reloadData];
	}	
}

- (IBAction) delFiles: (id)sender
{
	[fileList deleteSelected:fileListView];
}

- (IBAction) bind: (id)sender
{
	NSSavePanel *savePanel;
	int choice;
	
	savePanel = [NSSavePanel savePanel];
	[savePanel setAccessoryView: nil];
	// [savePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"m4a", @"m4b", nil]];
	
	choice = [savePanel runModalForDirectory: NSHomeDirectory()
										  file: @"book.m4b"];
	/* if successful, save file under designated name */
	if (choice == NSOKButton)
	{
		[bindButton setEnabled:FALSE];
		outFile = [[savePanel filename] retain];

		
		[NSThread detachNewThreadSelector:@selector(bindToFileThread:) toTarget:self withObject:nil];
	}
}

- (void) bindingThreadIsDone:(id)sender
{
	[bindButton setEnabled:TRUE];
}

- (void)bindToFileThread:(id)object
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *author = [[form cellAtIndex:ABBAuthor] stringValue];
	NSString *title = [[form cellAtIndex:ABBTitle] stringValue];

	[_binder setOutputFile:outFile];
	
	NSArray *files = [fileList files];
	for (AudioFile *file in files) 
		[_binder addInputFile:file.filePath];
	
	[NSApp beginSheet:progressPanel modalForWindow:window
		modalDelegate:self didEndSelector:NULL contextInfo:nil];	
	
	[fileProgress setMaxValue:100.];
	[fileProgress setDoubleValue:0.]; 
	[fileProgress displayIfNeeded];
	if (![_binder convert])
	{
		NSLog(@"Conversion failed");
	}		
	
	else if (![author isEqualToString:@""] || (![title isEqualToString:@""]))
	{
		NSLog(@"Adding metadata, it may take a while...");
		@try {
			MP4File *mp4 = [[MP4File alloc] initWithFileName:outFile];
			[mp4 setArtist:author]; 
			[mp4 setTitle:title]; 
			[mp4 updateFile];
		}
		@catch (NSException *e) {
			NSLog(@"Something went wrong");
		}
	}
	
	[_binder release];
	[NSApp endSheet:progressPanel];
	[progressPanel orderOut:nil];
	[self performSelectorOnMainThread:@selector(bindingThreadIsDone:) withObject:nil waitUntilDone:NO];
	[pool release];
}

//
// AudioBinderDelegate methods
// 
-(void) conversionStart: (NSString*)filename 
				 format: (AudioStreamBasicDescription*)asbd 
	  formatDescription: (NSString*)description 
				 length: (UInt64)frames

{
	[currentFile setStringValue:[NSString stringWithFormat:@"Converting %@", filename]];
	[fileProgress setMaxValue:(double)frames];
	[fileProgress setDoubleValue:0];
}

-(void) updateStatus: (NSString *)filename handled:(UInt64)handledFrames total:(UInt64)totalFrames
{
	[fileProgress setDoubleValue:(double)handledFrames];
}

-(BOOL) continueFailedConversion:(NSString*)filename reason:(NSString*)reason
{
	return NO;
}

-(void) conversionFinished: (NSString*)filename
{
	[fileProgress setDoubleValue:[fileProgress doubleValue]];
}

-(void) audiobookReady: (NSString*)filename duration: (UInt32)seconds
{
}

- (IBAction) cancel: (id)sender
{
	[_binder cancel];
}


@end

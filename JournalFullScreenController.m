//
//  JournalFullScreenController.m
//  Journler
//
//  Created by Philip Dow on 3/27/07.
//  Copyright 2007 Sprouted, Philip Dow. All rights reserved.
//

/*
 Redistribution and use in source and binary forms, with or without modification, are permitted
 provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions
 and the following disclaimer in the documentation and/or other materials provided with the
 distribution.
 
 * Neither the name of the author nor the names of its contributors may be used to endorse or
 promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
 WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

// Basically, you can use the code in your free, commercial, private and public projects
// as long as you include the above notice and attribute the code to Philip Dow / Sprouted
// If you use this code in an app send me a note. I'd love to know how the code is used.

// Please also note that this copyright does not supersede any other copyrights applicable to
// open source code used herein. While explicit credit has been given in the Journler about box,
// it may be lacking in some instances in the source code. I will remedy this in future commits,
// and if you notice any please point them out.

#import "JournalFullScreenController.h"

#import "Definitions.h"
//#import "JUtility.h"

#import "JournlerEntry.h"
#import "JournlerJournal.h"

#import <SproutedUtilities/SproutedUtilities.h>
#import <SproutedInterface/SproutedInterface.h>

/*
#import "PDFavoritesBar.h"
#import "KFAppleScriptHandlerAdditionsCore.h"
#import "PDAutoCompleteTextField.h"
*/

#import "EntryTabController.h"
#import "FullScreenWindow.h"
#import "LinksOnlyNSTextView.h"
#import "BrowseTableFieldEditor.h"

#import "NSAttributedString+JournlerAdditions.h"
#import "NSAlert+JournlerAdditions.h"

@implementation JournalFullScreenController

- (id)initWithWindow:(NSWindow *)window
{
	if ( self = [super initWithWindow:window] )
	{
		// don't need it
		[tabsBar release];
		[favoritesBar release];				
	}
	return self;
}

- (void) dealloc 
{
	[callingController release];
	[super dealloc];
}

- (void) windowDidLoad 
{	
	//[super windowDidLoad];
	
	// the custom field editor
	[browseTableFieldEditor retain];
	[browseTableFieldEditor setFieldEditor:YES];
	
	activeTabView = initalTabPlaceholder;
	[(FullScreenWindow*)[self window] completelyFillScreen];
	[[self window] registerForDraggedTypes:[NSArray arrayWithObjects:PDEntryIDPboardType, PDFavoritePboardType, nil]];
	//activeTabView = initalTabPlaceholder;
}

#pragma mark -

- (JournlerWindowController*) callingController
{
	return callingController;
}

- (void) setCallingController:(JournlerWindowController*)aWindowController
{
	if ( callingController != aWindowController )
	{
		[callingController release];
		callingController = [aWindowController retain];
	}
}

#pragma mark -

+ (void) enableFullscreenMode
{
	BOOL showMenuBar = [[NSUserDefaults standardUserDefaults] boolForKey:@"FullScreenShowMenuBar"];
	if ( showMenuBar ) 
	{
		SetSystemUIMode(kUIModeNormal, 0);
	}
	else 
	{
		SetSystemUIMode(kUIModeAllHidden, 0);
	}
}

- (BOOL) isFullScreenController
{
	// to be used *only* by full screen controllers
	return YES;
}


#pragma mark -

- (void)windowWillClose:(NSNotification *)aNotification 
{
	//Intentionally not calling super
	//[super windowWillClose:aNotification];
	
	NSResponder *theFirstResponder = [[self window] firstResponder];
	[[self window] makeFirstResponder:nil];
	
	// subclasses should call super's implementation or otherwise perform autosave themselves
	[self performAutosave:aNotification];
	
	// stop observing the tab
	[self stopObservingTab:[self selectedTab] paths:[self observedPathsForTab:[self selectedTab]]];

	NSView *completeContent = [[[self window] contentView] retain];
	PDTabsView *theTabsBar = [tabsBar retain];
	PDFavoritesBar *theFavoritesBar = [favoritesBar retain];
	
	[[self window] setContentView:[[[NSView alloc] initWithFrame:NSMakeRect(0,0,100,100)] autorelease]];
	[tabsBar release]; tabsBar = nil;
	[favoritesBar release]; favoritesBar = nil;

	
	[[[self callingController] window] setContentView:completeContent];
	[[self callingController] setTabControllers:[self tabControllers]];
	[[[self callingController] tabControllers] setValue:[self callingController] forKeyPath:@"owner"];
	
	callingController->activeTabView = activeTabView;
	callingController->favoritesBar = theFavoritesBar;
	callingController->tabsBar = theTabsBar;
	callingController->bookmarksHidden = bookmarksHidden;
	callingController->tabsHidden = tabsHidden;
	
	[theTabsBar setDelegate:callingController];
	[theTabsBar setDataSource:callingController];
	[theFavoritesBar setTarget:callingController];
	[theFavoritesBar setDelegate:callingController];
	
	[[self callingController] setSelectedTabIndex:-1];
	[[self callingController] selectTabAtIndex:[self selectedTabIndex] force:YES];
	[[[self callingController] window] makeFirstResponder:theFirstResponder];
	
    for ( TabController *aTab in [[self callingController] tabControllers] )
		[aTab setFullScreen:NO];
	
	[[self callingController] showWindow:self];
	
	SetSystemUIMode(kUIModeNormal, 0);
	[self autorelease];
}

#pragma mark -

- (BOOL) textViewIsInFullscreenMode:(LinksOnlyNSTextView*)aTextView
{
	#ifdef __DEBUG__
	NSLog(@"%s",__PRETTY_FUNCTION__);
	#endif
	
	return YES;
}

- (void) addTab:(TabController*)aTab atIndex:(NSUInteger)index
{
	[aTab setFullScreen:YES];
	[super addTab:aTab atIndex:index];
}

#pragma mark -

- (IBAction) toggleFullScreen:(id)sender 
{
	[self close];
}

- (void)keyDown:(NSEvent *)theEvent
{
	if ( [theEvent keyCode] == 53 )
	{ 
		// escape key ends fullscreen mode
		[self toggleFullScreen:self];
	}
	else
	{ 
		// anything else is passed to super for the next responder to handle
		[super keyDown:theEvent];
	}
}

#pragma mark -

@end

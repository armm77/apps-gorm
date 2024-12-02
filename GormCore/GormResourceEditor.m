/* GormResourceEditor.m
 *
 * Copyright (C) 2002 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2002
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <AppKit/AppKit.h>

#include "GormDocument.h"
#include "GormPrivate.h"
#include "GormResourceEditor.h"
#include "GormFunctions.h"
#include "GormPalettesManager.h"
#include "GormResource.h"

// @interface NSMatrix (GormResourceEditorPrivate)
// - (BOOL **) _selectedCells;
// - (id **) _cells;
// - (void) _setSelectedCell: (id)c;
// @end

// @implementation NSMatrix (GormResourceEditorPrivate)
// - (BOOL **) _selectedCells
// {
//   return _selectedCells;
// }

// - (id **) _cells
// {
//   return _cells;
// }

// - (void) _setSelectedCell: (id)c
// {
//   _selectedCell = c;
// }
// @end

@implementation	GormResourceEditor

- (BOOL) acceptsTypeFromArray: (NSArray*)types
{
  return [types containsObject: NSFilenamesPboardType];
}

- (NSArray *) fileTypes
{
  return nil;
}

- (NSArray *) pbTypes
{
  return nil;
}

/*
 *	Dragging source protocol implementation
 */
- (void) draggedImage: (NSImage*)i endedAt: (NSPoint)p deposited: (BOOL)f
{
}

- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL)flag
{
  return NSDragOperationCopy;
}

- (id) placeHolderWithPath: (NSString *)string
{
  return nil; 
}

- (void) drawSelection
{
}

- (id<IBDocuments>) document
{
  return document;
}

- (void) handleNotification: (NSNotification*)aNotification
{
  NSString *name = [aNotification name];
  if([name isEqual: GormResizeCellNotification])
    {
      NSDebugLog(@"Received notification");
      [self setCellSize: defaultCellSize()];
    }
}

- (void) addSystemResources
{
  // NSMutableArray    *list = [NSMutableArray array];
  // do nothing... this is the parent class.
}

/*
 *	Initialisation 
 */
- (id) initWithObject: (id)anObject inDocument: (id<IBDocuments>)aDocument
{
  if ((self = [super initWithObject: anObject inDocument: aDocument]) != nil)
    {
      [self setAutoresizingMask: NSViewMinYMargin|NSViewWidthSizable];
      /*
       * Send mouse click actions to self, so we can handle selection.
       */
      [self setAction: @selector(changeSelection:)];
      [self setDoubleAction: @selector(raiseSelection:)];
      [self setTarget: self];

      // add any initial objects
      [self addSystemResources];

      // set up the notification...
      [[NSNotificationCenter defaultCenter]
	addObserver:self
	   selector:@selector(handleNotification:)
	       name:GormResizeCellNotification
	     object:nil];
    }
  return self;
}

- (void) close
{
  [super close];
  [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (NSString *) resourceType
{
  return @"resource";
}

- (void) addObject: (id)anObject
{
  if([objects containsObject: anObject] == NO)
    {
      [super addObject: anObject];
    }
  else
    {
      NSString *type = [self resourceType];
      NSString *msg = [NSString stringWithFormat: _(@"Problem adding %@"), type];
      NSRunAlertPanel(msg, 
		      _(@"A resource with the same name exists, remove it first."), 
		      _(@"OK"), 
		      nil, 
		      nil);      
    }
}

- (void) makeSelectionVisible: (BOOL)flag
{
  if (flag == YES && selected != nil)
    {
      unsigned	pos = [objects indexOfObjectIdenticalTo: selected];
      int	r = pos / [self numberOfColumns];
      int	c = pos % [self numberOfColumns];

      [self selectCellAtRow: r column: c];
    }
  else
    {
      [self deselectAllCells];
    }
  [self displayIfNeeded];
  [[self window] flushWindow];
}

- (void) mouseDown: (NSEvent*)theEvent
{
  NSLog(@"GormResourceEditor: mouseDown:");
  NSInteger row, column;
  NSInteger newRow, newColumn;
  unsigned  eventMask = NSLeftMouseUpMask | NSLeftMouseDownMask
		       | NSMouseMovedMask | NSLeftMouseDraggedMask
		       | NSPeriodicMask;
  NSPoint  lastLocation = [theEvent locationInWindow];
  NSEvent *lastEvent = theEvent;
  NSPoint  initialLocation;
  //   BOOL **selectedCells = [self _selectedCells];
  //   id selectedCell = [self selectedCell];
  
  /*
   * Pathological case -- ignore mouse down
   */
  if ((_numRows == 0) || (_numCols == 0))
    {
      [super mouseDown:theEvent];
      return;
    }

  lastLocation = [self convertPoint:lastLocation fromView:nil];
  initialLocation = lastLocation;
  //   If mouse down was on a selectable cell, start editing/selecting.
  if ([self getRow:&row column:&column forPoint:lastLocation] != NO)
    {
      if ([_cells[row][column] isEnabled])
	{
	  [self selectCell:_cells[row][column]];
	}
    }
  else
    {
      return;
    }

  lastEvent = [NSApp nextEventMatchingMask:eventMask
				 untilDate:[NSDate distantFuture]
				    inMode:NSEventTrackingRunLoopMode
				   dequeue:YES];

  lastLocation = [self convertPoint:[lastEvent locationInWindow] fromView:nil];

  while ([lastEvent type] != NSLeftMouseUp)
    {
      if ((![self getRow:&newRow column:&newColumn forPoint:lastLocation])
	  || (row != newRow) || (column != newColumn)
	  || ((lastLocation.x - initialLocation.x)
		  * (lastLocation.x - initialLocation.x)
		+ (lastLocation.y - initialLocation.y)
		    * (lastLocation.y - initialLocation.y)
	      >= 25))
	{
	  NSPasteboard *pb;
	  NSInteger	pos;
	  pos = row * [self numberOfColumns] + column;

	  // don't allow the user to drag empty resources.
	  if (pos < [objects count])
	    {
	      pb = [NSPasteboard pasteboardWithName:NSDragPboard];
	      [pb declareTypes:[self pbTypes] owner:self];
	      [pb setString:[(GormResource *) [objects objectAtIndex:pos] name]
		    forType:[[self pbTypes] objectAtIndex:0]];
	      [self dragImage:[[objects objectAtIndex:pos] imageForViewer]
			   at:lastLocation
		       offset:NSZeroSize
			event:theEvent
		   pasteboard:pb
		       source:self
		    slideBack:YES];
	    }

	  return;
	}

      lastEvent = [NSApp nextEventMatchingMask:eventMask
				     untilDate:[NSDate distantFuture]
					inMode:NSEventTrackingRunLoopMode
				       dequeue:YES];

      lastLocation = [self convertPoint:[lastEvent locationInWindow]
			       fromView:nil];
    }

  [self changeSelection:self];
}

- (void) pasteInSelection
{
}

- (void) deleteSelection
{
  if(![selected isSystemResource])
    {
      if([selected isInWrapper])
	{
	  NSFileManager *mgr = [NSFileManager defaultManager];
	  NSString *path = [selected path];
	  BOOL removed = [mgr removeFileAtPath: path
			      handler: nil];
	  if(!removed)
	    {
	      NSString *msg = [NSString stringWithFormat: @"Could not delete file %@", path];
	      NSLog(@"%@",msg);
	    }
	}
      [super deleteSelection];
    }
}

- (id) raiseSelection: (id)sender
{
  id	obj = [self changeSelection: sender];
  id	e;

  e = [document editorForObject: obj create: YES];
  [e orderFront];
  [e resetObject: obj];
  return self;
}

@end



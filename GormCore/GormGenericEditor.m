/* GormGenericEditor.m
 *
 * Copyright (C) 1999, 2003 Free Software Foundation, Inc.
 *
 * Author:	Pierre-Yves Rivaille <pyrivail@ens-lyon.fr>
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2003
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

#include "GormGenericEditor.h"
#include "Foundation/NSGeometry.h"
#include "GormFunctions.h"

@interface GormButtonCell : NSButtonCell
@end
@implementation GormButtonCell

- (instancetype)init
{
  [super init];
  [self setBordered:NO];
  [self setSelectable:YES];
  [self setEditable:NO];
  [self setAlignment:NSCenterTextAlignment];
  [self setImagePosition:NSImageAbove];

  [self setShowsStateBy:NSChangeGrayCellMask];
  [self setHighlightsBy:NSChangeGrayCellMask];
  [self setRefusesFirstResponder:YES];

  return self;
}

- (void)drawHighlightAtRect:(NSRect)cellFrame inView:(NSView *)controlView
{
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *path = [bundle pathForImageResource:@"highlight"];
  NSImage  *highlight = [[NSImage alloc] initWithContentsOfFile:path];
  NSPoint offset;
  NSRect  rect;
  NSSize  size = [highlight size];

  /* Calculate an offset from the cellFrame origin */
  offset = NSMakePoint((NSWidth(cellFrame) - size.width) / 2.0,
		       (NSHeight(cellFrame) - size.height) / 2.0);

  rect = NSMakeRect(cellFrame.origin.x + offset.x,
		    cellFrame.origin.y + offset.y, size.width, size.height);

  /* Pixel-align */
  if (nil != controlView)
    {
      rect = [controlView centerScanRect:rect];
    }

  NSLog(@"highlight: %@", highlight);
  [highlight drawInRect:rect
	       fromRect:NSZeroRect
	      operation:NSCompositeSourceOver
	       fraction:1.0
	 respectFlipped:YES
		  hints:nil];
}

- (void)drawImage:(NSImage *)imageToDisplay
	withFrame:(NSRect)cellFrame
	   inView:(NSView *)controlView
{
//   NSLog(@"GormButonCell: drawImage");
  if (imageToDisplay != nil)
    {
      NSPoint offset;
      NSRect  rect;
      NSSize  size = [imageToDisplay size];

      /* Calculate an offset from the cellFrame origin */
      offset = NSMakePoint((NSWidth(cellFrame) - size.width) / 2.0,
                           (NSHeight(cellFrame) - size.height) / 2.0);

      rect = NSMakeRect(cellFrame.origin.x + offset.x,
			cellFrame.origin.y + offset.y, size.width, size.height);

      /* Pixel-align */
      if (nil != controlView)
	{
	  rect = [controlView centerScanRect:rect];
	}

      /* Draw the image */
      if (_cell.is_highlighted || _cell.state)
	{
	  [self drawHighlightAtRect:cellFrame inView:controlView];
	}
      [imageToDisplay drawInRect:rect
			fromRect:NSZeroRect
		       operation:NSCompositeSourceOver
			fraction:1.0
		  respectFlipped:YES
			   hints:nil];
    }
}

@end

@implementation	GormGenericEditor

+ (id) editorForDocument: (id<IBDocuments>)aDocument
{
  // does nothing here, the subclass must define this.
  return nil;
}

- (id) editorForDocument: (id<IBDocuments>)aDocument
{
  return [[self class] editorForDocument: aDocument];
}

+ (void) setEditor: (id)editor
       forDocument: (id<IBDocuments>)aDocument
{
  // does nothing, defined by subclass.
}

- (void) setEditor: (id)editor
       forDocument: (id<IBDocuments>)aDocument
{
  [[self class] setEditor: editor
		     forDocument: aDocument];
}

- (BOOL) acceptsFirstMouse: (NSEvent*)theEvent
{
  return YES;   /* Ensure we get initial mouse down event.      */
}

- (BOOL) activate
{
  activated = YES;
  [[self window] makeKeyAndOrderFront: self];
  return YES;
}

- (void) addObject: (id)anObject
{
  if (anObject != nil
    && [objects indexOfObjectIdenticalTo: anObject] == NSNotFound)
    {
      [objects addObject: anObject];
      [self refreshCells];
    }
}

- (void) mouseDown: (NSEvent*)theEvent
{
  NSPoint   loc = [theEvent locationInWindow];
  NSInteger r = 0, c = 0;
  int	    pos = 0;
  id	    obj = nil;

  loc = [self convertPoint:loc fromView:nil];
  [self getRow:&r column:&c forPoint:loc];
  pos = r * [self numberOfColumns] + c;
  if (pos >= 0 && pos < [objects count])
    {
      obj = [objects objectAtIndex:pos];
    }
  if (obj != nil && obj != selected)
    {
      [self selectObjects:[NSArray arrayWithObject:obj]];
    }
  else
    {
      [super mouseDown:theEvent];
    }
}


- (id) changeSelection: (id)sender
{
  int	row = [self selectedRow];
  int	col = [self selectedColumn];
  int	index = row * [self numberOfColumns] + col;
  id	obj = nil;

  if (index >= 0 && index < [objects count])
    {
      obj = [objects objectAtIndex: index];
      [self selectObjects: [NSArray arrayWithObject: obj]];
    }
  return obj;
}

- (BOOL) containsObject: (id)object
{
  if ([objects indexOfObjectIdenticalTo: object] == NSNotFound)
    return NO;
  return YES;
}

- (void) willCloseDocument: (NSNotification *)aNotification
{
  document = nil;
}

- (void) close
{
  if(closed == NO)
    {
      closed = YES;
      [document editor: self didCloseForObject: [self editedObject]];
      [self deactivate];
      [self closeSubeditors];
    }
}

// Stubbed out methods...  Since this is an abstract class, some methods need to be
// provided so that compilation will occur cleanly and to give a warning if called.
- (void) closeSubeditors
{
}

- (void) resetObject: (id)object
{
}

- (id) initWithObject: (id)anObject inDocument: (id<IBDocuments>)aDocument
{
  if ((self = [super init]) != nil)
    {
      NSButtonCell *proto;

      /* don't retain the document... */
      document = aDocument;
      closed = NO;
      activated = NO;
      resourceManager = nil;

      proto = [GormButtonCell new];
      [self setPrototype: proto];
      RELEASE(proto);
      [self setAutosizesCells:NO];
      [self setCellSize: defaultCellSize()];
      [self setIntercellSpacing: NSMakeSize(8,8)];
      [self setMode:NSRadioModeMatrix];

      objects = [[NSMutableArray alloc] init];
      if (anObject != nil)
	{
	  [self addObject:anObject];
	}

      /* since we don't retain the document handle its close notifications */
      [[NSNotificationCenter defaultCenter]
	addObserver:self
	   selector:@selector(willCloseDocument:)
	       name:IBWillCloseDocumentNotification
	     object:document];
    }
  return self;
}

- (BOOL) acceptsTypeFromArray: (NSArray*)types
{
  return NO;
}

// IBEditor protocol
- (void) makeSelectionVisible: (BOOL)flag
{
}

- (void) deactivate
{
  activated = NO;
}

- (void) copySelection
{
}

- (void) pasteInSelection
{
}
// end of stubbed methods...

- (void) dealloc
{
  if(closed == NO)
    [self close];

  // The resource manager is a weak connection and is not retained,
  // no need to release it here.
  RELEASE(objects); 

  // Remove self from any and all notifications.
  [[NSNotificationCenter defaultCenter]
    removeObserver: self];
  
  [super dealloc];
}

- (void) deleteSelection
{
  if (selected != nil)
    {
      [document detachObject: selected];
      [objects removeObjectIdenticalTo: selected];
      [self selectObjects: [NSArray array]];
      [self refreshCells];
    }
}

- (id<IBDocuments>) document
{
  return document;
}

- (id) editedObject
{
  return selected;
}

- (id<IBEditors>) openSubeditorForObject: (id)anObject
{
  return nil;
}

- (void) orderFront
{
  [[self window] orderFront: self];
}


/*
 * Return the rectangle in which an objects image will be displayed.
 * (use window coordinates)
 */
- (NSRect) rectForObject: (id)anObject
{
  NSUInteger	pos = [objects indexOfObjectIdenticalTo: anObject];
  NSRect	rect;
  int		r;
  int		c;

  if (pos == NSNotFound)
    return NSZeroRect;
  r = pos / [self numberOfColumns];
  c = pos % [self numberOfColumns];
  rect = [self cellFrameAtRow: r column: c];
  /*
   * Adjust to image area.
   */
  rect.size.height -= 15;
  rect = [self convertRect: rect toView: nil];
  return rect;
}


- (void) refreshCells
{
  NSUInteger	count = [objects count];
  NSUInteger	index = 0;
  int		cols = 0;
  int		rows = 0;
  int		width = 0;

  NSLog(@"GormGenericEditor-%@ refreshCells: %@", [self className],
	NSStringFromRect([self bounds]));

  if ([self superview] == nil)
    {
      return;
    }
  
  width = [[self superview] bounds].size.width;
  while (width >= _cellSize.width)
    {
      width -= (_cellSize.width + _intercell.width);
      cols++;
    }
  if (cols == 0)
    {
      cols = 1;
    }
  rows = count / cols;
  if (rows == 0 || rows * cols != count)
    {
      rows++;
    }
  [self renewRows: rows columns: cols];

  for (index = 0; index < count; index++)
    {
      id		obj = [objects objectAtIndex: index];
      NSButtonCell	*but = [self cellAtRow: index/cols column: index%cols];

      [but setImage: [obj imageForViewer]];
      [but setTitle: [document nameForObject: obj]];
    }
  while (index < rows * cols)
    {
      NSButtonCell	*but = [self cellAtRow: index/cols column: index%cols];

      [but setImage: nil];
      [but setTitle: @""];
      [but setShowsStateBy: NSNoCellMask];
      [but setHighlightsBy: NSNoCellMask];
      index++;
    }
  [self sizeToCells];
}

- (void) removeObject: (id)anObject
{
  NSUInteger	pos;

  pos = [objects indexOfObjectIdenticalTo: anObject];
  if (pos == NSNotFound)
    {
      return;
    }
  [objects removeObjectAtIndex: pos];
  [self refreshCells];
}

- (void) resizeWithOldSuperviewSize: (NSSize)oldSize
{
  [self refreshCells];
}

- (NSArray*) selection
{
  if (selected == nil)
    return [NSArray array];
  else
    return [NSArray arrayWithObject: selected];
}

- (NSUInteger) selectionCount
{
  return (selected == nil) ? 0 : 1;
}


- (BOOL) wantsSelection
{
  return NO;
}

- (NSWindow*) window
{
  return [super window];
}

- (void) selectObjects: (NSArray*)anArray
{
  id	obj = [anArray lastObject];

  selected = obj;
  [document setSelectionFromEditor: self];
  [self makeSelectionVisible: YES];
}

- (NSArray *) objects
{
  return objects;
}

- (BOOL) isOpened
{
  return (closed == NO);
}

// stubs for protocol methods not implemented in this editor.
- (void) validateEditing
{
  // does nothing.
}

- (void) drawSelection
{
  // does nothing.
}

- (NSArray *)fileTypes
{
  return nil;
}
@end

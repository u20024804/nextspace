/*
  Sound preferences bundle

  Author:	Sergii Stoian <stoyan255@gmail.com>
  Date:		2019

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License as
  published by the Free Software Foundation; either version 2 of
  the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this program; if not, write to:

  Free Software Foundation, Inc.
  59 Temple Place - Suite 330
  Boston, MA  02111-1307, USA
*/
#import <AppKit/AppKit.h>
#import <SoundKit/SoundKit.h>

#import "Sound.h"
#import "Mixer.h"

@implementation Sound

// --- Init and dealloc
- (void)dealloc
{
  NSLog(@"Sound -dealloc");
  if (soundServer) {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [soundOut release];
    [soundIn release];
    [soundServer disconnect];
    [soundServer release];
  }
  [soundsList release];
  [defaults synchronize];
  [image release];
  if (mixer)
    [mixer release];
  [super dealloc];
}

- (id)init
{
  NSBundle *bundle;
  NSString *imagePath;
  
  self = [super init];
  
  defaults = [NXTDefaults globalUserDefaults];

  bundle = [NSBundle bundleForClass:[self class]];
  imagePath = [bundle pathForResource:@"Sound" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];

  defaultSound = [defaults objectForKey:@"NXSystemBeep"];
  if (defaultSound == nil) {
    defaultSound = @"/usr/NextSpace/Sounds/Bonk.snd";
    [defaults setObject:defaultSound forKey:@"NXSystemBeep"];
  }

  soundsList = [[NSDictionary alloc]
                 initWithDictionary:[self loadSoundList]];
      
  return self;
}

- (NSDictionary *)loadSoundList
{
  NSString            *path, *filePath;
  NSArray             *soundFiles;
  NSArray             *pathList = NSStandardLibraryPaths();
  NSFileManager       *fm = [NSFileManager defaultManager];
  NSMutableDictionary *list;

  list = [[NSMutableDictionary alloc] init];

  for (NSString *lp in pathList) {
    path = [NSString stringWithFormat:@"%@/Sounds", lp];
    NSLog(@"Searching for sounds in %@", path);
    soundFiles = [fm contentsOfDirectoryAtPath:path error:NULL];

    for (NSString *file in soundFiles) {
      if ([file isEqualToString:@"SystemBeep.snd"] == NO) {
        filePath = [NSString stringWithFormat:@"%@/%@", path, file];
        [list setObject:filePath
                 forKey:[file stringByDeletingPathExtension]];
      }
    }
  }

  return [list autorelease];
}

- (void)awakeFromNib
{
  NSString *beepType;
  
  [view retain];
  [window release];

  // 1. Connect to PulseAudio on locahost
  soundServer = [SNDServer sharedServer];
  // 2. Wait for server to be ready
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(serverStateChanged:)
           name:SNDServerStateDidChangeNotification
         object:soundServer];

  [[beepAudioRadio cellWithTag:0] setRefusesFirstResponder:YES];
  [[beepAudioRadio cellWithTag:1] setRefusesFirstResponder:YES];
  beepType = [defaults objectForKey:@"NXSystemBeepType"];
  [beepAudioRadio
    selectCellWithTag:([beepType isEqualToString:@"Audio"] == NO)];
}

// --- Protocol
- (NSView *)view
{
  if (view == nil) {
    if (![NSBundle loadNibNamed:@"Sound" owner:self]) {
      NSLog (@"Sound.preferences: Could not load GORM file, aborting.");
      return nil;
    }
  }
  return view;
}

- (NSString *)buttonCaption
{
  return @"Sound Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

- (void)_updateControls
{
  NSString *info = [NSString stringWithFormat:@"%@ version %@ on %@@%@",
                             soundServer.name, soundServer.version,
                             soundServer.userName, soundServer.hostName];
  [soundInfo setStringValue:info];
  if (soundOut) {
    [muteButton setEnabled:YES];
    [volumeLevel setEnabled:YES];
    [volumeBalance setEnabled:YES];
    [muteButton setState:[soundOut isMute]];
    [volumeLevel setIntegerValue:[soundOut volume]];
    [volumeBalance setFloatValue:[soundOut balance]];
  }
  else {
    [muteButton setEnabled:NO];
    [volumeLevel setEnabled:NO];
    [volumeBalance setEnabled:NO];
  }
  
  if (soundIn) {
    [muteMicButton setEnabled:YES];
    [micLevel setEnabled:YES];
    [micBalance setEnabled:YES];
    [muteMicButton setState:[soundIn isMute]];
    [micLevel setIntegerValue:[soundIn volume]];
    [micBalance setFloatValue:[soundIn balance]];
  }
  else {
    [muteMicButton setEnabled:NO];
    [micLevel setEnabled:NO];
    [micBalance setEnabled:NO];
  }
}

// --- Key-Value Observing
static void *OutputContext = &OutputContext;
static void *InputContext = &InputContext;
- (void)observeOutput:(SNDOut *)output
{
  [output.sink addObserver:self
                forKeyPath:@"mute"
                   options:NSKeyValueObservingOptionNew
                   context:OutputContext];
  [output.sink addObserver:self
                forKeyPath:@"channelVolumes"
                   options:NSKeyValueObservingOptionNew
                   context:OutputContext];
}
- (void)observeInput:(SNDIn *)input
{
  [input.source addObserver:self
                 forKeyPath:@"mute"
                    options:NSKeyValueObservingOptionNew
                    context:InputContext];
  [input.source addObserver:self
                 forKeyPath:@"channelVolumes"
                    options:NSKeyValueObservingOptionNew
                    context:InputContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if (context == OutputContext) {
    if ([keyPath isEqualToString:@"mute"]) {
      [muteButton setState:[soundOut isMute]];
    }
    else if ([keyPath isEqualToString:@"channelVolumes"]) {
      [volumeLevel setIntegerValue:[soundOut volume]];
      [volumeBalance setFloatValue:[soundOut balance]];
    }
  }
  else if (context == InputContext) {
    if ([keyPath isEqualToString:@"mute"]) {
      [muteMicButton setState:[soundIn isMute]];
    }
    else if ([keyPath isEqualToString:@"channelVolumes"]) {
      [micLevel setIntegerValue:[soundIn volume]];
      [micBalance setFloatValue:[soundIn balance]];
    }
  } else {
    // Any unrecognized context must belong to super
    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
  }
}

// --- Sound subsystem actions
- (void)serverStateChanged:(NSNotification *)notif
{
  if ([notif object] != soundServer) {
    NSLog(@"Received other SNDServer state change notification.");
    return;
  }
  if (soundServer.status == SNDServerReadyState) {
    soundOut = [[soundServer defaultOutput] retain];
    soundIn = [[soundServer defaultInput] retain];
    if (soundOut) {
      [volumeLevel setMaxValue:[soundOut volumeSteps]-1];
      [self observeOutput:soundOut];
    }
    if (soundIn) {
      [micLevel setMaxValue:[soundIn volumeSteps]-1];
      [self observeInput:soundIn];
    }
    [self _updateControls];
    [self reloadBrowser];    
  }
  else if (soundServer.status == SNDServerFailedState ||
           soundServer.status == SNDServerTerminatedState) {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [soundServer release];
    soundServer = nil;
  }
}

// --- Control actions

- (void)reloadBrowser
{
  [beepBrowser reloadColumn:0];
  
  // NSLog(@"Default sound row %li", defSoundRow);
  // [beepBrowser selectRow:defSoundRow inColumn:0];
  [[beepBrowser matrixInColumn:0] selectCellAtRow:defSoundRow column:0];
  [beepBrowser scrollRowToVisible:defSoundRow inColumn:0];
}
- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix *)matrix
{
  NSBrowserCell *cell;
  NSString      *filePath;
  NSInteger     row;

  defSoundRow = -1;
  for (NSString *file in [soundsList allKeys]) {
    [matrix addRow];
    row = [matrix numberOfRows] - 1;
    cell = [matrix cellAtRow:row column:column];
    [cell setLeaf:YES];
    [cell setRefusesFirstResponder:YES];
    [cell setTitle:[file stringByDeletingPathExtension]];

    filePath = [soundsList objectForKey:file];
    [cell setRepresentedObject:filePath];
    
    if ([filePath isEqualToString:defaultSound]) {
      NSLog(@"Default sound found at row %li (column:%li)", row, column);
      defSoundRow = row;
    }
  }
}

- (void)setMute:(id)sender
{
  SNDDevice *device = (sender == muteButton) ? soundOut : soundIn;
  [device setMute:[sender state]];
}
- (void)setVolume:(id)sender
{
  SNDDevice *device = (sender == volumeLevel) ? soundOut : soundIn;

  [device setVolume:[sender intValue]];
}
- (void)setBalance:(id)sender
{
  SNDDevice *device = (sender == volumeBalance) ? soundOut : soundIn;
  
  [device setBalance:[sender intValue]];
}

- (void)setBeep:(id)sender
{
  NSString   *soundPath;
  NSSound    *sound;

  // FIXME: should be:
  //// Write NXSystemBeep value to defaults.
  // [defs setObject:soundPath forKey:@"NXSystemBeep"];
  //// Call NSBeep() to play sound (Workspace should reread defaults on
  //// [defs synchronize] and play new sound with XBell catching function).
  // NSBeep();
  soundPath = [[beepBrowser selectedCellInColumn:0] representedObject];
  sound = [[NSSound alloc] initWithContentsOfFile:soundPath byReference:NO];
  [sound play];
  [sound release];

  [defaults setObject:soundPath forKey:@"NXSystemBeep"];
}
- (void)setBeepRadio:(id)sender
{
  NSString *type = [defaults objectForKey:@"NXSystemBeepType"];
  NSString *title = [[sender selectedCell] title];

  if ([title isEqualToString:type]) {
    return;
  }
  [defaults setObject:title forKey:@"NXSystemBeepType"];
}

- (void)showMixer:(id)sender
{
  if (mixer == nil) {
    mixer = [[Mixer alloc] initWithServer:soundServer];
  }
  [[mixer window] makeKeyAndOrderFront:self];
}

@end

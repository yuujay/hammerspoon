@import Cocoa ;
@import LuaSkin ;

#import "MJAppDelegate.h"

//
// TO-DO LIST:
//
//  * Add `hs.dialog.chooseFromList()` as discussed here: https://github.com/Hammerspoon/hammerspoon/issues/1227#issuecomment-278972348
//

#define USERDATA_TAG  "hs.dialog"
static int refTable = LUA_NOREF ;

#pragma mark - Support Functions and Classes

//
// COLOR PANEL:
//
@interface HSColorPanel : NSObject
@property int callbackRef ;
@end

@implementation HSColorPanel
- (instancetype)init {
    self = [super init] ;
    if (self) {
        _callbackRef = LUA_NOREF ;
        NSColorPanel *cp = [NSColorPanel sharedColorPanel];
        [cp setTarget:self];
        [cp setAction:@selector(colorCallback:)];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(colorClose:)
                                                     name:NSWindowWillCloseNotification
                                                   object:cp] ;
    }
    return self ;
}

// Second argument to callback is true indicating this is a close color panel event
- (void)colorClose:(__unused NSNotification*)note {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            NSColorPanel *cp = [NSColorPanel sharedColorPanel];
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            [skin pushNSObject:cp.color] ;
            lua_pushboolean(L, YES) ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s: color callback error, %s",
                                                          USERDATA_TAG,
                                                          lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        }) ;
    }
}

// Second argument to callback is false indicating that the color panel is still open (i.e. they may change color again)
- (void)colorCallback:(NSColorPanel*)colorPanel {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            [skin pushNSObject:colorPanel.color] ;
            lua_pushboolean(L, NO) ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s: color callback error, %s",
                                                          USERDATA_TAG,
                                                          lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        }) ;
    }
}
@end

//
// FONT PANEL:
//
@interface HSFontPanel : NSObject <NSWindowDelegate>
@property int          callbackRef ;
@property NSUInteger   fontPanelModes ;
@property NSDictionary *attributesDictionary ;
@end

@implementation HSFontPanel
- (instancetype)init {
    self = [super init] ;
    if (self) {
        _callbackRef = LUA_NOREF ;
        _attributesDictionary = @{} ;
        _fontPanelModes = NSFontPanelFaceModeMask | NSFontPanelSizeModeMask | NSFontPanelCollectionModeMask ;
        NSFontPanel *fp = [NSFontPanel sharedFontPanel];
        fp.delegate = self ;
        NSFontManager *fm = [NSFontManager sharedFontManager];
        [fm setTarget:self];
        [fm setSelectedFont:[NSFont systemFontOfSize: 27] isMultiple:NO] ;
        [fm setSelectedAttributes:_attributesDictionary isMultiple:NO] ;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(fontClose:)
                                                     name:NSWindowWillCloseNotification
                                                   object:fp] ;
    }
    return self ;
}

- (void)fontClose:(__unused NSNotification*)note {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            [skin pushNSObject:[[NSFontManager sharedFontManager] selectedFont]] ;
            lua_pushboolean(L, YES) ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s: font callback error, %s",
                                                          USERDATA_TAG,
                                                          lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        }) ;
    }
}

- (void)changeFont:(id)obj {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            [skin pushNSObject:[obj selectedFont]] ;
            lua_pushboolean(L, NO) ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s: font callback error, %s",
                                                          USERDATA_TAG,
                                                          lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        }) ;
    }
}

- (void)changeAttributes:(id)obj {
    if (_callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin   *skin = [LuaSkin shared] ;
            lua_State *L    = [skin L] ;
            [skin pushLuaRef:refTable ref:self->_callbackRef] ;
            self->_attributesDictionary = [obj convertAttributes:self->_attributesDictionary] ;
            [[NSFontManager sharedFontManager] setSelectedAttributes:self->_attributesDictionary isMultiple:NO] ;
            [skin pushNSObject:self->_attributesDictionary] ;
            lua_pushboolean(L, NO) ;
            if (![skin protectedCallAndTraceback:2 nresults:0]) {
                [skin logError:[NSString stringWithFormat:@"%s: font callback error, %s",
                                                          USERDATA_TAG,
                                                          lua_tostring(L, -1)]] ;
                lua_pop(L, 1) ;
            }
        }) ;
    }
}

@end

static HSColorPanel *cpReceiverObject ;
static HSFontPanel *fpReceiverObject ;

// This must be in the responder chain for the application; we'll stick it into the Hammerspoon application delegate
// which is at the base of the responder chain.
@interface MJAppDelegate (dialogFontPanelAdditions)
- (NSUInteger)validModesForFontPanel:(NSFontPanel *)fontPanel ;
@end

@implementation MJAppDelegate (dialogFontPanelAdditions)

- (NSUInteger)validModesForFontPanel:(__unused NSFontPanel *)fontPanel {
    if (fpReceiverObject) {
        return fpReceiverObject.fontPanelModes ;
    } else {
        return NSFontPanelFaceModeMask | NSFontPanelSizeModeMask | NSFontPanelCollectionModeMask ;
    }
}

@end

#pragma mark - Color Panel Functions

/// hs.dialog.color.callback([callbackFn]) -> function or nil
/// Function
/// Sets or removes the callback function for the color panel.
///
/// Parameters:
///  * a function, or `nil` to remove the current function, which will be invoked as a callback for messages generated by this color panel. The callback function should expect 2 arguments as follows:
///    ** A table containing the color values from the color panel.
///    ** A boolean which returns `true` if the color panel has been closed otherwise `false` indicating that the color panel is still open (i.e. it may change color again).
///
/// Returns:
///  * The last callbackFn or `nil` so you can save it and re-attach it if something needs to temporarily take the callbacks.
///
/// Notes:
///  * Example:
///      `hs.dialog.color.callback(function(a,b) print("COLOR CALLBACK:\nSelected Color: " .. hs.inspect(a) .. "\nPanel Closed: " .. hs.inspect(b)) end)`
static int colorPanelCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;

    if (cpReceiverObject.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:cpReceiverObject.callbackRef] ;
    } else {
        lua_pushnil(L) ;
    }
    if (lua_gettop(L) == 2) { // we just added to it...
        // in either case, we need to remove an existing callback, so...
        cpReceiverObject.callbackRef = [skin luaUnref:refTable ref:cpReceiverObject.callbackRef] ;
        if (lua_type(L, 1) == LUA_TFUNCTION) {
            lua_pushvalue(L, 1) ;
            cpReceiverObject.callbackRef = [skin luaRef:refTable] ;
        }
    }
    // return the *last* fn (or nil) so you can save it and re-attach it if something needs to
    // temporarily take the callbacks
    return 1 ;
}

/// hs.dialog.color.continuous([value]) -> boolean
/// Function
/// Set or display whether or not the callback should be continiously updated when a user drags a color slider or control.
///
/// Parameters:
///  * [value] - `true` if you want to continiously trigger the callback, otherwise `false`.
///
/// Returns:
///  * `true` if continuous is enabled otherwise `false`
///
/// Notes:
///  * Example:
///      `hs.dialog.color.continuous(true)`
static int colorPanelContinuous(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSColorPanel *cp = [NSColorPanel sharedColorPanel];
    if (lua_gettop(L) == 1) {
        [cp setContinuous:(BOOL)lua_toboolean(L, 1)] ;
    }
    lua_pushboolean(L, cp.continuous) ;
    return 1 ;
}

/// hs.dialog.color.showsAlpha([value]) -> boolean
/// Function
/// Set or display whether or not the color panel should display an opacity slider.
///
/// Parameters:
///  * [value] - `true` if you want to display an opacity slider, otherwise `false`.
///
/// Returns:
///  * `true` if the opacity slider is displayed otherwise `false`
///
/// Notes:
///  * Example:
///      `hs.dialog.color.showsAlpha(true)`
static int colorPanelShowsAlpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSColorPanel *cp = [NSColorPanel sharedColorPanel];
    if (lua_gettop(L) == 1) {
        [cp setShowsAlpha:(BOOL)lua_toboolean(L, 1)] ;
    }
    lua_pushboolean(L, cp.showsAlpha) ;
    return 1 ;
}

/// hs.dialog.color.color([value]) -> table
/// Function
/// Set or display the currently selected color in a color wheel.
///
/// Parameters:
///  * [value] - The color values in a table (as described in `hs.drawing.color`).
///
/// Returns:
///  * A table of the currently selected color in the form of `hs.drawing.color`.
///
/// Notes:
///  * Example:
///      `hs.dialog.color.color(hs.drawing.color.blue)`
static int colorPanelColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    NSColorPanel *cp = [NSColorPanel sharedColorPanel];
    if (lua_gettop(L) == 1) {
        NSColor *theColor = [[LuaSkin shared] luaObjectAtIndex:1 toClass:"NSColor"] ;
        [cp setColor:theColor] ;
    }
    [skin pushNSObject:[cp color]] ;
    return 1 ;
}

/// hs.dialog.color.mode([value]) -> table
/// Function
/// Set or display the currently selected color panel mode.
///
/// Parameters:
///  * [value] - The mode you wish to use as a string from the following options:
///    ** "wheel" - Color Wheel
///    ** "gray" - Gray Scale Slider
///    ** "RGB" - RGB Sliders
///    ** "CMYK" - CMYK Sliders
///    ** "HSB" - HSB Sliders
///    ** "list" - Color Palettes
///    ** "custom" - Image Palettes
///    ** "crayon" - Pencils
///    ** "none"
///
/// Returns:
///  * The current mode as a string.
///
/// Notes:
///  * Example:
///      `hs.dialog.color.mode("RGB")`
static int colorPanelMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSColorPanel *cp = [NSColorPanel sharedColorPanel];
    if (lua_gettop(L) == 1) {
        NSString *theMode = [skin toNSObjectAtIndex:1] ;
        if ([theMode isEqualToString:@"none"]) {
            [cp setMode:NSColorPanelModeNone];
        } else if ([theMode isEqualToString:@"gray"]) {
            [cp setMode:NSColorPanelModeGray];
        } else if ([theMode isEqualToString:@"RGB"]) {
            [cp setMode:NSColorPanelModeRGB];
        } else if ([theMode isEqualToString:@"CMYK"]) {
            [cp setMode:NSColorPanelModeCMYK];
        } else if ([theMode isEqualToString:@"HSB"]) {
            [cp setMode:NSColorPanelModeHSB];
        } else if ([theMode isEqualToString:@"custom"]) {
            [cp setMode:NSColorPanelModeCustomPalette];
        } else if ([theMode isEqualToString:@"list"]) {
            [cp setMode:NSColorPanelModeColorList];
        } else if ([theMode isEqualToString:@"wheel"]) {
            [cp setMode:NSColorPanelModeWheel];
        } else if ([theMode isEqualToString:@"crayon"]) {
            [cp setMode:NSColorPanelModeCrayon];
        } else {
            return luaL_error(L, "unknown color panel mode") ;
        }
    }

    switch(cp.mode) {
        case NSColorPanelModeNone:          [skin pushNSObject:@"none"] ; break ;
        case NSColorPanelModeGray:          [skin pushNSObject:@"gray"] ; break ;
        case NSColorPanelModeRGB:           [skin pushNSObject:@"RGB"] ; break ;
        case NSColorPanelModeCMYK:          [skin pushNSObject:@"CMYK"] ; break ;
        case NSColorPanelModeHSB:           [skin pushNSObject:@"HSB"] ; break ;
        case NSColorPanelModeCustomPalette: [skin pushNSObject:@"custom"] ; break ;
        case NSColorPanelModeColorList:     [skin pushNSObject:@"list"] ; break ;
        case NSColorPanelModeWheel:         [skin pushNSObject:@"wheel"] ; break ;
        case NSColorPanelModeCrayon:        [skin pushNSObject:@"crayon"] ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"** unrecognized mode:%ld", [cp mode]]] ;
            break ;
    }
    return 1;
}

/// hs.dialog.color.alpha([value]) -> number
/// Function
/// Set or display the selected opacity.
///
/// Parameters:
///  * [value] - A opacity value as a number between 0 and 1, where 0 is 100% transparent/see-through.
///
/// Returns:
///  * The current alpha value as a number.
///
/// Notes:
///  * Example:
///      `hs.dialog.color.alpha(0.5)`
static int colorPanelAlpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;

    NSColorPanel *cp = [NSColorPanel sharedColorPanel];
    if (lua_gettop(L) == 1) {
        NSNumber *alpha = [skin toNSObjectAtIndex:1];
        NSColor *color = [[cp color] colorWithAlphaComponent:[alpha doubleValue]];
        [cp setColor:color] ;
    }

    lua_pushnumber(L, [[NSColorPanel sharedColorPanel] alpha]) ;
    return 1 ;
}

/// hs.dialog.color.show() -> none
/// Function
/// Shows the Color Panel.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * Example:
///      `hs.dialog.color.show()`
static int colorPanelShow(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [NSApp orderFrontColorPanel:nil] ;
    return 0 ;
}

/// hs.dialog.color.hide() -> none
/// Function
/// Hides the Color Panel.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * Example:
///      `hs.dialog.color.hide()`
static int colorPanelHide(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [[NSColorPanel sharedColorPanel] close] ;
    return 0 ;
}

#pragma mark - Font Panel Functions

/// hs.dialog.font.callback([callbackFn]) -> function or nil
/// Function
/// Sets or removes the callback function for the font panel.
///
/// Parameters:
///  * a function, or `nil` to remove the current function, which will be invoked as a callback for messages generated by this font panel. The callback function should expect 2 arguments as follows:
///    ** A table containing the font values from the font panel.
///    ** A boolean which returns `true` if the color panel has been closed otherwise `false` indicating that the color panel is still open (i.e. it may change font again).
///
/// Returns:
///  * The last callbackFn or `nil` so you can save it and re-attach it if something needs to temporarily take the callbacks.
///
/// Notes:
///  * Example:
///      `hs.dialog.font.callback(function(a,b) print("FONT CALLBACK:\nSelected Font: " .. hs.inspect(a) .. "\nPanel Closed: " .. hs.inspect(b)) end)`
static int fontPanelCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TFUNCTION | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;

    if (fpReceiverObject.callbackRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:fpReceiverObject.callbackRef] ;
    } else {
        lua_pushnil(L) ;
    }
    if (lua_gettop(L) == 2) { // we just added to it...
        // in either case, we need to remove an existing callback, so...
        fpReceiverObject.callbackRef = [skin luaUnref:refTable ref:fpReceiverObject.callbackRef] ;
        if (lua_type(L, 1) == LUA_TFUNCTION) {
            lua_pushvalue(L, 1) ;
            fpReceiverObject.callbackRef = [skin luaRef:refTable] ;
        }
    }
    // return the *last* fn (or nil) so you can save it and re-attach it if something needs to
    // temporarily take the callbacks
    return 1 ;
}

/// hs.dialog.font.show() -> none
/// Function
/// Shows the Font Panel.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * Example:
///      `hs.dialog.font.show()`
static int fontPanelShow(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [[NSFontPanel sharedFontPanel] orderFront:nil] ;
    return 0 ;
}

/// hs.dialog.font.hide() -> none
/// Function
/// Hides the Font Panel.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * Example:
///      `hs.dialog.font.hide()`
static int fontPanelHide(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [[NSFontPanel sharedFontPanel] close] ;
    return 0 ;
}

/// hs.dialog.font.mode([value]) -> number
/// Function
/// Set or display the font panel mode.
///
/// Parameters:
///  * [value] - A number value, as defined in `hs.dialog.font.panelModes`.
///
/// Returns:
///  * The current mode value as a number.
///
/// Notes:
///  * Example:
///      `hs.dialog.color.mode(hs.dialog.font.panelModes.face)`
static int fontPanelMode(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 1) {
        fpReceiverObject.fontPanelModes = (NSUInteger)luaL_checkinteger(L, 1) ;
    }
    lua_pushinteger(L, (lua_Integer)fpReceiverObject.fontPanelModes) ;
    return 1 ;
}

#pragma mark - Choose File or Folder

/// hs.dialog.chooseFileOrFolder([message], [defaultPath], [canChooseFiles], [canChooseDirectories], [allowsMultipleSelection]) -> string
/// Function
/// Displays a file and/or folder selection dialog box using NSOpenPanel.
///
/// Parameters:
///  * [message] - The optional message text to display.
///  * [defaultPath] - The optional path you want to dialog to open to.
///  * [canChooseFiles] - Whether or not the user can select files. Defaults to `true`.
///  * [canChooseDirectories] - Whether or not the user can select folders. Default to `false`.
///  * [allowsMultipleSelection] - Allow multiple selections of files and/or folders. Defaults to `false`.
///  * [allowedFileTypes] - An optional table of allowed file types. Defaults to `true`.
///  * [resolvesAliases] - An optional boolean that indicates whether the panel resolves aliases.
///
/// Returns:
///  * The selected files in a table or `nil` if cancel was pressed.
///
/// Notes:
///  * The optional values must be entered in order (i.e. you can't supply `allowsMultipleSelection` without also supplying `canChooseFiles` and `canChooseDirectories`).
///  * Example:
///      `hs.inspect(hs.dialog.chooseFileOrFolder("Please select a file:", "~/Desktop", true, false, true, {"jpeg", "pdf"}, true))`
static int chooseFileOrFolder(lua_State *L) {

    // Check the Parameters:
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TOPTIONAL | LS_TSTRING, LS_TOPTIONAL | LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TTABLE | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    // Create new NSOpenPanel:
    NSOpenPanel *panel = [NSOpenPanel openPanel];

    // Allowed File Types:
    NSMutableArray *allowedFileTypes;
    if (lua_istable(L, 6)) {
        allowedFileTypes = [[NSMutableArray alloc] init];
        lua_pushnil(L);
        while (lua_next(L, 6) != 0) {
            NSString *item = [NSString stringWithUTF8String:luaL_checkstring(L, -1)];
            [allowedFileTypes addObject:item];
            lua_pop(L, 1);
        }
        [panel setAllowedFileTypes:allowedFileTypes];
    }

    // Message:
    NSString* message = [skin toNSObjectAtIndex:1];
    if(message != nil) {
        [panel setMessage:message];
    }

    // Default Path:
    NSString* path = [skin toNSObjectAtIndex:2];
    if(path != nil) {
        NSURL *url = [[NSURL alloc] initWithString:path];
        [panel setDirectoryURL:url];
    }

    // Can Choose Files:
    if (lua_isboolean(L, 3) && !lua_toboolean(L, 3)) {
        [panel setCanChooseFiles:NO];
    }
    else
    {
        [panel setCanChooseFiles:YES];

    }

    // Can Choose Directories:
    if (lua_isboolean(L, 4) && lua_toboolean(L, 4)) {
        [panel setCanChooseDirectories:YES];
    }
    else {
        [panel setCanChooseDirectories:NO];
    }

    // Resolve Aliases:
    if (lua_isboolean(L, 7) && lua_toboolean(L, 7)) {
        [panel setResolvesAliases:YES];
    }
    else {
        [panel setResolvesAliases:NO];
    }

    // Allows Multiple Selections:
    if (lua_isboolean(L, 5) && !lua_toboolean(L, 5)) {
        [panel setAllowsMultipleSelection:NO];
    }
    else {
        [panel setAllowsMultipleSelection:YES];
    }

    // Load the window and check to see when a button is clicked:
    NSInteger clicked = [panel runModal];

    // Counter used when multiple files can be selected:
    int count = 1;

    if (clicked == NSFileHandlingPanelOKButton) {
        lua_newtable(L);
        for (NSURL *url in [panel URLs]) {
            lua_pushstring(L,[[url absoluteString] UTF8String]); lua_setfield(L, -2, [[NSString stringWithFormat:@"%i", count] UTF8String]);
            count = count + 1;
        }
    }
    else
    {
        lua_pushnil(L);
    }

    return 1;
}

#pragma mark - Webview Alert

/// hs.dialog.webviewAlert(webview, callbackFn, message, [informativeText], [buttonOne], [buttonTwo], [style]) -> string
/// Function
/// Displays a simple dialog box using `NSAlert` in a `hs.webview`.
///
/// Parameters:
///  * webview - The `hs.webview` to display the alert on.
///  * callbackFn - The callback function that's called when a button is pressed.
///  * message - The message text to display.
///  * [informativeText] - Optional informative text to display.
///  * [buttonOne] - An optional value for the first button as a string. Defaults to "OK".
///  * [buttonTwo] - An optional value for the second button as a string. If `nil` is used, no second button will be displayed.
///  * [style] - An optional style of the dialog box as a string. Defaults to "warning".
///
/// Returns:
///  * nil
///
/// Notes:
///  * This alert is will prevent the user from interacting with the `hs.webview` until a button is pressed on the alert.
///  * The optional values must be entered in order (i.e. you can't supply `style` without also supplying `buttonOne` and `buttonTwo`).
///  * [style] can be "warning", "informational" or "critical". If something other than these string values is given, it will use "informational".
///  * Example:
///      ```testCallbackFn = function(result) print("Callback Result: " .. result) end
///      testWebviewA = hs.webview.newBrowser(hs.geometry.rect(250, 250, 250, 250)):show()
///      testWebviewB = hs.webview.newBrowser(hs.geometry.rect(450, 450, 450, 450)):show()
///      hs.dialog.webviewAlert(testWebviewA, testCallbackFn, "Message", "Informative Text", "Button One", "Button Two", "NSCriticalAlertStyle")
///      hs.dialog.webviewAlert(testWebviewB, testCallbackFn, "Message", "Informative Text", "Single Button")```
static int webviewAlert(lua_State *L) {

    NSString* defaultButton = @"OK";
    const NSAlertStyle defaultAlertStyle = NSInformationalAlertStyle;

    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, "hs.webview", LS_TFUNCTION, LS_TSTRING, LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];

    NSWindow *webview = [skin toNSObjectAtIndex:1];

    lua_pushvalue(L, 2) ; // Copy the callback function to the top of the stack
    int callbackRef = [skin luaRef:refTable] ; // Store what's at the top of the stack in the registry and save it's reference number. "luaRef" will pull off the top value of the stack, so the net effect of these two lines is to leave the stack of arguments as-is.

    NSString *message = [skin toNSObjectAtIndex:3];
    NSString *informativeText = [skin toNSObjectAtIndex:4];
    NSString *buttonOne = [skin toNSObjectAtIndex:5];
    NSString *buttonTwo = [skin toNSObjectAtIndex:6];
    NSString *style = [skin toNSObjectAtIndex:7];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];

    if (informativeText) {
        [alert setInformativeText:informativeText];
    }

    if( buttonOne == nil ){
        [alert addButtonWithTitle:defaultButton];
    }
    else
    {
        if ([buttonOne isEqualToString:@""]) {
            [alert addButtonWithTitle:defaultButton];
        }
        else
        {
            [alert addButtonWithTitle:buttonOne];
        }
    }

    if (buttonTwo != nil && ![buttonTwo isEqualToString:@""]) {
        [alert addButtonWithTitle:buttonTwo];
    }

    if (style == nil){
        [alert setAlertStyle:defaultAlertStyle];
    }
    else
    {
        if ([style isEqualToString:@"warning"]) {
            [alert setAlertStyle:NSWarningAlertStyle];
        }
        else if ([style isEqualToString:@"informational"]) {
            [alert setAlertStyle:NSInformationalAlertStyle];
        }
        else if ([style isEqualToString:@"critical"]) {
            [alert setAlertStyle:NSCriticalAlertStyle];
        }
        else
        {
            [alert setAlertStyle:defaultAlertStyle];
        }
    }

    [alert beginSheetModalForWindow:webview completionHandler:^(NSModalResponse result){

        NSString *button = defaultButton;

        if (result == NSAlertFirstButtonReturn) {
            if (buttonOne != nil) {
                button = buttonOne;
            }
        }
        else if (result == NSAlertSecondButtonReturn) {
            button = buttonTwo;
        }
        else
        {
            [LuaSkin logError:@"hs.dialog.webviewAlert() - Failed to detect which button was pressed."];
            lua_pushnil(L) ;
        }


        [skin pushLuaRef:refTable ref:callbackRef] ; // Put the saved function back on the stack.
        [skin luaUnref:refTable ref:callbackRef] ; // Remove the stored function from the registry.
        [skin pushNSObject:button];
        if (![skin protectedCallAndTraceback:1 nresults:0]) { // Returns NO on error, so we check if the result is !YES
            [skin logError:[NSString stringWithFormat:@"hs.dialog:callback error - %s", lua_tostring(L, -1)]]; // -1 indicates the top item of the stack, which will be an error message string in this case
            lua_pop(L, 1) ; // Remove the error from the stack to keep it clean
        }
    }] ;

    lua_pushnil(L) ;
    return 1 ;

}

#pragma mark - Blocking Alert

/// hs.dialog.blockAlert(message, informativeText, [buttonOne], [buttonTwo], [style]) -> string
/// Function
/// Displays a simple dialog box using `NSAlert` that will halt Lua code processing until the alert is closed.
///
/// Parameters:
///  * message - The message text to display.
///  * informativeText - The informative text to display.
///  * [buttonOne] - An optional value for the first button as a string. Defaults to "OK".
///  * [buttonTwo] - An optional value for the second button as a string. If `nil` is used, no second button will be displayed.
///  * [style] - An optional style of the dialog box as a string. Defaults to "NSWarningAlertStyle".
///
/// Returns:
///  * The value of the button as a string.
///
/// Notes:
///  * The optional values must be entered in order (i.e. you can't supply `style` without also supplying `buttonOne` and `buttonTwo`).
///  * [style] can be "NSWarningAlertStyle", "NSInformationalAlertStyle" or "NSCriticalAlertStyle". If something other than these string values is given, it will use "NSWarningAlertStyle".
///  * Example:
///      `hs.dialog.blockAlert("Message", "Informative Text", "Button One", "Button Two", "NSCriticalAlertStyle")`
static int blockAlert(lua_State *L) {

	NSString* defaultButton = @"OK";

 	LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];

    NSString* message = [skin toNSObjectAtIndex:1];
    NSString* informativeText = [skin toNSObjectAtIndex:2];
    NSString* buttonOne = [skin toNSObjectAtIndex:3];
    NSString* buttonTwo = [skin toNSObjectAtIndex:4];
    NSString* style = [skin toNSObjectAtIndex:5];

	NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert setInformativeText:informativeText];

    if( buttonOne == nil ){
        [alert addButtonWithTitle:defaultButton];
    }
    else
    {
        if ([buttonOne isEqualToString:@""]) {
            [alert addButtonWithTitle:defaultButton];
        }
        else
        {
            [alert addButtonWithTitle:buttonOne];
        }
    }

    if (buttonTwo != nil && ![buttonTwo isEqualToString:@""]) {
        [alert addButtonWithTitle:buttonTwo];
    }

	if (style == nil){
		[alert setAlertStyle:NSWarningAlertStyle];
	}
	else
	{
		if ([style isEqualToString:@"NSWarningAlertStyle"]) {
			[alert setAlertStyle:NSWarningAlertStyle];
		}
		else if ([style isEqualToString:@"NSInformationalAlertStyle"]) {
			[alert setAlertStyle:NSInformationalAlertStyle];
		}
		else if ([style isEqualToString:@"NSCriticalAlertStyle"]) {
			[alert setAlertStyle:NSCriticalAlertStyle];
		}
        else
        {
            [alert setAlertStyle:NSWarningAlertStyle];
        }
	}

	NSInteger result = [alert runModal];

	if (result == NSAlertFirstButtonReturn) {
		if (buttonOne == nil) {
			lua_pushstring(L,[defaultButton UTF8String]);
		}
		else
		{
			lua_pushvalue(L, 3);
		}
	}
	else if (result == NSAlertSecondButtonReturn) {
		lua_pushvalue(L, 4);
	}
	else
	{
        [LuaSkin logError:@"hs.dialog.alert() - Failed to detect which button was pressed."];
        lua_pushnil(L) ;
	}

	return 1 ;
}

#pragma mark - Text Prompt

/// hs.dialog.textPrompt(message, informativeText, [defaultText], [buttonOne], [buttonTwo]) -> string, string
/// Function
/// Displays a simple text input dialog box.
///
/// Parameters:
///  * message - The message text to display
///  * informativeText - The informative text to display
///  * [defaultText] - The informative text to display
///  * [buttonOne] - An optional value for the first button as a string
///  * [buttonTwo] - An optional value for the second button as a string
///
/// Returns:
///  * The value of the button as a string
///  * The value of the text input as a string
///
/// Notes:
///  * [buttonOne] defaults to "OK" if no value is supplied.
///  * Example:
///      `hs.dialog.textPrompt("Main message.", "Please enter something:", "Default Value", "Button One", "Button Two")`
static int textPrompt(lua_State *L) {
    NSString* defaultButton = @"OK";

    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];

    NSString* message = [skin toNSObjectAtIndex:1];
    NSString* informativeText = [skin toNSObjectAtIndex:2];
    NSString* defaultText = [skin toNSObjectAtIndex:3];
    NSString* buttonOne = [skin toNSObjectAtIndex:4];
    NSString* buttonTwo = [skin toNSObjectAtIndex:5];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert setInformativeText:informativeText];

    if( buttonOne == nil ){
        [alert addButtonWithTitle:defaultButton];
    }
    else
    {
        if ([buttonOne isEqualToString:@""]) {
            [alert addButtonWithTitle:defaultButton];
        }
        else
        {
            [alert addButtonWithTitle:buttonOne];
        }
    }

    if (buttonTwo != nil && ![buttonTwo isEqualToString:@""]) {
        [alert addButtonWithTitle:buttonTwo];
    }

    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    if (defaultText == nil) {
        [input setStringValue:@""];
    }
    else
    {
        [input setStringValue:defaultText];
    }

    [alert setAccessoryView:input];

    NSInteger result = [alert runModal];

    if (result == NSAlertFirstButtonReturn) {
        if (buttonOne == nil) {
            lua_pushstring(L,[defaultButton UTF8String]);
            lua_pushstring(L, [[input stringValue] UTF8String]);
        }
        else
        {
            lua_pushvalue(L, 4);
            lua_pushstring(L, [[input stringValue] UTF8String]);
        }
    }
    else if (result == NSAlertSecondButtonReturn) {
        lua_pushvalue(L, 5);
        lua_pushstring(L, [[input stringValue] UTF8String]);
    }
    else
    {
        [LuaSkin logError:@"hs.dialog.textPrompt() - Failed to detect which button was pressed."];
        lua_pushnil(L) ;
    }

    return 2 ;
}

#pragma mark - Module Constants

/// hs.dialog.font.panelModes
/// Constant
/// This table contains this list of defined modes for the font panel.
static int pushFontPanelTypes(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSFontPanelFaceModeMask) ;                lua_setfield(L, -2, "face") ;
    lua_pushinteger(L, NSFontPanelSizeModeMask) ;                lua_setfield(L, -2, "size") ;
    lua_pushinteger(L, NSFontPanelCollectionModeMask) ;          lua_setfield(L, -2, "collection") ;
    lua_pushinteger(L, NSFontPanelUnderlineEffectModeMask) ;     lua_setfield(L, -2, "underlineEffect") ;
    lua_pushinteger(L, NSFontPanelStrikethroughEffectModeMask) ; lua_setfield(L, -2, "strikethroughEffect") ;
    lua_pushinteger(L, NSFontPanelTextColorEffectModeMask) ;     lua_setfield(L, -2, "textColorEffect") ;
    lua_pushinteger(L, NSFontPanelDocumentColorEffectModeMask) ; lua_setfield(L, -2, "documentColorEffect") ;
    lua_pushinteger(L, NSFontPanelShadowEffectModeMask) ;        lua_setfield(L, -2, "shadowEffect") ;
    lua_pushinteger(L, NSFontPanelAllEffectsModeMask) ;          lua_setfield(L, -2, "allEffects") ;
    lua_pushinteger(L, NSFontPanelStandardModesMask) ;           lua_setfield(L, -2, "standard") ;
    lua_pushinteger(L, NSFontPanelAllModesMask) ;                lua_setfield(L, -2, "allModes") ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int releaseReceivers(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSColorPanel *cp = [NSColorPanel sharedColorPanel];
    [[NSNotificationCenter defaultCenter] removeObserver:cpReceiverObject
                                                    name:NSWindowWillCloseNotification
                                                  object:cp] ;
    [cp setTarget:nil];
    [cp setAction:nil];
    if (cpReceiverObject.callbackRef != LUA_NOREF) [skin luaUnref:refTable ref:cpReceiverObject.callbackRef] ;
    [cp close];
    cpReceiverObject = nil ;

    NSFontPanel *fp = [NSFontPanel sharedFontPanel];
    NSFontManager *fm = [NSFontManager sharedFontManager];
    [[NSNotificationCenter defaultCenter] removeObserver:fpReceiverObject
                                                    name:NSWindowWillCloseNotification
                                                  object:fp] ;
    if (fpReceiverObject.callbackRef != LUA_NOREF) [skin luaUnref:refTable ref:fpReceiverObject.callbackRef] ;
    [fm setTarget:nil] ;
    fpReceiverObject = nil ;
    return 0 ;
}

// Functions for returned object when module loads:
static luaL_Reg moduleLib[] = {
    {"webviewAlert", webviewAlert},
    {"blockAlert", blockAlert},
    {"textPrompt", textPrompt},
    {"chooseFileOrFolder", chooseFileOrFolder},
    {NULL,  NULL}
};

static luaL_Reg colorPanelLib[] = {
    {"alpha",      colorPanelAlpha},
    {"callback",   colorPanelCallback},
    {"color",      colorPanelColor},
    {"continuous", colorPanelContinuous},
    {"mode",       colorPanelMode},
    {"showsAlpha", colorPanelShowsAlpha},
    {"show",       colorPanelShow},
    {"hide",       colorPanelHide},
    {NULL,         NULL}
};

static luaL_Reg fontPanelLib[] = {
    {"show",     fontPanelShow},
    {"hide",     fontPanelHide},
    {"callback", fontPanelCallback},
    {"mode",     fontPanelMode},
    {NULL,   NULL}
};

static luaL_Reg module_metaLib[] = {
    {"__gc", releaseReceivers},
    {NULL,   NULL}
};

int luaopen_hs_dialog_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
	refTable = [skin registerLibrary:moduleLib metaFunctions:module_metaLib] ;

    luaL_newlib(L, colorPanelLib) ; lua_setfield(L, -2, "color") ;
    [NSColorPanel setPickerMask:NSColorPanelAllModesMask] ;
    cpReceiverObject = [[HSColorPanel alloc] init] ;
    fpReceiverObject = [[HSFontPanel alloc] init] ;
    luaL_newlib(L, fontPanelLib) ;
    pushFontPanelTypes(L) ; lua_setfield(L, -2, "panelModes") ;
    lua_setfield(L, -2, "font") ;

    return 1;
}

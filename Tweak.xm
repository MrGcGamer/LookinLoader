#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <mach/mach.h>
#import "CoreSymbolication.h"

NSString* nameForLocalSymbol(NSNumber* addrNum, uint64_t* outOffset)
{
    NSString* name = nil;
    void* symAddr = (void*)[addrNum unsignedLongLongValue];
    Dl_info info = { NULL, NULL, NULL, NULL };
    int success = dladdr(symAddr, &info);
    if (symAddr && success)
    {
        CSSymbolicatorRef symbolicator = CSSymbolicatorCreateWithTask(mach_task_self());
        if (!CSIsNull(symbolicator))
        {
            CSSymbolOwnerRef owner = CSSymbolicatorGetSymbolOwnerWithAddressAtTime(symbolicator, (vm_address_t)symAddr, kCSNow);
            if (!CSIsNull(owner))
            {
                uint64_t imgAddr = (uint64_t)info.dli_fbase;
                if (outOffset) *outOffset = (uint64_t)symAddr - imgAddr;
                CSSymbolRef symbol = CSSymbolOwnerGetSymbolWithAddress(owner, (mach_vm_address_t)symAddr);
                if (!CSIsNull(symbol))
                {
                    const char* c_name = CSSymbolGetName(symbol);
                    if (c_name)
                        name = [NSString stringWithUTF8String:c_name];
                    else
                        name = [NSString stringWithFormat:@"func_%llx", CSSymbolGetRange(symbol).location - imgAddr];
                }
            }
            CSRelease(symbolicator);
        }
    }
    return name;
}

NSArray* symbolicatedStackSymbols(NSArray* callStackSymbols, NSArray* callStackReturnAddresses)
{
    NSMutableArray* symArr = [callStackSymbols mutableCopy];
    for (uint32_t i = 0; i < callStackSymbols.count; i++)
    {
        uint64_t offset = 0;
        NSString* symName = nameForLocalSymbol(callStackReturnAddresses[i], &offset);
        if (symName && symName.length)
        {
            NSMutableArray<NSString*>* components = [[symArr[i] componentsSeparatedByString:@" "] mutableCopy];
            NSMutableArray<NSString*>* newComponents = [[NSMutableArray alloc] initWithCapacity:3];
            for (uint32_t b = 0; b < components.count; b++)
            {
                if (components[b].length)
                {
                    [newComponents addObject:components[b]];
                    if (newComponents.count >= 3)
                        break;
                }
            }
            if (newComponents.count < 3)
                continue;
            NSString* newSym = [newComponents[0] stringByPaddingToLength:4 withString:@" " startingAtIndex:0];
            newSym = [newSym stringByAppendingString:newComponents[1]];
            newSym = [newSym stringByPaddingToLength:40 withString:@" " startingAtIndex:0];
            newSym = [newSym stringByAppendingString:newComponents[2]];
            NSUInteger padding = newSym.length + 30;
            newSym = [NSString stringWithFormat:@"%@ 0x%llx + 0x%llx", newSym, [callStackReturnAddresses[i] unsignedLongLongValue] - offset, offset];
            newSym = [newSym stringByPaddingToLength:padding withString:@" " startingAtIndex:0];
            if (symName)
                newSym = [newSym stringByAppendingFormat:@" // %@", symName];
            symArr[i] = newSym;
        }
    }
    return symArr;
}

@interface _UIStatusBarForegroundView : UIView
@end

%group UIDebug

%hook _UIStatusBarForegroundView

- (id)initWithFrame:(CGRect)arg1 {

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showAlert:)];
    
    tapGesture.numberOfTapsRequired = 2;

    [self addGestureRecognizer:tapGesture];

    return %orig;

}

%new 

- (void)showAlert:(UITapGestureRecognizer *)sender {

    if (sender.state == UIGestureRecognizerStateEnded) {

        UIAlertView *alertView = [[UIAlertView alloc] init];
        alertView.delegate = self;
        alertView.tag = 0;
        alertView.title = @"Lookin UIDebug";
        [alertView addButtonWithTitle:@"2D Inspection"];
        [alertView addButtonWithTitle:@"3D Inspection"];
        [alertView addButtonWithTitle:@"Export"];
        [alertView addButtonWithTitle:@"Cancel"];
        [alertView show];

    }

}

%new

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    if (alertView.tag == 0) {
        
        if (buttonIndex == 0) {

			[[NSNotificationCenter defaultCenter] postNotificationName:@"Lookin_2D" object:nil];
       
        } else if (buttonIndex == 1) {
			
            [[NSNotificationCenter defaultCenter] postNotificationName:@"Lookin_3D" object:nil];
        
        } else if (buttonIndex == 2) {

        	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			
				[[NSNotificationCenter defaultCenter] postNotificationName:@"Lookin_Export" object:nil];
			
            });

        }

    }

}

%end

@interface LookinMethodTraceRecord : NSObject <NSSecureCoding>
@property(nonatomic, copy) NSString *targetAddress;
@property(nonatomic, copy) NSString *selClassName;
@property(nonatomic, copy) NSString *selName;
@property(nonatomic, copy) NSArray<NSString *> *args;
@property(nonatomic, copy) NSArray<NSString *> *callStacks;
@property(nonatomic, strong) NSDate *date;

@property(nonatomic, copy, readonly) NSString *combinedTitle;
- (NSArray *)briefFormattedCallStacks;
- (NSArray *)completeFormattedCallStacks;
@end

%hook LookinMethodTraceRecord
    - (void)setCallStacks:(NSArray *)rawCallStacks {
        NSArray *callStackSymbols = [NSThread callStackSymbols];
        NSArray *callStackReturnAddresses = [NSThread callStackReturnAddresses];

        NSArray *symbolicatedCallStacks = symbolicatedStackSymbols(callStackSymbols, callStackReturnAddresses);

        %orig(symbolicatedCallStacks);
    }

%end

%end

%ctor {
	
	NSFileManager* fileManager = [NSFileManager defaultManager];

	NSString* libPath = @"/usr/lib/Lookin/LookinServer.framework/LookinServer";

	if ([fileManager fileExistsAtPath:libPath]) {

		void *lib = dlopen([libPath UTF8String], RTLD_NOW);
		
		if (lib) {

			%init(UIDebug)

			NSLog(@"[+] LookinLoader loaded!");

		} else {
			
			char* err = dlerror();
			
			NSLog(@"[+] LookinLoader load failed:%s", err);
		}
	
	}

}

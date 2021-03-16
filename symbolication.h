#import "CoreSymbolication.h"

extern NSString* nameForLocalSymbol(NSNumber* addrNum, uint64_t* outOffset);
extern NSArray* symbolicatedStackSymbols(NSArray* callStackSymbols, NSArray* callStackReturnAddresses);
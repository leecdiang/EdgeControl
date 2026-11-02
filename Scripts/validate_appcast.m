#import <Foundation/Foundation.h>
#import <Sparkle/Sparkle.h>

// Release tooling only. Exercise the parser in the exact pinned Sparkle binary
// instead of treating well-formed XML as proof that an update feed is usable.
@interface SPUAppcastItemStateResolver : NSObject
- (instancetype)initWithHostVersion:(NSString *)version
      applicationVersionComparator:(id<SUVersionComparison>)comparator
          standardVersionComparator:(SUStandardVersionComparator *)standardComparator;
@end
@interface SUAppcast (ReleaseValidation)
- (instancetype)initWithXMLData:(NSData *)data relativeToURL:(NSURL *)url
                  stateResolver:(SPUAppcastItemStateResolver *)resolver
        signingValidationStatus:(SPUAppcastSigningValidationStatus)status error:(NSError **)error;
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) { fprintf(stderr, "Usage: validate_appcast feed.xml expected-latest-build\n"); return 2; }
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfFile:@(argv[1]) options:0 error:&error];
        if (!data) { fprintf(stderr, "%s\n", error.description.UTF8String); return 1; }
        SUStandardVersionComparator *comparator = [SUStandardVersionComparator defaultComparator];
        SPUAppcastItemStateResolver *resolver = [[SPUAppcastItemStateResolver alloc]
            initWithHostVersion:@"1" applicationVersionComparator:comparator standardVersionComparator:comparator];
        SUAppcast *feed = [[SUAppcast alloc] initWithXMLData:data relativeToURL:nil stateResolver:resolver
            signingValidationStatus:SPUAppcastSigningValidationStatusSkipped error:&error];
        if (!feed || feed.items.count == 0) {
            fprintf(stderr, "Sparkle rejected feed: %s\n", error.description.UTF8String ?: "empty feed"); return 1;
        }
        if (![feed.items.firstObject.versionString isEqualToString:@(argv[2])]) {
            fprintf(stderr, "Unexpected newest build: %s\n", feed.items.firstObject.versionString.UTF8String); return 1;
        }
        for (SUAppcastItem *item in feed.items) {
            printf("Sparkle parsed build %s (%s)\n", item.versionString.UTF8String, item.displayVersionString.UTF8String);
        }
        return 0;
    }
}

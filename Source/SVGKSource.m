#import "SVGKSource.h"
#import "SVGKSourceLocalFile.h"
#import "SVGKSourceURL.h"
#import "SVGKSourceData.h"

@interface SVGKSource ()
@property (readwrite, nonatomic, strong) NSInputStream* stream;
@end

@implementation SVGKSource

@synthesize svgLanguageVersion;
@synthesize stream;

- (id)initWithInputSteam:(NSInputStream*)s {
	self = [super init];
	if (!self)
		return nil;
	
	self.stream = s;
	return self;
}

+ (SVGKSource*)sourceFromFilename:(NSString*)p
{
	return [SVGKSourceLocalFile sourceFromFilename:p];
}

+ (SVGKSource*)sourceFromURL:(NSURL*)u
{
	return [SVGKSourceURL sourceFromURL:u];
}

+ (SVGKSource*)sourceFromData:(NSData*)data {
	return [SVGKSourceData sourceFromData:data];
}

+ (SVGKSource*)sourceFromContentsOfString:(NSString*)rawString {
	return [self sourceFromData:[rawString dataUsingEncoding:NSUTF8StringEncoding]];
}

- (id)copyWithZone:(NSZone *)zone
{
	DDLogError(@"[%@] ERROR: %s should be in a subclass!", [self class], sel_getName(_cmd));
	
	return nil;
}

@end

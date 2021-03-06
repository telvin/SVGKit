#import "SVGKFastImageView.h"
#include <tgmath.h>
#import "BlankSVG.h"

#define TEMPORARY_WARNING_FOR_APPLES_BROKEN_RENDERINCONTEXT_METHOD 1 // ONLY needed as temporary workaround for Apple's renderInContext bug breaking various bits of rendering: Gradients, Scaling, etc

#if TEMPORARY_WARNING_FOR_APPLES_BROKEN_RENDERINCONTEXT_METHOD
#import "SVGGradientElement.h"
#endif

@interface SVGKFastImageView ()
@property(nonatomic,readwrite) NSTimeInterval timeIntervalForLastReRenderOfSVGFromMemory;
@property (nonatomic, strong) NSDate* startRenderTime, * endRenderTime; /*< for debugging, lets you know how long it took to add/generate the CALayer (may have been cached! Only SVGKImage knows true times) */
@end

@implementation SVGKFastImageView
{
	NSString* internalContextPointerBecauseApplesDemandsIt;
}

@synthesize image = _image;
@synthesize tileRatio = _tileRatio;
@synthesize disableAutoRedrawAtHighestResolution = _disableAutoRedrawAtHighestResolution;
@synthesize timeIntervalForLastReRenderOfSVGFromMemory = _timeIntervalForLastReRenderOfSVGFromMemory;

#if TEMPORARY_WARNING_FOR_APPLES_BROKEN_RENDERINCONTEXT_METHOD
+(BOOL) svgImageHasNoGradients:(SVGKImage*) image
{
	return [self svgElementAndDescendentsHaveNoGradients:image.DOMTree];
}

+(BOOL) svgElementAndDescendentsHaveNoGradients:(SVGElement*) element
{
	if( [element isKindOfClass:[SVGGradientElement class]])
		return FALSE;
	else
	{
		for( SVGKNode* n in element.childNodes )
		{
			if( [n isKindOfClass:[SVGElement class]])
			{
				if( [self svgElementAndDescendentsHaveNoGradients:(SVGElement*)n])
					;
				else
					return FALSE;
			}
				
		}
	}
	
	return TRUE;
}
#endif

- (instancetype)init
{
	NSAssert(false, @"init not supported, use initWithSVGKImage:");
    
    return nil;
}

- (void)generateObservers
{
    /** other obeservers */
    [self addObserver:self forKeyPath:@"image" options:NSKeyValueObservingOptionNew context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
    [self addObserver:self forKeyPath:@"tileRatio" options:NSKeyValueObservingOptionNew context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
    [self addObserver:self forKeyPath:@"showBorder" options:NSKeyValueObservingOptionNew context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
    if( self )
    {
		self.backgroundColor = [UIColor clearColor];
        [self populateFromImage:nil];
        [self generateObservers];
    }
    return self;
}

-(instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if( self )
	{
		self.backgroundColor = [UIColor clearColor];
        [self populateFromImage:nil];
        [self generateObservers];
	}
	return self;
}

- (instancetype)initWithSVGKImage:(SVGKImage*) im
{
    self = [super init];
    if (self)
	{
		// Remove the old, internal redraw observers, because the populateFromImage will add them back in.
		[self removeInternalRedrawOnResizeObservers];

        [self populateFromImage:im];
        // Not generating observers here, as they should have been generated when the UIView superclass called initWithFrame
    }
    return self;
}

- (void)populateFromImage:(SVGKImage*) im
{
	if( im == nil )
	{
		SVGKitLogWarn(@"[%@] WARNING: you have initialized an SVGKImageView with a blank image (nil). Possibly because you're using Storyboards or NIBs which Apple won't allow us to decorate. Make sure you assign an SVGKImage to the .image property!", [self class]);
		SVGKitLogInfo(@"[%@] Using default SVG: %@", [self class], SVGKGetDefaultImageStringContents());
		im = [SVGKImage defaultImage];
	}
    
    self.image = im;
    self.frame = CGRectMake( 0,0, im.size.width, im.size.height ); // NB: this uses the default SVG Viewport; an ImageView can theoretically calc a new viewport (but its hard to get right!)
    self.tileRatio = CGSizeZero;
    self.backgroundColor = [UIColor clearColor];
}

- (void)setImage:(SVGKImage *)image {
	
#if TEMPORARY_WARNING_FOR_APPLES_BROKEN_RENDERINCONTEXT_METHOD
	BOOL imageIsGradientFree = [SVGKFastImageView svgImageHasNoGradients:image];
	if( !imageIsGradientFree )
		SVGKitLogWarn(@"[%@] WARNING: Apple's rendering DOES NOT ALLOW US to render this image correctly using SVGKFastImageView, because Apple's renderInContext method - according to Apple's docs - ignores Apple's own masking layers. Until Apple fixes this bug, you should use SVGKLayeredImageView for this particular SVG file (or avoid using gradients)", [self class]);
	
	if( image.scale != 0.0f )
		SVGKitLogWarn(@"[%@] WARNING: Apple's rendering DOES NOT ALLOW US to render this image correctly using SVGKFastImageView, because Apple's renderInContext method - according to Apple's docs - ignores Apple's own transforms. Until Apple fixes this bug, you should use SVGKLayeredImageView for this particular SVG file (or avoid using scale: you SHOULD INSTEAD be scaling by setting .size on the image, and ensuring that the incoming SVG has either a viewbox or an explicit svg width or svg height)", [self class]);
#endif
    
    if( !internalContextPointerBecauseApplesDemandsIt ) {
        internalContextPointerBecauseApplesDemandsIt = @"Apple wrote the addObserver / KVO notification API wrong in the first place and now requires developers to pass around pointers to fake objects to make up for the API deficicineces. You have to have one of these pointers per object, and they have to be internal and private. They serve no real value.";
    }
	
    if (_image) {
        [_image removeObserver:self forKeyPath:@"size" context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
    }
    _image = image;
    
    /** redraw-observers */
    if( self.disableAutoRedrawAtHighestResolution )
        ;
    else {
        [self addInternalRedrawOnResizeObservers];
        [_image addObserver:self forKeyPath:@"size" options:NSKeyValueObservingOptionNew context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
    }
    
    /** other obeservers */
    [self addObserver:self forKeyPath:@"image" options:NSKeyValueObservingOptionNew context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
    [self addObserver:self forKeyPath:@"tileRatio" options:NSKeyValueObservingOptionNew context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
    [self addObserver:self forKeyPath:@"showBorder" options:NSKeyValueObservingOptionNew context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
}

-(void) addInternalRedrawOnResizeObservers
{
	[self addObserver:self forKeyPath:@"layer" options:NSKeyValueObservingOptionNew context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
	[self.layer addObserver:self forKeyPath:@"transform" options:NSKeyValueObservingOptionNew context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
	//[self.image addObserver:self forKeyPath:@"size" options:NSKeyValueObservingOptionNew context:internalContextPointerBecauseApplesDemandsIt];
}

-(void) removeInternalRedrawOnResizeObservers
{
	[self removeObserver:self  forKeyPath:@"layer" context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
	[self.layer removeObserver:self forKeyPath:@"transform" context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
	//[self.image removeObserver:self forKeyPath:@"size" context:internalContextPointerBecauseApplesDemandsIt];
}

-(void)setDisableAutoRedrawAtHighestResolution:(BOOL)newValue
{
	if( newValue == _disableAutoRedrawAtHighestResolution )
		return;
	
	_disableAutoRedrawAtHighestResolution = newValue;
	
	if( self.disableAutoRedrawAtHighestResolution ) // disabled, so we have to remove the observers
	{
		[self removeInternalRedrawOnResizeObservers];
	}
	else // newly-enabled ... must add the observers
	{
		[self addInternalRedrawOnResizeObservers];
	}
}

- (void)dealloc
{
	if( self.disableAutoRedrawAtHighestResolution )
		;
	else
		[self removeInternalRedrawOnResizeObservers];
	
	[self removeObserver:self forKeyPath:@"image" context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
	[self removeObserver:self forKeyPath:@"tileRatio" context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
	[self removeObserver:self forKeyPath:@"showBorder" context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
	
	if (_image) {
		[_image removeObserver:self forKeyPath:@"size" context:(__bridge void *)(internalContextPointerBecauseApplesDemandsIt)];
	}
	
	_image = nil;
}

/** Trigger a call to re-display (at higher or lower draw-resolution) (get Apple to call drawRect: again) */
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if( [keyPath isEqualToString:@"transform"] &&  CGSizeEqualToSize( CGSizeZero, self.tileRatio ) )
	{
		/*SVGKitLogVerbose(@"transform changed. Setting layer scale: %2.2f --> %2.2f", self.layer.contentsScale, self.transform.a);
		 self.layer.contentsScale = self.transform.a;*/
		[self.image.CALayerTree removeFromSuperlayer]; // force apple to redraw?
		[self setNeedsDisplay];
	}
	else
	{
		
		if( self.disableAutoRedrawAtHighestResolution )
			;
		else
		{
			[self setNeedsDisplay];
		}
	}
}

/**
 NB: this implementation is a bit tricky, because we're extending Apple's concept of a UIView to add "tiling"
 and "automatic rescaling"
 
 */
-(void)drawRect:(CGRect)rect
{
	self.startRenderTime = self.endRenderTime = [NSDate date];
	
	/**
	 view.bounds == width and height of the view
	 imageBounds == natural width and height of the SVGKImage
	 */
	CGRect imageBounds = CGRectMake( 0,0, self.image.size.width, self.image.size.height );
	
	
	/** Check if tiling is enabled in either direction
	 
	 We have to do this FIRST, because we cannot extend Apple's enum they use for UIViewContentMode
	 (objective-C is a weak language).
	 
	 If we find ANY tiling, we will be forced to skip the UIViewContentMode handling
	 
	 TODO: it would be nice to combine the two - e.g. if contentMode=BottomRight, then do the tiling with
	 the bottom right corners aligned. If = TopLeft, then tile with the top left corners aligned,
	 etc.
	 */
	int cols = ceil(self.tileRatio.width);
	int rows = ceil(self.tileRatio.height);
	
	if( cols < 1 ) // It's meaningless to have "fewer than 1" tiles; this lets us ALSO handle special case of "CGSizeZero == disable tiling"
		cols = 1;
	if( rows < 1 ) // It's meaningless to have "fewer than 1" tiles; this lets us ALSO handle special case of "CGSizeZero == disable tiling"
		rows = 1;
	
	
	CGSize scaleConvertImageToView;
	CGSize tileSize;
	if( cols == 1 && rows == 1 ) // if we are NOT tiling, then obey the UIViewContentMode as best we can!
	{
#ifdef USE_SUBLAYERS_INSTEAD_OF_BLIT
		if( self.image.CALayerTree.superlayer == self.layer )
		{
			[super drawRect:rect];
			return; // TODO: Apple's bugs - they ignore all attempts to force a redraw
		}
		else
		{
			[self.layer addSublayer:self.image.CALayerTree];
			return; // we've added the layer - let Apple take care of the rest!
		}
#else
		scaleConvertImageToView = CGSizeMake( self.bounds.size.width / imageBounds.size.width, self.bounds.size.height / imageBounds.size.height );
		tileSize = self.bounds.size;
#endif
	}
	else
	{
		scaleConvertImageToView = CGSizeMake( self.bounds.size.width / (self.tileRatio.width * imageBounds.size.width), self.bounds.size.height / ( self.tileRatio.height * imageBounds.size.height) );
		tileSize = CGSizeMake( self.bounds.size.width / self.tileRatio.width, self.bounds.size.height / self.tileRatio.height );
	}
	
	//DEBUG: SVGKitLogVerbose(@"cols, rows: %i, %i ... scaleConvert: %@ ... tilesize: %@", cols, rows, NSStringFromCGSize(scaleConvertImageToView), NSStringFromCGSize(tileSize) );
	/** To support tiling, and to allow internal shrinking, we use renderInContext */
	CGContextRef context = UIGraphicsGetCurrentContext();
	for( int k=0; k<rows; k++ )
		for( int i=0; i<cols; i++ )
		{
			CGContextSaveGState(context);
			
			CGContextTranslateCTM(context, i * tileSize.width, k * tileSize.height );
			CGContextScaleCTM( context, scaleConvertImageToView.width, scaleConvertImageToView.height );
			
			[self.image.CALayerTree renderInContext:context];
			
			CGContextRestoreGState(context);
		}
	
	/** The border is VERY helpful when debugging rendering and touch / hit detection problems! */
	if( self.showBorder )
	{
		[[UIColor blackColor] set];
		CGContextStrokeRect(context, rect);
	}
	
	self.endRenderTime = [NSDate date];
	self.timeIntervalForLastReRenderOfSVGFromMemory = [self.endRenderTime timeIntervalSinceDate:self.startRenderTime];
}

@end

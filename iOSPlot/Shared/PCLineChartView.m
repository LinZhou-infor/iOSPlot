/**
 * Copyright (c) 2011 Muh Hon Cheng
 * Created by honcheng on 28/4/11.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject
 * to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT
 * WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR
 * PURPOSE AND NONINFRINGEMENT. IN NO EVENT
 * SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR
 * IN CONNECTION WITH THE SOFTWARE OR
 * THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * @author 		Muh Hon Cheng <honcheng@gmail.com>
 * @copyright	2011	Muh Hon Cheng
 * @version
 *
 */

#define VERTICAL_TOP_MARGIN     35
#define VERTICAL_BOTTOM_MARGIN  25
#define HORIZONTAL_MARGIN       45
#define X_AXIS_TEXT_HEIGHT      20
#define TOUCHABLE_DIAMETER      40

#import "PCLineChartView.h"

@interface PCLineChartViewComponent ()
// a helper private property used in user interaction calculation
// contains NSValue objects that wrap CGRect struct
@property (nonatomic, strong) NSMutableArray *pointLocationsInView;
@end

@implementation PCLineChartViewComponent

- (id)init {
	self = [super init];
	if (self) {
		_labelFormat = @"%.1f%%";
        _pointLocationsInView = [NSMutableArray arrayWithCapacity:20];
	}
	return self;
}

@end

@implementation PCLineChartView
{
    float scale_min, scale_max;
    // all these instance fields are for user interaction
    BOOL touchMoved;
    PCLineChartViewComponent *currentSelectedComponent;
    NSInteger currentSelectedPointIndex;
    CGPoint touchInitialLocation;
    int initialValue;
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		[self setBackgroundColor:[UIColor clearColor]];
		_interval = 20;
		_maxValue = 100;
		_minValue = 0;
		_yLabelFont = [UIFont boldSystemFontOfSize:14];
		_xLabelFont = [UIFont boldSystemFontOfSize:12];
		_valueLabelFont = [UIFont boldSystemFontOfSize:10];
		_legendFont = [UIFont boldSystemFontOfSize:10];
		_numYIntervals = 5;
		_numXIntervals = 1;
		_yLabelAlignment = NSTextAlignmentRight;
        _dragType = LineChartDragTypeNone;
	}
	return self;
}

- (void)drawRect:(CGRect)rect {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	UIGraphicsPushContext(ctx);
	CGContextSetRGBFillColor(ctx, 0.2f, 0.2f, 0.2f, 1.0f);

	int n_div;
	int power;
	float div_height;
	float top_margin = VERTICAL_TOP_MARGIN;
	float bottom_margin = VERTICAL_BOTTOM_MARGIN;
	float x_label_height = X_AXIS_TEXT_HEIGHT;

	if (self.autoscaleYAxis) {
		scale_min = 0.0;
		power = floor(log10(self.maxValue/5));
		float increment = self.maxValue / (5 * pow(10,power));
		increment = (increment <= 5) ? ceil(increment) : 10;
		increment = increment * pow(10,power);
		scale_max = 5 * increment;
		self.interval = scale_max / self.numYIntervals;
	} else {
		scale_min = self.minValue;
		scale_max = self.maxValue;
	}
    
    // start to draw horizontal grid lines
	n_div = (scale_max-scale_min)/self.interval + 1;
	div_height = (self.frame.size.height-top_margin-bottom_margin-x_label_height)/(n_div-1);

	for (int i=0; i<n_div; i++) {
		float y_axis = scale_max - i*self.interval;

		int y = top_margin + div_height*i;
		CGRect textFrame = CGRectMake(0,y-8,25,20);

		NSString *formatString = [NSString stringWithFormat:@"%%.%if", (power < 0) ? -power : 0];
		NSString *text;
		if (self.mappedYLabels != nil) {
			NSUInteger key = [[NSString stringWithFormat:formatString, y_axis] integerValue];
			text = [self.mappedYLabels objectForKey:[NSNumber numberWithInteger:key]];
		} else {
			text = [NSString stringWithFormat:formatString, y_axis];
		}
		[text drawInRect:textFrame
                withFont:self.yLabelFont
           lineBreakMode:NSLineBreakByWordWrapping
               alignment:self.yLabelAlignment];

		// These are "grid" lines
		CGContextSetLineWidth(ctx, 1);
		CGContextSetRGBStrokeColor(ctx, 0.4f, 0.4f, 0.4f, 0.1f);
		CGContextMoveToPoint(ctx, 30, y);
		CGContextAddLineToPoint(ctx, self.frame.size.width-30, y);
		CGContextStrokePath(ctx);
	}
    // end of drawing horizontal grid lines
    
    // start to draw x axis
	float margin = HORIZONTAL_MARGIN;
	float div_width;
	if ([self.xLabels count] == 1) {
		div_width = 0;
	} else {
		div_width = (self.frame.size.width-2*margin)/([self.xLabels count]-1);
	}

	for (NSUInteger i=0; i<[self.xLabels count]; i++) {
		if (i % self.numXIntervals == 1 || self.numXIntervals==1) {
			int x = (int) (margin + div_width * i);
            BOOL shouldShowXLable = YES;
            NSString *xLabel = [self.xLabels objectAtIndex:i];
            if ([self.visibleXLables count] && ![self.visibleXLables containsObject:xLabel]) {
                shouldShowXLable = NO;
            }
            
            if (shouldShowXLable) {
                NSString *x_label = [NSString stringWithFormat:@"%@", [self.xLabels objectAtIndex:i]];
                CGRect textFrame = CGRectMake(x - 100, self.frame.size.height - x_label_height, 200, x_label_height);
                [x_label drawInRect:textFrame
                           withFont:self.xLabelFont
                      lineBreakMode:NSLineBreakByWordWrapping
                          alignment:NSTextAlignmentCenter];
            }
		};
	}
    // end of drawing x axis
    
    // there's no main x axis and y axis
    // just a reminder
    
    // set shadow for the lines in chart
	CGColorRef shadowColor = [[UIColor lightGrayColor] CGColor];
	CGContextSetShadowWithColor(ctx, CGSizeMake(0,-1), 1, shadowColor);

	NSMutableArray *legends = [NSMutableArray array];

	float circle_diameter = 10;
	float circle_stroke_width = 3;
	float line_width = 4;

	for (PCLineChartViewComponent *component in self.components) {
		int last_x = 0;
		int last_y = 0;

		if (!component.colour) {
			component.colour = PCColorBlue;
		}

		for (int x_axis_index=0; x_axis_index<[component.points count]; x_axis_index++) {
			id object = [component.points objectAtIndex:x_axis_index];

			if (object!=[NSNull null] && object) {
				float value = [object floatValue];

				CGContextSetStrokeColorWithColor(ctx, [component.colour CGColor]);
				CGContextSetLineWidth(ctx, circle_stroke_width);

				int x = margin + div_width*x_axis_index;
				int y = top_margin + (scale_max-value)/self.interval*div_height;

				CGRect circleRect = CGRectMake(x-circle_diameter/2, y-circle_diameter/2, circle_diameter,circle_diameter);
				CGContextStrokeEllipseInRect(ctx, circleRect);

                CGRect circleTouchableRect = CGRectMake(x-TOUCHABLE_DIAMETER/2, y-TOUCHABLE_DIAMETER/2, TOUCHABLE_DIAMETER, TOUCHABLE_DIAMETER);
                NSValue *rectValue = [NSValue valueWithCGRect:circleTouchableRect];
                if ([component.pointLocationsInView count]<=x_axis_index) {
                    [component.pointLocationsInView addObject:rectValue];
                }else{
                    [component.pointLocationsInView replaceObjectAtIndex:x_axis_index withObject:rectValue];
                }
                
				CGContextSetFillColorWithColor(ctx, [component.colour CGColor]);

				if (last_x!=0 && last_y!=0) {
					float distance = sqrt( pow(x-last_x, 2) + pow(y-last_y,2) );
					float last_x1 = last_x + (circle_diameter/2) / distance * (x-last_x);
					float last_y1 = last_y + (circle_diameter/2) / distance * (y-last_y);
					float x1 = x - (circle_diameter/2) / distance * (x-last_x);
					float y1 = y - (circle_diameter/2) / distance * (y-last_y);

					CGContextSetLineWidth(ctx, line_width);
					CGContextMoveToPoint(ctx, last_x1, last_y1);
					CGContextAddLineToPoint(ctx, x1, y1);
					CGContextStrokePath(ctx);
				}


				if (x_axis_index==[component.points count]-1) {
					NSMutableDictionary *info = [NSMutableDictionary dictionary];
					if (component.title) {
						[info setObject:component.title forKey:@"title"];
					}
					[info setObject:[NSNumber numberWithFloat:x+circle_diameter/2+15] forKey:@"x"];
					[info setObject:[NSNumber numberWithFloat:y-10] forKey:@"y"];
					[info setObject:component.colour forKey:@"colour"];
					[legends addObject:info];
				}

				last_x = x;
				last_y = y;
			}
		}
	}

	for (int i=0; i<[self.xLabels count]; i++) {
		int y_level = top_margin;

		for (int j=0; j<[self.components count]; j++) {
			NSArray *items = [[self.components objectAtIndex:j] points];
			id object = [items objectAtIndex:i];
			if (object!=[NSNull null] && object) {
				float value = [object floatValue];
				int x = margin + div_width*i;
				int y = top_margin + (scale_max-value)/self.interval*div_height;
				int y1 = y - circle_diameter/2 - self.valueLabelFont.pointSize;
				int y2 = y + circle_diameter/2;

				if ([[self.components objectAtIndex:j] shouldLabelValues]) {
					if (y1 > y_level) {
						CGContextSetRGBFillColor(ctx, 0.0f, 0.0f, 0.0f, 1.0f);
						NSString *perc_label = [NSString stringWithFormat:[[self.components objectAtIndex:j] labelFormat], value];
						CGRect textFrame = CGRectMake(x-25,y1, 50,20);
						[perc_label drawInRect:textFrame
													withFont:self.valueLabelFont
										 lineBreakMode:NSLineBreakByWordWrapping
												 alignment:NSTextAlignmentCenter];
						y_level = y1 + 20;
					}
					else if (y2 < y_level+20 && y2 < self.frame.size.height-top_margin-bottom_margin) {
						CGContextSetRGBFillColor(ctx, 0.0f, 0.0f, 0.0f, 1.0f);
						NSString *perc_label = [NSString stringWithFormat:[[self.components objectAtIndex:j] labelFormat], value];
						CGRect textFrame = CGRectMake(x-25,y2, 50,20);
						[perc_label drawInRect:textFrame
													withFont:self.valueLabelFont
										 lineBreakMode:NSLineBreakByWordWrapping
												 alignment:NSTextAlignmentCenter];
						y_level = y2 + 20;
					}
					else {
						CGContextSetRGBFillColor(ctx, 0.0f, 0.0f, 0.0f, 1.0f);
						NSString *perc_label = [NSString stringWithFormat:[[self.components objectAtIndex:j] labelFormat], value];
						CGRect textFrame = CGRectMake(x-50,y-10, 50,20);
						[perc_label drawInRect:textFrame
													withFont:self.valueLabelFont
										 lineBreakMode:NSLineBreakByWordWrapping
												 alignment:NSTextAlignmentCenter];
						y_level = y1 + 20;
					}
				}
				if (y+circle_diameter/2>y_level) y_level = y+circle_diameter/2;
			}
		}
	}

	NSSortDescriptor *sortDesc = [NSSortDescriptor sortDescriptorWithKey:@"y" ascending:YES];
	[legends sortUsingDescriptors:[NSArray arrayWithObject:sortDesc]];
	
	//CGContextSetRGBFillColor(ctx, 0.0f, 0.0f, 0.0f, 1.0f);
	float y_level = 0;
	for (NSMutableDictionary *legend in legends) {
		UIColor *colour = [legend objectForKey:@"colour"];
		CGContextSetFillColorWithColor(ctx, [colour CGColor]);

		NSString *title = [legend objectForKey:@"title"];
		float x = [[legend objectForKey:@"x"] floatValue];
		float y = [[legend objectForKey:@"y"] floatValue];
		if (y<y_level) {
			y = y_level;
		}

		CGRect textFrame = CGRectMake(x,y,margin,15);
		[title drawInRect:textFrame withFont:self.legendFont];

		y_level = y + 15;
	}
}

#pragma mark - UIResponder Methods

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    touchMoved = NO;
    if (_dragType == LineChartDragTypeVertical) {
        currentSelectedComponent = nil;
        currentSelectedPointIndex = NSNotFound;
        
        CGPoint point = [[touches anyObject] locationInView:self];
        for (PCLineChartViewComponent *component in self.components) {
            for (int i=0; i<[component.pointLocationsInView count];i++) {
                NSValue *value = [component.pointLocationsInView objectAtIndex:i];
                CGRect touchRect = [value CGRectValue];
                if (CGRectContainsPoint(touchRect, point)) {
                    currentSelectedComponent = component;
                    currentSelectedPointIndex = i;
                    touchInitialLocation = point;                    
                    initialValue = [[component.points objectAtIndex:i] intValue];
                }
            }
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    touchMoved = YES;
    if (_dragType == LineChartDragTypeVertical && currentSelectedComponent && currentSelectedPointIndex!=NSNotFound) {
        UITouch *touch = [touches anyObject];
        float pixelMoved = touchInitialLocation.y-[touch locationInView:self].y;//
        float valuePerPixel = (scale_max-scale_min)/(self.frame.size.height-VERTICAL_TOP_MARGIN-VERTICAL_BOTTOM_MARGIN-X_AXIS_TEXT_HEIGHT);
        int newValue = initialValue+pixelMoved*valuePerPixel;
        [currentSelectedComponent.points replaceObjectAtIndex:currentSelectedPointIndex withObject:[NSNumber numberWithInt:newValue]];
        [self setNeedsDisplay];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    if (_dragType == LineChartDragTypeVertical && touchMoved) {
        
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
}

@end

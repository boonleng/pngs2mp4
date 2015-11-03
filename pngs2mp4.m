/*
        File: pngs2mp4.m
 
  A command line utility to generate a movie from a series of images.

  Copyright (c) 2014 Boon Leng Cheong. All Rights Reserved.

*/

#include <stdio.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>


#ifdef USE_COLORS
#define COLOR_GREEN  "\e[32m"
#define COLOR_RED    "\e[31m"
#define COLOR_RESET  "\e[0m"
#else
#define COLOR_GREEN  ""
#define COLOR_RED    ""
#define COLOR_RESET  ""
#endif


void help() {
	printf("\n"
		   "PNG2MP4 - PNG Images to MP4 Video\n"
		   "  A command line utility that generates a movie from a series of images.\n"
		   "  The output video will be encoded in H.264 codec using High Profile 4.1.\n"
		   "  All parameters will be set to default values if not supplied.\n\n"
           "  Usage:\n\n"
		   "    pngs2mp4 [options] <dir_1> <dir_2> ...\n"
		   "\n"
		   "    -f       Frames per second of the movie.\n"
		   "    -b       Bits per second of the movie.\n"
		   "    -h       Height of the frame.\n"
		   "    -l       Logo at the corner.\n"
		   "    -o       Output filename.\n"
		   "    -w       Fit 16 x 9 widescreen\n"
		   "    -v       Increase verbose level.\n"
		   "\n"
		   "    <dir_x>  Directories that contains the images, which must contain the\n"
           "             same number of images."
		   "\n"
		   "  DEFAULTS:\n"
		   "\n"
		   "    f = 15\n"
		   "    b = <auto calculate, 1 bit / pixel / frame>\n"
		   "    h = <same as the image height>\n"
		   "    l = <none>\n"
		   "    o = <current directory name>.mp4\n"
		   "    v = 0\n"
		   "\n"
		   "  EXAMPLE 1:\n"
		   "\n"
		   "    pngs2mp4 -f 15 -o sample.mp4 images/\n"
		   "\n"
		   "  generates a 15-fps movie named sample.mp4 in the current folder using\n"
		   "  images in the folder 'images' relative to the current folder. Verbosity\n"
		   "  will be kept minimal.\n"
		   "\n"
		   "  EXAMPLE 2:\n"
		   "\n"
		   "    pngs2mp4 -v -f 10 -l logo.png -o sample.mp4 images/\n"
		   "\n"
		   "  generates a 10-fps movie named sample.mp4 in the current folder using\n"
		   "  images in the folder 'images'. The utility runs in a verbose mode, which\n"
		   "  generates a lot of internal messages. A logo named 'logo.png' will also\n"
		   "  be imprinted at the lower right corner.\n"
		   "\n"
		   "  Copyright (c) 2014 Boon Leng Cheong. All Rights Reserved.\n\n"
		   );
}

//
//
//   M  A  I  N
//
//
int main(int argc, char *argv[]) {
	
	float fps = 15.0f;
	NSInteger height = 0;
	NSInteger bitrate = 0;
	NSString *outputName = nil;
	NSString *logoName = nil;

	char verbose = 0;
	BOOL resizeImage = FALSE;
	BOOL fpsIsFractional = FALSE;
	BOOL fitForWideScreen = FALSE;
	BOOL __block videoClosed = FALSE;

	NSSize pixelsPerPoint = NSZeroSize;
	
	if (argc == 1 ||
		(argc == 2 && (!strcmp(argv[1], "--help") ||
					   !strcmp(argv[1], "-help") ||
					   !strcmp(argv[1], "-h")))) {
		help();
		return EXIT_SUCCESS;
	}
	
	@autoreleasepool {

		char c;
		
		while ((c = getopt(argc, argv, "f:b:h:l:o:vw")) != -1) {
			switch (c) {
				case 'f':
					fps = atof(optarg);
					if (fps < 0.1 || fps > 60.0) {
						fprintf(stderr, COLOR_RED "Error: Framerate should be 0.1 <= fps <= 60.0" COLOR_RESET "\n");
						return EXIT_FAILURE;
					}
					fpsIsFractional = floorf(fps / 1.0f) != fps;
					if (fpsIsFractional) {
						printf("Info: " COLOR_GREEN "FPS is fractional." COLOR_RESET "\n");
					}
					break;
				case 'b':
					bitrate = (NSInteger)atol(optarg);
					break;
				case 'h':
					height = (NSInteger)atol(optarg);
					if (height != 0) {
						resizeImage = TRUE;
					}
					break;
				case 'l':
					logoName = [NSString stringWithUTF8String:optarg];
					break;
				case 'o':
					outputName = [NSString stringWithUTF8String:optarg];
					break;
				case 'v':
					verbose++;
					break;
				case 'w':
					fitForWideScreen = TRUE;
					resizeImage = TRUE;
					break;
				default:
					fprintf(stderr, "Unknown option character `\\x%x'.\n", optopt);
					break;
			}
		}
        
        int i = optind;
        const int ndirs = argc - optind;
		
		NSFileManager *fileManager = [NSFileManager defaultManager];

        NSMutableArray *dirs = [NSMutableArray arrayWithCapacity:ndirs];
        while (i < argc) {
            // Input folders
            NSString *dir = [[NSURL fileURLWithPath:[[NSString stringWithUTF8String:argv[i++]] stringByExpandingTildeInPath]] path];
            [dirs addObject:dir];
        }
        NSLog(@"dirs = %@", dirs);
		
		// Output video name
		NSURL *outputPath;
		if (outputName) {
			outputPath = [NSURL fileURLWithPath:[outputName stringByExpandingTildeInPath]];
		} else {
			NSString *name = [[[dirs objectAtIndex:0] stringByDeletingLastPathComponent] lastPathComponent];
			name = [NSString stringWithFormat:@"%@.mp4", name];
			outputPath = [NSURL fileURLWithPath:name];
		}

		// I/O locations
		if (verbose) {
			printf("Info: dir=%s %s %s\n"
				   "Info: output=%s\n",
                   [[dirs objectAtIndex:0] UTF8String],
                   [dirs count] > 1 ? [[dirs objectAtIndex:1] UTF8String] : "",
                   [dirs count] > 2 ? "..." : "",
				   [[outputPath path] UTF8String]);
		}

		BOOL isDir = FALSE;
        BOOL dirExists = TRUE;
        for (NSString *dir in dirs) {
            BOOL exists = [fileManager fileExistsAtPath:dir isDirectory:&isDir];
            if (!isDir) {
                fprintf(stderr, COLOR_RED "Error: Input %s is not a directory." COLOR_RESET "\n", [dir UTF8String]);
                return EXIT_FAILURE;
            }
            dirExists &= exists;
        }
		NSError *error;

		if (!dirExists) {
			fprintf(stderr, COLOR_RED "Error: One or more input directories does not exist." COLOR_RESET "\n");
			return EXIT_FAILURE;
		}
		if ([fileManager isWritableFileAtPath:[[outputPath path] stringByDeletingLastPathComponent]] == NO) {
			fprintf(stderr, COLOR_RED "Error: Unable to write to the %s." COLOR_RESET "\n", [[[outputPath path] stringByDeletingLastPathComponent] UTF8String]);
			return EXIT_FAILURE;
		}
		if ([fileManager fileExistsAtPath:[outputPath path]]) {
			printf("Info: File exists. Removing %s ...\n", [[[outputPath path] lastPathComponent] UTF8String]);
			[fileManager removeItemAtPath:[outputPath path] error:&error];
		}

        NSMutableArray *dir_files = [NSMutableArray arrayWithCapacity:ndirs];
        for (NSString *dir in dirs) {
            NSArray *files = [fileManager contentsOfDirectoryAtPath:dir error:&error];
            files = [files sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
            [dir_files addObject:files];
        }
		
		// Count up the number of images
        i = 0;
        NSInteger imageCounts[ndirs];
        NSMutableArray *dir_images = [NSMutableArray arrayWithCapacity:ndirs];
        for (NSArray *files in dir_files) {
            NSInteger imageCount = 0;
            NSMutableArray *images = [NSMutableArray array];
            for (NSString *file in files) {
                if ([[file pathExtension] caseInsensitiveCompare:@"jpg"] == NSOrderedSame ||
                    [[file pathExtension] caseInsensitiveCompare:@"png"] == NSOrderedSame) {
                    [images addObject:file];
                    imageCount++;
                }
            }
            if (imageCount == 0) {
                fprintf(stderr, COLOR_RED "Error: Directory contains 0 images." COLOR_RESET "\n");
                return EXIT_FAILURE;
            }
            [dir_images addObject:images];
            imageCounts[i++] = imageCount;
        }
        
        // Check if all imageCounts are the same
        BOOL sameCount = TRUE;
        NSInteger imageCount = imageCounts[0];
        for (i = 1; i < ndirs; i++) {
            sameCount &= imageCounts[i] == imageCount;
        }
        if (!sameCount) {
            fprintf(stderr, COLOR_RED "Error: Not all directories contain the same number of images." COLOR_RESET "\n");
        }

        NSArray *images = [dir_images objectAtIndex:0];
		NSString *imagePath = [[dirs objectAtIndex:0] stringByAppendingPathComponent:[images objectAtIndex:0]];

		NSArray *imageReps = [NSBitmapImageRep imageRepsWithContentsOfFile:imagePath];

		// Derive frame size based on the first frame's image size
		size_t imageWidth = 0, imageHeight = 0;
		for (NSImageRep *imageRep in imageReps) {
			if (imageWidth < [imageRep pixelsWide]) {
				imageWidth = [imageRep pixelsWide];
			}
			if (imageHeight < [imageRep pixelsHigh]) {
				imageHeight = [imageRep pixelsHigh];
			}
			pixelsPerPoint = [imageRep size];
			pixelsPerPoint.width = imageWidth / pixelsPerPoint.width;
			pixelsPerPoint.height = imageHeight / pixelsPerPoint.height;
			if (verbose)
				printf("Info: Pixels Per Point = %.2f, %.2f\n", pixelsPerPoint.width, pixelsPerPoint.height);
		}
		
		// Some basic geometry
		NSRect sourceRect = NSMakeRect(0.0f, 0.0f, imageWidth, imageHeight);
        NSRect targetRect;
        NSRect drawRect0, drawRect1, drawRect2;
        if (ndirs == 1) {
            targetRect = NSMakeRect(0.0f, 0.0f, imageWidth, imageHeight);
        } else if (ndirs == 2) {
            targetRect = NSMakeRect(0.0f, 0.0f, 2.0f * imageWidth, imageHeight);
            drawRect0 = NSMakeRect(0.0f, 0.0f, imageWidth, imageHeight);
            drawRect1 = NSMakeRect(imageWidth, 0.0f, imageWidth, imageHeight);
        }
		double ratio = (double)imageWidth / (double)imageHeight;

		if (verbose) {
			printf("Info: First image size = %d x %d  (%.4f)\n", (int)imageWidth, (int)imageHeight, ratio);
		}
		
		if (resizeImage) {
			// Use the custom height if supplied
			if (height != 0) {
				imageHeight = (size_t)height;
			}
			// Crop out from the original if we want to fit the image into a wide screen aspect ratio
			if (fitForWideScreen) {
				if (ratio < 16.0 / 9.0) {
					sourceRect.origin.y = 0.5 * (sourceRect.size.height - 9.0 / 16.0 * sourceRect.size.width);
					sourceRect.size.height = 9.0 / 16.0 * sourceRect.size.width;
				} else {
					sourceRect.origin.x = sourceRect.size.width - 0.5 * 16.0 / 9.0 * sourceRect.size.height;
					sourceRect.size.width = 16.0 / 9.0 * sourceRect.size.height;
				}
				imageWidth = (size_t)(16.0 / 9.0 * height);
				targetRect.size.width = imageWidth;
				targetRect.size.height = imageHeight;
			} else {
				imageWidth = (size_t)(ratio * height);
                if (ndirs == 1) {
                    targetRect.size.width = imageWidth;
                } else if (ndirs == 2) {
                    targetRect.size.width = 2.0f * imageWidth;
                }
                targetRect.size.height = imageHeight;
			}
			if (verbose) {
				printf("Info: Will be resized to %d x %d\n", (int)targetRect.size.width, (int)targetRect.size.height);
			}
		}


		printf("Info: Source [ %5.1f %5.1f %5.1f %5.1f]\n", sourceRect.origin.x, sourceRect.origin.y, sourceRect.size.width, sourceRect.size.height);
		printf("Info: Target [ %5.1f %5.1f %5.1f %5.1f]\n", targetRect.origin.x, targetRect.origin.y, targetRect.size.width, targetRect.size.height);
        printf("Info: draw_1 [ %5.1f %5.1f %5.1f %5.1f]\n", drawRect0.origin.x, drawRect0.origin.y, drawRect0.size.width, drawRect0.size.height);
        printf("Info: draw_2 [ %5.1f %5.1f %5.1f %5.1f]\n", drawRect1.origin.x, drawRect1.origin.y, drawRect1.size.width, drawRect1.size.height);

		// Adjust the source rect by its pixels per point ratio
		sourceRect.origin.x = sourceRect.origin.x / pixelsPerPoint.width;
		sourceRect.origin.y = sourceRect.origin.y / pixelsPerPoint.height;
		sourceRect.size.width = sourceRect.size.width / pixelsPerPoint.width;
		sourceRect.size.height = sourceRect.size.height / pixelsPerPoint.height;
		
		// Logo image
		NSImage *logoImage = nil;
		NSRect logoRect = NSZeroRect;
		if (logoName) {
			NSImage *scratchImage = [[NSImage alloc] initWithContentsOfFile:logoName];
			NSSize logoSize = [scratchImage size];
			//printf(COLOR_RED "%.1f >? %.1f" COLOR_RESET "\n", logoSize.height * logoSize.width, 0.04f * imageHeight * imageHeight);
			if (logoSize.height * logoSize.width > 0.04f * imageHeight * imageHeight) {
				//printf(COLOR_RED "Scaling down..." COLOR_RESET "\n");
				CGFloat scale = sqrtf(0.04f * targetRect.size.width * targetRect.size.height / (logoSize.height * logoSize.width));
				logoSize.width = roundf(scale * logoSize.width);
				logoSize.height = roundf(scale * logoSize.height);
			}
			CGFloat pad = ceilf(targetRect.size.height * 0.04f / 5.0f) * 5.0f;
			logoRect = NSMakeRect(targetRect.size.width - logoSize.width - pad, pad, logoSize.width, logoSize.height);
			logoImage = [[NSImage alloc] initWithSize:logoSize];
			[logoImage lockFocus];
			[scratchImage drawInRect:NSMakeRect(0.0f, 0.0f, logoSize.width, logoSize.height)];
			[scratchImage release];
			[logoImage unlockFocus];
			printf("Info: logo=%s  %.1f x %.1f + %.1f + %.1f\n", [logoName UTF8String],
				   logoSize.width, logoSize.height, logoRect.origin.x, logoRect.origin.y);
		}
		
		
		// Check bitrate based on image size
		if (bitrate == 0) {
			//bitrate = roundf(imageHeight * imageWidth * fps);
            bitrate = 50000000;
			if (verbose) {
				printf("Info: Bitrate = %ld bps.\n", bitrate);
			}
		} else if (bitrate < 5000000) {
			if (verbose) {
				bitrate = 5000000;
			}
			printf("Info: Bitrate too low, overriden with 5 Mbps.\n");
		}
		
		// Video
		AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:outputPath
															   fileType:AVFileTypeMPEG4
																  error:&error];
		if (error) {
			fprintf(stderr, COLOR_RED "Error: %s" COLOR_RESET "\n", [[error localizedDescription] UTF8String]);
			exit(EXIT_FAILURE);
		}

		if (verbose)
			printf("Info: Video initialized\n");

		NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
									   [NSNumber numberWithInteger:targetRect.size.width], AVVideoWidthKey,
									   [NSNumber numberWithInteger:targetRect.size.height], AVVideoHeightKey,
									   AVVideoCodecH264, AVVideoCodecKey,
									   [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithInteger:bitrate], AVVideoAverageBitRateKey,
										nil], AVVideoCompressionPropertiesKey,
									   nil];
		
		AVAssetWriterInput *videoWriterInput = [AVAssetWriterInput
												assetWriterInputWithMediaType:AVMediaTypeVideo
												outputSettings:videoSettings];
		
		AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
														 assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput
														 sourcePixelBufferAttributes:nil];

		// Video writer
		[videoWriterInput setExpectsMediaDataInRealTime:YES];
		if ([videoWriter canAddInput:videoWriterInput]) {
			if (verbose) {
				printf("Info: Video writer can be added.\n");
			}
		} else {
			fprintf(stderr, COLOR_RED "Error: Video writer cannot be added." COLOR_RESET "\n");
		}
		[videoWriter addInput:videoWriterInput];
		BOOL started = [videoWriter startWriting];
		if (started) {
			if (verbose) {
				printf("Info: " COLOR_GREEN "Session started." COLOR_RESET "\n");
			}
		} else {
			fprintf(stderr, COLOR_RED "Session NOT started." COLOR_RESET "\n");
		}
		[videoWriter startSessionAtSourceTime:kCMTimeZero];

		// Stuffs for drawing
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		
		NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
								 [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
								 [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
		
		// A pixel buffer for drawing images
		CVPixelBufferRef buffer = NULL;
		if (CVPixelBufferCreate(kCFAllocatorDefault, targetRect.size.width, targetRect.size.height, k32ARGBPixelFormat, (CFDictionaryRef)options, &buffer) != kCVReturnSuccess) {
			fprintf(stderr, COLOR_RED "Error: Unable to allocate pixel buffer." COLOR_RESET "\n");
			exit(EXIT_FAILURE);
		}
		
		CVPixelBufferLockBaseAddress(buffer, 0);
		void *rasterData = CVPixelBufferGetBaseAddress(buffer);
		
		CGContextRef context = CGBitmapContextCreate(rasterData,
													 (size_t)targetRect.size.width,
													 (size_t)targetRect.size.height,
													 8,
													 CVPixelBufferGetBytesPerRow(buffer),
													 colorSpace,
													 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
		if (context == NULL){
			fprintf(stderr, COLOR_RED "Error: Unable to create Core Graphics context." COLOR_RESET "\n");
			exit(EXIT_FAILURE);
		}
		
		// The connected to NSGraphicsContext
		NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:NO];

		int __block frame = 0;
		float __block efps;
		CMTime __block timeCode = kCMTimeZero;
		NSTimeInterval __block t0 = [NSDate timeIntervalSinceReferenceDate], t1;
	
		dispatch_queue_t queue = dispatch_queue_create("videoInputQueue", NULL);

		[videoWriterInput requestMediaDataWhenReadyOnQueue:queue usingBlock:^{
			while ([videoWriterInput isReadyForMoreMediaData]) {

				[NSGraphicsContext setCurrentContext:nsContext];

                for (int k = 0; k < ndirs; k++) {
                    // The directory of the image
                    NSString *dir = [dirs objectAtIndex:k];
                    
                    // The path to the image
                    NSArray *images = [dir_images objectAtIndex:k];
                    NSString *imagePath = [dir stringByAppendingPathComponent:[images objectAtIndex:(NSInteger)frame]];
                    //NSLog(@"k=%d  %@", k, imagePath);
                    
                    // Get the image and draw into the buffer
                    NSImage *image = [[NSImage alloc] initWithContentsOfFile:imagePath];
                    if (image == nil) {
                        break;
                    }
                    
                    [image drawInRect:k == 0 ? drawRect0 : (k == 1 ? drawRect1 : drawRect2)
                             fromRect:sourceRect
                            operation:NSCompositeCopy
                             fraction:1.0f];
                    [image release];
                }
				
				// Imprint a logo at the lower right corner
				if (logoImage) {
					[logoImage drawInRect:logoRect];
				}
				
				// Esimate encoding speed at FPS
				t1 = [NSDate timeIntervalSinceReferenceDate];
				if (frame == 0) {
					efps = 1.0f / (t1 - t0);
				} else {
					efps = 0.8f * efps + 0.2f * (1.0f / (t1 - t0));
				}
				t0 = t1;

				frame++;
				
				// Now the image is ready, append it to the movie stream
				if (![adaptor appendPixelBuffer:buffer withPresentationTime:timeCode]) {
					if (verbose) {
						printf(" + %s  " COLOR_RED "FAIL" COLOR_RESET "\n", [[imagePath lastPathComponent] UTF8String]);
					}
				} else {
					if (verbose) {
						printf(" + %s (%d of %d) %.2f%% " COLOR_GREEN "OK" COLOR_RESET "  %.0fFPS\n",
							   [[imagePath lastPathComponent] UTF8String],
							   frame, (int)imageCount, (float)frame / imageCount * 100.0f, efps);
					} else {
						if (frame > 5) {
							fprintf(stderr, "Encoding %.2f%%  %.0fFPS\r", (float)frame / imageCount * 100.0f, efps);
						} else {
							fprintf(stderr, "Encoding %.2f%%\r", (float)frame / imageCount * 100.0f);
						}
					}
					if (fpsIsFractional) {
						timeCode = CMTimeAdd(timeCode, CMTimeMake(1000, (int32_t)(fps * 1000.0f)));
					} else {
						timeCode = CMTimeAdd(timeCode, CMTimeMake(1, (int32_t)fps));
					}
				}
				
				// Jump out if we have reached the end
				if (frame == images.count) {
					[videoWriterInput markAsFinished];
					[videoWriter finishWritingWithCompletionHandler:^{
						videoClosed = TRUE;
					}];
					[videoWriter release];
					break;
				}
			}
			
			if (!verbose) {
				// Clear line
				printf("\e[2K");
			}
		}];

		// Wait until the video is closed
		while (!videoClosed) {
			[NSThread sleepForTimeInterval:0.05];
		}

		CFRelease(context);
		
		CVPixelBufferUnlockBaseAddress(buffer, 0);
		CVPixelBufferRelease(buffer);
		
		CGColorSpaceRelease(colorSpace);
		
		if (logoImage)
			[logoImage release];
		
	} // @autorelease{}
	
	printf("All done.\n");
	
	return EXIT_SUCCESS;
}

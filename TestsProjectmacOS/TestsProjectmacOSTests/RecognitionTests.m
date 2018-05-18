//
//  RecognitionTests.m
//  TestsProjectTests
//
//  Created by Nikolay Volosatov on 15.12.14.
//  Copyright (c) 2014 Daniele Galiotto - www.g8production.com.
//  All rights reserved.
//

#import <AppKit/AppKit.h>
#import <TesseractOCRmacOS/TesseractOCR.h>
#import <Kiwi/Kiwi.h>

#import "G8RecognitionTestsHelper.h"
#import "NSImage+G8Equal.h"
#import "NSData+G8Equal.h"
#import "Defaults.h"

SPEC_BEGIN(RecognitionTests)

__block G8RecognitionTestsHelper *helper;

beforeEach(^{
    helper = [[G8RecognitionTestsHelper alloc] init];
});

#pragma mark - Test - Simple image

describe(@"Simple image", ^{

    beforeEach(^{
        helper.image = [NSImage imageNamed:@"image_sample.jpg"];
        helper.charWhitelist = @"0123456789";
    });

    it(@"Should recognize sync", ^{
        [helper recognizeImage];

        [[theValue(helper.tesseract.progress) should] equal:theValue(100)];

        NSString *recognizedText = helper.tesseract.recognizedText;

        [[recognizedText should] containString:@"1234567890"];
    });

    it(@"Should recognize by queue", ^{
        [helper recognizeImageUsingOperation];

        [[theValue(helper.tesseract.progress) should] equal:theValue(100)];

        NSString *recognizedText = helper.tesseract.recognizedText;
        [[recognizedText should] containString:@"1234567890"];
    });

    it(@"Should recognize with simple thresholding", ^{
        helper.customPreprocessingType = G8CustomPreprocessingSimpleThreshold;

        [helper recognizeImage];

        NSString *recognizedText = helper.tesseract.recognizedText;
        [[recognizedText should] containString:@"1234567890"];
    });

    describe(@"Subimage", ^{

        beforeEach(^{
            helper.rect = (CGRect){CGPointZero, {helper.image.size.width * 0.6f, helper.image.size.height}};
        });

        it(@"Should recognize subimage", ^{
            [helper recognizeImage];

            NSString *recognizedText = helper.tesseract.recognizedText;
            [[recognizedText should] containString:@"123456"];
            [[recognizedText shouldNot] containString:@"7890"];
        });

        it(@"Should recognize subimage after resizing", ^{
            helper.customPreprocessingType = G8CustomPreprocessingSimpleThresholdAndResize;

            [helper recognizeImage];

            NSString *recognizedText = helper.tesseract.recognizedText;
            [[recognizedText should] containString:@"123456"];
            [[recognizedText shouldNot] containString:@"7890"];
        });

    });

    it(@"Should provide choices", ^{
        [helper recognizeImage];

        NSArray *choices = helper.tesseract.characterChoices;
        for (id blocksObj in choices) {
            [[blocksObj should] beKindOfClass:[NSArray class]];

            for (id blockObj in (NSArray *)blocksObj) {
                [[blockObj should] beKindOfClass:[G8RecognizedBlock class]];
                G8RecognizedBlock *block = blockObj;

                [[block.text shouldNot] beEmpty];

                [[theValue(CGRectGetWidth(block.boundingBox)) should] beInTheIntervalFrom:theValue(0.0f)
                                                                                       to:theValue(1.0f)];
                [[theValue(CGRectGetHeight(block.boundingBox)) should] beInTheIntervalFrom:theValue(0.0f)
                                                                                        to:theValue(1.0f)];

                [[theValue(block.confidence) should] beGreaterThanOrEqualTo:theValue(0.0f)];
                [[theValue(block.level) should] equal:theValue(G8PageIteratorLevelSymbol)];
            }
        }
    });

    it(@"Should provide confidences", ^{
        [helper recognizeImage];

        NSArray *confidences = [helper.tesseract recognizedBlocksByIteratorLevel:G8PageIteratorLevelWord];
        [[[confidences should] have:1] object];

        id blockObj = confidences.firstObject;
        [[blockObj should] beKindOfClass:[G8RecognizedBlock class]];
        G8RecognizedBlock *block = blockObj;

        [[block.text shouldNot] beEmpty];
        [[theValue(CGRectGetWidth(block.boundingBox)) should] beInTheIntervalFrom:theValue(0.0f) to:theValue(1.0f)];
        [[theValue(CGRectGetHeight(block.boundingBox)) should] beInTheIntervalFrom:theValue(0.0f) to:theValue(1.0f)];
        [[theValue(block.confidence) should] beGreaterThanOrEqualTo:theValue(0.0f)];
        [[theValue(block.level) should] equal:theValue(G8PageIteratorLevelWord)];
    });

    it(@"Should clamp source resolution", ^{
        [helper setupTesseract];

        [[theValue(helper.tesseract.sourceResolution) should] equal:theValue(kG8DefaultResolution)];

        helper.tesseract.sourceResolution = 50;
        [[theValue(helper.tesseract.sourceResolution) should] beInTheIntervalFrom:theValue(kG8MinCredibleResolution)
                                                                               to:theValue(kG8MaxCredibleResolution)];

        helper.tesseract.sourceResolution = 3000;
        [[theValue(helper.tesseract.sourceResolution) should] beInTheIntervalFrom:theValue(kG8MinCredibleResolution)
                                                                               to:theValue(kG8MaxCredibleResolution)];
    });

    it(@"Should draw blocks on image", ^{
        [helper recognizeImage];

        NSArray *blocks = [helper.tesseract recognizedBlocksByIteratorLevel:G8PageIteratorLevelSymbol];
        NSImage *blocksImage = [helper.tesseract imageWithBlocks:blocks drawText:YES thresholded:NO];
        NSImage *expectedBlocksImage = [NSImage imageNamed:@"image_sample_bl_mac"];

        [[theValue([blocksImage g8_isEqualToImage:expectedBlocksImage]) should] beYes];
    });

    it(@"Should fetch thresholded image", ^{
        NSImage *onceThresholded = [helper thresholdedImageForImage:helper.image];
        NSImage *twiceThresholded = [helper thresholdedImageForImage:onceThresholded];
        NSImage *expectedThresholdedImage = [NSImage imageNamed:@"image_sample_tr"];

        [[theValue([onceThresholded g8_isEqualToImage:twiceThresholded]) should] beYes];
        [[theValue([onceThresholded g8_isEqualToImage:expectedThresholdedImage]) should] beYes];
    });

});

#pragma mark - Test - Blank image

describe(@"Blank image", ^{

    beforeEach(^{
        helper.image = [NSImage imageNamed:@"image_blank"];
        helper.customPreprocessingType = G8CustomPreprocessingSimpleThreshold;
    });

    it(@"Should recognize nothing", ^{
        [helper recognizeImage];

        NSString *recognizedText = helper.tesseract.recognizedText;
        [[recognizedText should] beEmpty];
    });

    it(@"Should recognize noise with Otsu", ^{
        helper.customPreprocessingType = G8CustomPreprocessingNone;

        [helper recognizeImage];

        NSString *recognizedText = helper.tesseract.recognizedText;
        [[recognizedText shouldNot] beEmpty];
    });

    it(@"Should be blank thresholded image", ^{
        NSImage *thresholdedImage = [helper thresholdedImageForImage:helper.image];

        [[theValue([thresholdedImage g8_isFilledWithColor:[NSColor blackColor]]) should] beYes];
    });

});

#pragma mark - Test - Well scaned page

describe(@"Well scanned page", ^{

    static NSString *const kG8WellScanedFirstTitle = @"Foreword";
    static NSString *const kG8WellScanedFinalLongString = @"recommendations sometimes get acted on";

    beforeEach(^{
        helper.image = [NSImage imageNamed:@"well_scanned_page"];
    });

    it(@"Should recognize", ^{
        [helper recognizeImage];

        [[theValue(helper.tesseract.progress) should] equal:theValue(100)];

        NSString *recognizedText = helper.tesseract.recognizedText;
        [[recognizedText should] containString:kG8WellScanedFirstTitle];
        [[recognizedText should] containString:kG8WellScanedFinalLongString];

        [[recognizedText should] containString:@"Division"];
        [[recognizedText should] containString:@"remove"];
        [[recognizedText should] containString:@"1954"];
    });

    it(@"Should fetch thresholded image", ^{
        NSImage *onceThresholded = [helper thresholdedImageForImage:helper.image];
        NSImage *twiceThresholded = [helper thresholdedImageForImage:onceThresholded];

        [[theValue([onceThresholded g8_isEqualToImage:twiceThresholded]) should] beYes];
    });

    it(@"Should not crash analyze layout", ^{
        helper.pageSegmentationMode = G8PageSegmentationModeOSDOnly;

        [helper recognizeImage];

        [[theBlock(^{
            [helper.tesseract deskewAngle];
        }) shouldNot] raise];
    });

    it(@"Should analyze layout", ^{
        helper.pageSegmentationMode = G8PageSegmentationModeAutoOSD;

        [helper recognizeImage];

        CGFloat deskewAngle = helper.tesseract.deskewAngle;
        [[theValue(ABS(deskewAngle)) should] beGreaterThan:theValue(FLT_EPSILON)];

        [[theValue(helper.tesseract.orientation) should] equal:theValue(G8OrientationPageUp)];
        [[theValue(helper.tesseract.writingDirection) should] equal:theValue(G8WritingDirectionLeftToRight)];
        [[theValue(helper.tesseract.textlineOrder) should] equal:theValue(G8TextlineOrderTopToBottom)];
    });

    it(@"Should break by deadline", ^{
        helper.waitDeadline = 1.0;

        [helper recognizeImageUsingOperation];

        [[helper.tesseract shouldNot] beNil];
        [[theValue(helper.tesseract.progress) should] beLessThan:theValue(100)];

        NSString *recognizedText = helper.tesseract.recognizedText;
        [[recognizedText should] containString:kG8WellScanedFirstTitle];
        [[recognizedText shouldNot] containString:kG8WellScanedFinalLongString];

        [[[[helper.tesseract recognizedBlocksByIteratorLevel:G8PageIteratorLevelWord] should] haveAtLeast:10] items];
    });

});

#pragma mark - hOCR

describe(@"hOCR", ^{

    it(@"Should sample image", ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"image_sample" ofType:@"hOCR"];

        helper.image = [NSImage imageNamed:@"image_sample.jpg"];
        helper.charWhitelist = @"0123456789";

        [helper recognizeImage];
        NSString *hOCR = [helper.tesseract recognizedHOCRForPageNumber:0];

        NSError *error = nil;
        [[hOCR should] equal:[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error]];
        NSAssert(error == nil, @"error loading hOCR from file %@: %@", path, error);
    });

    it(@"Should well scanned page", ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"well_scanned_page" ofType:@"hOCR"];

        helper.image = [NSImage imageNamed:@"well_scanned_page"];

        [helper recognizeImage];

        NSString *recognizedText = helper.tesseract.recognizedText;

        NSString *hOCR = [helper.tesseract recognizedHOCRForPageNumber:0];

        NSError *error = nil;
        NSString *fileString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];

        [[hOCR should] equal:fileString];
        NSAssert(error == nil, @"error loading hOCR from file %@: %@", path, error);
    });

    it(@"Should return nil without prerecognition", ^{
        G8Tesseract *tesseract = [[G8Tesseract alloc] initWithLanguage:kG8Languages];

        NSString *hOCR = [tesseract recognizedHOCRForPageNumber:0];
        [[hOCR should] beNil];
    });
});

describe(@"PDF", ^{

    NSData *(^recognizedPDFForImages)(NSArray*images) = ^NSData*(NSArray*images) {
        G8Tesseract *tesseract = [[G8Tesseract alloc] initWithLanguage:@"eng"];

        // TODO: Shouldn't use this directory
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *outputFilePath = [documentsDirectory stringByAppendingPathComponent:@"outputbase"];

        return [tesseract recognizedPDFForImages:images outputbase:outputFilePath];
    };

    NSData * (^samplePDFDataFromFile)(NSString *fileName) = ^NSData*(NSString *fileName) {
        NSString *PDFPath = [[NSBundle mainBundle] pathForResource:fileName ofType:@"pdf"];
        NSData *PDF = [NSData dataWithContentsOfFile:PDFPath];
        NSAssert(PDF, @"There is not %@ file to compare to", PDFPath);
        return PDF;
    };

    it(@"Should generate well scanned page", ^{
        NSData *pdfData = recognizedPDFForImages(@[[NSImage imageNamed:@"well_scanned_page"]]);
        [[theValue([pdfData g8_isEqualToData:samplePDFDataFromFile(@"well_scanned_page")]) should] beYes];
    });

    context(@"Should generate empty page for", ^{
        it(@"nil array", ^{
            [[theValue([recognizedPDFForImages(nil) g8_isEqualToData:samplePDFDataFromFile(@"empty")]) should] beYes];
        });

        it(@"empty array", ^{
            [[theValue([recognizedPDFForImages(@[]) g8_isEqualToData:samplePDFDataFromFile(@"empty")]) should] beYes];
        });

        it(@"array containing nonimage", ^{
            [[theValue([recognizedPDFForImages(@[@"someStringAsImage.png"]) g8_isEqualToData:samplePDFDataFromFile(@"empty")]) should] beYes];
        });
    });
});

SPEC_END
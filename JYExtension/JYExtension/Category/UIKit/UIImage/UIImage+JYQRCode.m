//
//  UIImage+JYQRCode.m
//  JYExtension
//
//  Created by Dely on 2017/8/18.
//  Copyright © 2017年 Dely. All rights reserved.
//

#import "UIImage+JYQRCode.h"

@implementation UIImage (JYQRCode)

#pragma mark - --------------------公共方法--------------------
/*生成二维码(黑白色)*/
+ (UIImage *)getQRWithString:(NSString *)string size:(CGFloat)size{
    UIImage *QRImage = [self getQRWithString:string size:size foreColor:nil logoImage:nil logoRadius:0.0];
    return QRImage;
}

/*生成二维码(前景色)*/
+ (UIImage *)getQRWithString:(NSString *)string size:(CGFloat)size foreColor:(UIColor *)foreColor{
    UIImage *QRImage = [self getQRWithString:string size:size foreColor:foreColor logoImage:nil logoRadius:0.0];
    return QRImage;
}

/*生成二维码(前景色、logo)*/
+ (UIImage *)getQRWithString:(NSString *)string size:(CGFloat)size foreColor:(UIColor *)foreColor logoImage:(UIImage *)logo logoRadius:(CGFloat)radius{
    
    if (!string || [string class] == [NSNull null]) {
        return nil;
    }
    size = [self validateCodeSize:size];
    CIImage *QRCIImage = [self getQRCIImageWithString:string];
    
    //这个就是黑白二维码图片可以直接使用了
    UIImage *QRImage = [self getQRImageWithCIImage:QRCIImage size:size];
    
    //处理颜色log二维码图片
    UIImage *handleQRImage = [self getColorOrLogoQRImage:QRImage foreColor:foreColor logo:logo logoRadius:radius] ;
    
    return handleQRImage;
}



#pragma mark - --------------------私有方法--------------------
//获取二维码尺寸合理性的大小
+ (CGFloat)validateCodeSize:(CGFloat)size{
    size = MAX(200, size);
    size = MIN(CGRectGetWidth([UIScreen mainScreen].bounds) - 40, size);
    return size;
}

//获取二维码CIImage
+ (CIImage *)getQRCIImageWithString:(NSString *)string{
    
    NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
    CIFilter *QRFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    
    //通过kvo方式给一个字符串，生成二维码
    [QRFilter setValue:stringData forKey:@"inputMessage"];
    
    //设置二维码的纠错水平，越高纠错水平越高，可以污损的范围越大
    [QRFilter setValue:@"H" forKey:@"inputCorrectionLevel"];
    
    return QRFilter.outputImage;
}

//对图像进行清晰化处理
+ (UIImage *)getQRImageWithCIImage:(CIImage *)image size:(CGFloat)size{
    
    CGRect extent = CGRectIntegral(image.extent);
    CGFloat scale = MIN(size/CGRectGetWidth(extent), size/CGRectGetHeight(extent));
    size_t width = CGRectGetWidth(extent) * scale;
    
    size_t height = CGRectGetHeight(extent) * scale;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, width, height, 8, 0, colorSpace, (CGBitmapInfo)kCGImageAlphaNone);
    CIContext * context = [CIContext contextWithOptions: nil];
    
    CGImageRef bitmapImage = [context createCGImage: image fromRect: extent];
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, scale, scale);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);
    CGContextRelease(bitmapRef);
    CGImageRelease(bitmapImage);
    CGColorSpaceRelease(colorSpace);
    
    return [UIImage imageWithCGImage:scaledImage];
}


+ (UIImage *)getColorOrLogoQRImage:(UIImage *)image foreColor:(UIColor *)foreColor logo:(UIImage *)logo logoRadius:(CGFloat)radius{
    UIImage *colorQRImage = [self getColorQRImage:image foreColor:foreColor];
    UIImage *logoQRImage = [self getLogoQRImage:colorQRImage logo:logo logoRadius:radius];
    return logoQRImage;
}


//填充颜色
void ProviderReleaseData(void *info, const void *data, size_t size) {
    free((void *)data);
}

+ (UIImage *)getColorQRImage:(UIImage *)image foreColor:(UIColor *)foreColor{
    if (foreColor) {
        const int imageWidth = image.size.width;
        const int imageHeight = image.size.height;
        size_t bytesPerRow = imageWidth * 4;
        uint32_t * rgbImageBuf = (uint32_t *)malloc(bytesPerRow * imageHeight);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(rgbImageBuf, imageWidth, imageHeight, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
        CGContextDrawImage(context, (CGRect){(CGPointZero), (image.size)}, image.CGImage);
        
        //遍历像素
        int pixelNumber = imageHeight * imageWidth;
        [self fillForeAndBackColor:rgbImageBuf pixelNum:pixelNumber foreColor:foreColor];
        
        CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, rgbImageBuf, bytesPerRow, ProviderReleaseData);
        CGImageRef imageRef = CGImageCreate(imageWidth, imageHeight, 8, 32, bytesPerRow, colorSpace, kCGImageAlphaLast | kCGBitmapByteOrder32Little, dataProvider, NULL, true, kCGRenderingIntentDefault);
        
        UIImage * resultImage = [UIImage imageWithCGImage: imageRef];
        CGImageRelease(imageRef);
        CGColorSpaceRelease(colorSpace);
        CGContextRelease(context);
        return resultImage;
    }
    return image;
}



// 遍历所有像素点，填充前景色和背景色（前景色为nil时设置为黑色，背景色nil时设置为透明）
+ (void)fillForeAndBackColor:(uint32_t *)rgbImageBuf pixelNum:(int)pixelNum foreColor:(UIColor *)foreColor{
    
    if (!foreColor) {
        return;
    }
    
    //前景色
    CGFloat foreR = 0.0, foreG = 0.0, foreB = 0.0, foreA = 0.0;
    [foreColor getRed:&foreR green:&foreG blue:&foreB alpha:&foreA];
    NSUInteger fR = foreR*255;
    NSUInteger fG = foreG*255;
    NSUInteger fB = foreB*255;
    
    uint32_t * pCurPtr = rgbImageBuf;
    for (int i = 0; i < pixelNum; i++, pCurPtr++) {
        uint8_t * ptr = (uint8_t *)pCurPtr;
        if ((*pCurPtr & 0xffffff00) < 0x99999900) {
            ptr[3] = fR;
            ptr[2] = fG;
            ptr[1] = fB;
        }else {
            ptr[0] = 0;
            
        }
    }
}


//填充logo
+ (UIImage *)getLogoQRImage:(UIImage *)image logo:(UIImage *)logo logoRadius:(CGFloat)radius;{
    if (!logo) {
        return image;
    }
    
    CGFloat width = image.size.width;
    
    CGFloat logoWidth = width/5.0;
    logoWidth = MIN(100, logoWidth);
    
    logo = [UIImage imageChangeSizeWithImage:logo size:CGSizeMake(logoWidth, logoWidth)];
    
    logo = [UIImage getRoundedRectImage:logo size:CGSizeMake(logoWidth, logoWidth) radius:radius];
    
    CGFloat magin = 10.f;
    UIImage *whiteBackImage = [UIImage imageWithColor:[UIColor whiteColor] size:CGSizeMake(logoWidth+magin, logoWidth+magin)];
    whiteBackImage = [UIImage getRoundedRectImage:whiteBackImage size:CGSizeMake(logoWidth+magin, logoWidth+magin) radius:radius];
    
    CGFloat logoX = (image.size.width - logo.size.width)/2.0;
    CGFloat logoY = (image.size.width - logo.size.width)/2.0;
    
    CGFloat whiteX = (image.size.width - logo.size.width - magin)/2.0;
    CGFloat whiteY = (image.size.width - logo.size.width - magin)/2.0;
    
    UIGraphicsBeginImageContext(image.size);
    [image drawInRect: (CGRect){ 0, 0, (image.size) }];
    [whiteBackImage drawInRect:(CGRect){ whiteX, whiteY, (whiteBackImage.size)}];
    [logo drawInRect: (CGRect){ logoX, logoY, (logo.size)}];
    UIImage * resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resultImage;
}

//根据颜色和大小获取一张图片
+ (instancetype)imageWithColor:(UIColor *)color size:(CGSize)size{
    UIGraphicsBeginImageContextWithOptions(size, 0, [UIScreen mainScreen].scale);
    [color set];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

//改变图片大小（会拉伸）
+ (instancetype)imageChangeSizeWithImage:(UIImage *)image size:(CGSize)size{
    
    CGFloat destW = size.width;
    CGFloat destH = size.height;
    
    CGFloat sourceW = size.width;
    CGFloat sourceH = size.height;
    
    CGImageRef imageRef = image.CGImage;
    
    CGContextRef bitmap = CGBitmapContextCreate(NULL,destW,destH, CGImageGetBitsPerComponent(imageRef), 4*destW, CGImageGetColorSpace(imageRef),(kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst));
    
    CGContextDrawImage(bitmap,CGRectMake(0, 0, sourceW, sourceH), imageRef);
    
    CGImageRef ref = CGBitmapContextCreateImage(bitmap);
    
    UIImage *result = [UIImage imageWithCGImage:ref];
    
    CGContextRelease(bitmap);
    CGImageRelease(ref);
    return result;
}


//获取圆角的图片
+ (instancetype)getRoundedRectImage:(UIImage*)image size:(CGSize)size radius:(CGFloat)r{
    // the size of CGContextRef
    int w = size.width;
    int h = size.height;
    
    UIImage *img = image;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGImageAlphaPremultipliedFirst);
    CGRect rect = CGRectMake(0, 0, w, h);
    
    CGContextBeginPath(context);
    JYAddRoundedRectToPath(context, rect, r, r);
    CGContextClosePath(context);
    CGContextClip(context);
    CGContextDrawImage(context, CGRectMake(0, 0, w, h), img.CGImage);
    CGImageRef imageMasked = CGBitmapContextCreateImage(context);
    img = [UIImage imageWithCGImage:imageMasked];
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(imageMasked);
    
    return img;
}

static void JYAddRoundedRectToPath(CGContextRef context, CGRect rect, float ovalWidth,float ovalHeight){
    float fw, fh;
    
    if (ovalWidth == 0 || ovalHeight == 0){
        CGContextAddRect(context, rect);
        return;
    }
    
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextScaleCTM(context, ovalWidth, ovalHeight);
    fw = CGRectGetWidth(rect) / ovalWidth;
    fh = CGRectGetHeight(rect) / ovalHeight;
    
    CGContextMoveToPoint(context, fw, fh/2);  // Start at lower right corner
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);  // Top right corner
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1); // Top left corner
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1); // Lower left corner
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1); // Back to lower right
    
    CGContextClosePath(context);
    CGContextRestoreGState(context);
}


@end

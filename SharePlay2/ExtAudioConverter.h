//
//  ExtAudioConverter.h
//  ExtAudio
//
//  
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioConverter.h>
#import <AudioToolbox/ExtendedAudioFile.h>
#import <AVFoundation/AVFoundation.h>
@interface ExtAudioConverter : NSObject{

}

-(BOOL)convertFrom:(NSURL*)fromURL toURL:(NSURL*)toURL;
@end

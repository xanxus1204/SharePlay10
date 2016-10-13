//
//  ExtAudioConverter.h
//  ExtAudio
//
//  Created by Norihisa Nagano
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioConverter.h>
#import <AudioToolbox/ExtendedAudioFile.h>
#import <AVFoundation/AVFoundation.h>
@interface ExtAudioConverter : NSObject{

}

-(void)convertFrom:(NSURL*)fromURL toURL:(NSURL*)toURL;
@end
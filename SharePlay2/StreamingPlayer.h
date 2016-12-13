//
//  StreamingPlayer.h
//  AudioStreamer
//
//  Created by 椛島優 on 2015/10/23.
//  Copyright © 2015年 椛島優. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define kNumberOfBuffers 3     //バッファの数
#define kBufferSize 32768      //バッファサイズ


typedef struct StreamInfo{
    AudioFileStreamID audioFileStream;
    AudioQueueRef     audioQueueObject;
    BOOL              started;
    BOOL              isPlaying;
    BOOL              isDone;
    AudioQueueBufferRef  audioQueueBuffer[kNumberOfBuffers];
    BOOL readyToPlay;
   
    
}StreamInfo;
@interface StreamingPlayer : NSObject{
    StreamInfo streamInfo;
    }
-(BOOL)play;
-(void)start;
-(BOOL)pause;
-(BOOL)stop;
-(void)changeVolume:(float)value;
-(void)recvAudio:(NSData *)data;
@end

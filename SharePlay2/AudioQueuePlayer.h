//
//  AudioQueuePlayer.h
//  AudioQueue
//
//  Created by Norihisa Nagano
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AudioQueuePlayer: NSObject {
    AudioQueueRef audioQueueObject;
    SInt64 currentFrame;
    AudioStreamBasicDescription audioFormat;
    BOOL donePlayingFile;
    BOOL isPrepared;
    BOOL isPlaying;
    AudioQueueTimelineRef timeline;
    SInt64 frameOffset;
    
}
-(SInt64)currentPosition;
-(void)setCurrentPosition:(SInt64)position;

@property SInt64 totalFrames;
@property BOOL isDone;
@property UInt32 numPacketsToRead;
@property AudioFileID audioFileID;
@property SInt64 startingPacketCount;
@property BOOL isVBR;
@property NSURL *url;


-(void)play;
-(void)stop:(BOOL)shouldStopImmediate;
-(void)initializeAudioQueue:(NSURL *)url2;
-(void)prepareBuffer;
      //再生
@end

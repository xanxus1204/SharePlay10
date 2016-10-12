//
//  AudioQueuePlayer.m
//  AudioQueue
//
//  Created by Norihisa Nagano
//

#import "AudioQueuePlayer.h"


@implementation AudioQueuePlayer
//static void checkError(OSStatus err,const char *message){
//    if(err){
//        char property[5];
//        *(UInt32 *)property = CFSwapInt32HostToBig(err);
//        property[4] = '\0';
//        NSLog(@"%s = %-4.4s,%d",message, property,(int)err);
//        exit(1);
//    }
//}


static void outputCallback(void *                  inUserData,
                           AudioQueueRef           inAQ,
                           AudioQueueBufferRef     inBuffer){
    AudioQueuePlayer *player = [[AudioQueuePlayer alloc]init];
    player = (__bridge AudioQueuePlayer*)inUserData;
    if(player.isDone){
        return;
    }
    
    UInt32 numPackets = player.numPacketsToRead;
    UInt32 numBytes;
    AudioFileReadPackets(player.audioFileID,
                            NO,
                            &numBytes,
                            inBuffer->mPacketDescriptions,
                            player.startingPacketCount,
                            &numPackets,
                            inBuffer->mAudioData);
    
    if (numPackets > 0){
        inBuffer->mAudioDataByteSize = numBytes;
        inBuffer->mPacketDescriptionCount = numPackets;
        AudioQueueEnqueueBuffer(inAQ,
                                inBuffer,
                                player.isVBR ? numPackets : 0, //VBRの場合はパケット数とASPDを渡す
                                player.isVBR ? inBuffer->mPacketDescriptions : NULL);
        player.startingPacketCount += numPackets;
    }else{
        player.startingPacketCount = 0;
        outputCallback(inUserData,inAQ,inBuffer);
    }
}






static UInt32 calcNumPackets(UInt32 framesPerPacket,UInt32 requestFrame){
    if(framesPerPacket >= requestFrame){
        return 1;
    }else{
        int packets = 2;
        while(1){
            UInt32 frames = packets * framesPerPacket;
            if(frames > requestFrame)break;
            packets++;
        }
        UInt32 sub1 = requestFrame -((packets - 1) * framesPerPacket);
        UInt32 sub2 = (packets * framesPerPacket) - requestFrame;
        if(sub1 <= sub2)return packets - 1;
        return packets;
    }
}


-(void)setCurrentPosition:(SInt64)position{
    BOOL playing = isPlaying;
    [self stop:YES];
    _startingPacketCount = position / audioFormat.mFramesPerPacket;
    frameOffset = position;
    if(playing)[self play];
}

-(SInt64)currentPosition{
    AudioTimeStamp timeStamp;
    AudioQueueGetCurrentTime(audioQueueObject,
                             timeline,
                             &timeStamp,
                             NULL);
    SInt64 currentSampleTime = (SInt64)timeStamp.mSampleTime + frameOffset;
    return currentSampleTime % _totalFrames;
}

-(void)initializeAudioQueue:(NSURL *)url2{
    _startingPacketCount = 0;
    frameOffset = 0;
    
    AudioFileOpenURL((__bridge CFURLRef)url2,
                     0x01,
                     kAudioFileM4AType,
                     &_audioFileID);
    
    UInt32 size = sizeof(AudioStreamBasicDescription);
    //[2] kAudioFilePropertyDataFormatをキーにAudioStreamBasicDescriptionを取得
    AudioFileGetProperty(_audioFileID,
                         kAudioFilePropertyDataFormat,
                         &size,
                         &audioFormat);
    
    _isVBR = (audioFormat.mBytesPerPacket == 0 || audioFormat.mFramesPerPacket == 0);
    
    //[3]Audio Queueオブジェクトを作成
    AudioQueueNewOutput(&audioFormat,
                        outputCallback,
                        (__bridge_retained void * _Nullable)(self),
                        NULL,NULL,0,
                        &audioQueueObject);
    
    //timelineを作成
    AudioQueueCreateTimeline(audioQueueObject, &timeline);
    
   
    
    UInt64 packetCount;
    UInt32 propertySize = sizeof(UInt64);
    AudioFileGetProperty(_audioFileID,
                         kAudioFilePropertyAudioDataPacketCount,
                         &propertySize,
                         &packetCount);
    
    _totalFrames = packetCount * audioFormat.mFramesPerPacket;
    
    if(audioFormat.mFormatID == kAudioFormatLinearPCM){
        _numPacketsToRead = 2048;
    }else{
        _numPacketsToRead = calcNumPackets(audioFormat.mFramesPerPacket, 2048);
    }
}


-(void)prepareBuffer{
    donePlayingFile = NO;
    _isDone = NO;
    isPrepared = YES;
    
    AudioQueueBufferRef buffers[3];
    //パケットのサイズを取得
    UInt32 maxPacketSize;
    UInt32 propertySize = sizeof(maxPacketSize);
    AudioFileGetProperty(_audioFileID,
                         kAudioFilePropertyPacketSizeUpperBound,
                         &propertySize,
                         &maxPacketSize);
    
    UInt32 bufferByteSize = _numPacketsToRead * maxPacketSize;
    //バッファをキューに追加
    BOOL isFormatVBR = (audioFormat.mBytesPerPacket == 0 || audioFormat.mFramesPerPacket == 0);
    int bufferIndex;
    for(bufferIndex = 0; bufferIndex < 3; bufferIndex++){
        AudioQueueAllocateBufferWithPacketDescriptions(audioQueueObject,
                                                       bufferByteSize,
                                                       (isFormatVBR ? _numPacketsToRead : 0),
                                                       &buffers[bufferIndex]);
        outputCallback((__bridge_retained void *)(self), audioQueueObject, buffers[bufferIndex]);
        if(donePlayingFile)break;
    }
}


-(void)play{
    if(!isPrepared)[self prepareBuffer];
    AudioQueueStart(audioQueueObject, 0);
    isPlaying = YES;
}

-(void)stop:(BOOL)shouldStopImmediate{
    //既にバッファがエンキューされていて、位置が進んでいるので現在の位置に戻す
    frameOffset = [self currentPosition];
    _startingPacketCount = frameOffset / audioFormat.mFramesPerPacket;
    
    _isDone = YES;
    AudioQueueStop(audioQueueObject, shouldStopImmediate);
    isPrepared = NO;
    isPlaying = NO;
}

@end

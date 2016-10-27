//
//  StreamingPlayer.m
//  AudioStreamer
//
//  Created by 椛島優 on 2015/10/23.
//  Copyright © 2015年 椛島優. All rights reserved.
//

#import "StreamingPlayer.h"
int count;
@interface StreamingPlayer()
@end
@implementation StreamingPlayer
-(void)start{
    if (streamInfo.isPlaying)return;
    
    OSStatus err = AudioFileStreamOpen(&streamInfo,
                                       propertyListenerProc,//プロパティを取得した時に呼ばれるコールバック関数
                                       //パケットデータを解析した時に呼ばれるコールバック関数
                                       packetsProc,
                                       0,   //ヒントなし
                                       &streamInfo.audioFileStream);
    checkError(err, "AudioFileStreamOpen");
    streamInfo.started = NO;
    streamInfo.isPlaying = YES;
    streamInfo.readyToPlay = NO;
}
-(void)play{
        if(!streamInfo.started && streamInfo.readyToPlay){
            streamInfo.started = YES;
          OSStatus  err = AudioQueueStart(streamInfo.audioQueueObject, NULL);
            checkError(err, "AudioQueueStart");
            streamInfo.isPlaying = YES;
            


        }else{
            NSLog(@"I'm not ready");
        }
}
-(void)pause{
    if (!streamInfo.isPlaying)return;
    if (streamInfo.started && !streamInfo.isDone) {
        
        OSStatus err = AudioQueuePause(streamInfo.audioQueueObject);
        checkError(err, "AudioQueuePause");
        streamInfo.isPlaying = NO;
        streamInfo.started = NO;

    }
    
}
-(void)stop{
    if (!streamInfo.isPlaying)return;
    if (streamInfo.started && !streamInfo.isDone) {
        streamInfo.isDone = YES;
        OSStatus err = AudioQueueStop(streamInfo.audioQueueObject, YES);
        checkError(err, "AudioQueueStop");
        streamInfo.isPlaying = NO;
       

    }
    
}
-(void)changeVolume:(float)value{
    if (streamInfo.started){
        OSStatus  err = AudioQueueSetParameter(streamInfo.audioQueueObject, kAudioQueueParam_Volume, value);//音量の調整
        checkError(err, "AudioQueuesetParamater");
    }
 
}
void propertyListenerProc(
                          void *							inClientData,
                          AudioFileStreamID				inAudioFileStream,
                          AudioFileStreamPropertyID		inPropertyID,
                          UInt32 *						ioFlags
                          ){
   
    StreamInfo* streamInfo = (StreamInfo*)inClientData;
    OSStatus err;
    
    //オーディオデータパケットを解析する準備が完了
    NSLog(@"property%u",(unsigned int)inPropertyID);
    if(inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets){
        
        count = 0;
        //ASBDを取得する
        AudioStreamBasicDescription audioFormat;
        UInt32 size = sizeof(AudioStreamBasicDescription);
        err = AudioFileStreamGetProperty(inAudioFileStream,
                                         kAudioFileStreamProperty_DataFormat,
                                         &size,
                                         &audioFormat);
        checkError(err, "kAudioFileStreamProperty_DataFormat");
        
        //AudioQueueオブジェクトの作成
        err = AudioQueueNewOutput(&audioFormat,
                                  outputCallback,
                                  streamInfo,
                                  NULL, NULL, 0,
                                  &streamInfo->audioQueueObject);
        checkError(err, "AudioQueueNewOutput");
       
       
        //キューバッファを用意する
        for (int i = 0; i < kNumberOfBuffers; ++i) {
            err = AudioQueueAllocateBuffer( streamInfo->audioQueueObject,
                                           kBufferSize,
                                           &streamInfo->audioQueueBuffer[i]);
            checkError(err, "AudioQueueAllocateBuffer");
        }
        UInt32 propertySize;
        
        //マジッククッキーのデータサイズを取得
        err = AudioFileStreamGetPropertyInfo( inAudioFileStream,
                                             kAudioFileStreamProperty_MagicCookieData,
                                             &propertySize,
                                             NULL );
        if (!err && propertySize) {
            char *cookie =(char*)malloc(propertySize);
            
            //マジッククッキーを取得
            err = AudioFileStreamGetProperty( inAudioFileStream,
                                             kAudioFileStreamProperty_MagicCookieData,
                                             &propertySize,
                                             cookie);
            checkError(err, "AudioQueueNewOutput");
            
            //キューにセット
            err = AudioQueueSetProperty( streamInfo->audioQueueObject, 
                                        kAudioQueueProperty_MagicCookie,
                                        cookie, 
                                        propertySize );
            checkError(err, "kAudioQueueProperty_MagicCookie");
            free(cookie);
        }
        streamInfo->readyToPlay = YES;

    }
}

void packetsProc( void *inClientData,
                 UInt32                        inNumberBytes,
                 UInt32                        inNumberPackets,
                 const void                    *inInputData,
                 AudioStreamPacketDescription  *inPacketDescriptions ){
    
    StreamInfo* streamInfo = (StreamInfo*)inClientData;
    OSStatus err;
    count ++;
    if ( count == 5) {
        AudioQueuePrime(streamInfo->audioQueueObject, 0, 0);
    }
    //キューバッファを作成し、エンキューする
    AudioQueueBufferRef queueBuffer;
    err = AudioQueueAllocateBuffer(streamInfo->audioQueueObject,
                                   inNumberBytes,
                                   &queueBuffer);
    if(err)NSLog(@"AudioQueueAllocateBuffer err = %d",(int)err);
    memcpy(queueBuffer->mAudioData, inInputData, inNumberBytes);
    
    queueBuffer->mAudioDataByteSize = inNumberBytes;
    queueBuffer->mPacketDescriptionCount = inNumberPackets;
    
        err = AudioQueueEnqueueBuffer(streamInfo->audioQueueObject,
                                  queueBuffer,
                                  0,
                                  NULL);
    
    if(err)NSLog(@"AudioQueueEnqueueBuffer err = %d",(int)err);
    
    
}
static void checkError(OSStatus err,const char *message){
    if(err){
        char property[5];
        *(UInt32 *)property = CFSwapInt32HostToBig(err);
        property[4] = '\0';
        NSLog(@"%s = %-4.4s,%d",message, property,(int)err);
        exit(1);
    }
}


void outputCallback( void                 *inClientData,
                    AudioQueueRef        inAQ,
                    AudioQueueBufferRef  inBuffer ){
    StreamInfo* streamInfo = (StreamInfo*)inClientData;
    //㈰inBufferがstreamInfo->audioQueueBuffer[ ]のどれかを探す
    UInt32 bufIndex = 0;
    for (int i = 0; i < kNumberOfBuffers; ++i){
        if (inBuffer == streamInfo->audioQueueBuffer[i]){
            bufIndex = i;
            break;
        }
    }
}
-(void)recvAudio:(NSData *)data{
    
    AudioFileStreamParseBytes(streamInfo.audioFileStream,
                              (int)data.length,
                              data.bytes,
                              0);
    
}

@end

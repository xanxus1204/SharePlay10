//
//  StreamingPlayer.h
//  AudioStreamer
//
//  Created by 椛島優 on 2015/10/23.
//  Copyright © 2015年 椛島優. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#include <pthread.h>
#define kNumberOfBuffers 3     //バッファの数
#define kBufferSize 32768      //バッファサイズ
#define kMaxPacketDescs 512    //最大ASPD数
typedef struct StreamInfo{
   
    AudioFileStreamID audioFileStream;
    AudioQueueRef     audioQueueObject;
    BOOL              started;
    
    AudioQueueBufferRef  audioQueueBuffer[kNumberOfBuffers];
    AudioStreamPacketDescription  packetDescs[kMaxPacketDescs];
    
    BOOL  inuse[kNumberOfBuffers];  //バッファが使用されているか
    UInt32 fillBufferIndex;         //バッファの埋めるべき位置
    UInt32 bytesFilled;             //何Byteバッファを埋めたか
    UInt32 packetsFilled;           //パケットを埋めた数
    
    pthread_mutex_t mutex;          //ロックに使用する
    pthread_mutex_t mutex2;         //ロックに使用する
    pthread_cond_t  cond;           //ロックに使用する
    
    BOOL isPlaying;  //再生中かどうか
    BOOL isDone;     //再生が終了したかどうか
}StreamInfo;

@interface StreamingPlayer: NSObject{
    
}

@property StreamInfo streamInfo;


-(void)start;
-(void)stop;

//typedef struct StreamInfo{
//    AudioFileStreamID audioFileStream;
//    AudioQueueRef     audioQueueObject;
//    BOOL              started;
//    BOOL              isPlaying;
//    BOOL              isDone;
//    AudioQueueBufferRef  audioQueueBuffer[kNumberOfBuffers];
//    AudioStreamPacketDescription  packetDescs[kMaxPacketDescs];
//    
//    BOOL  inuse[kNumberOfBuffers];  //バッファが使用されているか
//    UInt32 fillBufferIndex;         //バッファの埋めるべき位置
//    UInt32 bytesFilled;             //何Byteバッファを埋めたか
//    UInt32 packetsFilled;           //パケットを埋めた数
//    
//}StreamInfo;
//@interface StreamingPlayer : NSObject{
//     StreamInfo streamInfo;
//}
//-(void)start;
//-(void)pause;
//-(void)stop;
//-(void)restart;
-(void)recvAudio:(NSData *)data;
@end

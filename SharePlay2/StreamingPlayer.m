//
//  StreamingPlayer.m
//  AudioStreamer
//
//  Created by 椛島優 on 2015/10/23.
//  Copyright © 2015年 椛島優. All rights reserved.
//

#import "StreamingPlayer.h"

static void checkError(OSStatus err,const char *message){
    if(err){
        char property[5];
        *(UInt32 *)property = CFSwapInt32HostToBig(err);
        property[4] = '\0';
        NSLog(@"%s = %-4.4s,%d",message, property,err);
        exit(1);
    }
}

@interface StreamingPlayer()

@end
@implementation StreamingPlayer

- (void)start {
    if (_streamInfo.isPlaying) return;
    //スレッドを作成
    [ NSThread detachNewThreadSelector:@selector(startThread)
                              toTarget:self
                            withObject:nil];
}

-(void)stop{
    if (!_streamInfo.isPlaying) return;
    if (_streamInfo.started && !_streamInfo.isDone) {
        
        //他のスレッドでのAudioQueueの操作をロック
        pthread_mutex_lock(&_streamInfo.mutex2);{
            _streamInfo.isDone = YES; //終了フラグを立てる
            OSStatus err = AudioQueueStop(_streamInfo.audioQueueObject, YES);
            checkError(err, "AudioQueueStop");
        }pthread_mutex_unlock(&_streamInfo.mutex2);
        
        //スレッドがロックされている場合があるので解除を実行する
        pthread_mutex_lock(&_streamInfo.mutex);
        pthread_cond_signal(&_streamInfo.cond);
        pthread_mutex_unlock(&_streamInfo.mutex);
    }
}

-(void)startThread {
    //㈰バッファ用変数を初期化
    memset(_streamInfo.inuse, 0, sizeof(BOOL) * kNumberOfBuffers);
    _streamInfo.fillBufferIndex = 0;
    _streamInfo.bytesFilled = 0;
    _streamInfo.packetsFilled = 0;
    _streamInfo.started = NO;
    _streamInfo.isDone = NO;
    
    //㈪再生中のフラグをYESにする
    _streamInfo.isPlaying = YES;
    
    pthread_mutex_init(&_streamInfo.mutex, NULL);
    pthread_cond_init(&_streamInfo.cond, NULL);
    pthread_mutex_init(&_streamInfo.mutex2, NULL);
    
    OSStatus err = AudioFileStreamOpen( &_streamInfo,
                                       propertyListenerProc,
                                       packetsProc,
                                       0, //変更
                                       &_streamInfo.audioFileStream);
    checkError(err, "AudioFileStreamOpen");
    
    
    
    
    
    //㈫再生中はスレッドが終了しないようにする
    do{
        //RunLoopを0.25秒毎に実行する
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
    } while (_streamInfo.isPlaying);
    
    NSLog(@"*********Thread Did End");
    
    
}
void audioQueuePropertyListenerProc( void                  *inUserData,
                                    AudioQueueRef         inAQ,
                                    AudioQueuePropertyID  inID ){
    StreamInfo *streamInfo = inUserData;
    if (streamInfo->isDone) {
        streamInfo->isPlaying = NO;
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
    
    pthread_mutex_lock(&streamInfo->mutex);
    //㈪該当するインデックスを未使用（使用済み）にする
    streamInfo->inuse[bufIndex] = NO;
    //㈫pthread_cond_signalを呼んで、ロックを解除する
    pthread_cond_signal(&streamInfo->cond);
    pthread_mutex_unlock(&streamInfo->mutex);
}



static void enqueueBuffer(StreamInfo* streamInfo){
    
    OSStatus err = noErr;
    
    //バッファに充填済みフラグを立てる
    streamInfo->inuse[streamInfo->fillBufferIndex] = YES;
    
    AudioQueueBufferRef fillBuf
    = streamInfo->audioQueueBuffer[streamInfo->fillBufferIndex];
    fillBuf->mAudioDataByteSize = streamInfo->bytesFilled;
    
    err = AudioQueueEnqueueBuffer(streamInfo->audioQueueObject,
                                  fillBuf,
                                  streamInfo->packetsFilled,
                                  streamInfo->packetDescs);
    checkError(err, "AudioQueueEnqueueBuffer");
    
    if (!streamInfo->started){
        printf("AudioQueueStart\n");
        err = AudioQueueStart(streamInfo->audioQueueObject, NULL);
        checkError(err, "AudioQueueStart");
        streamInfo->started = YES;
    }
    
    //インデックスを次に進める 0 -> 1, 1 -> 2, 2 -> 0
    if (++streamInfo->fillBufferIndex >= kNumberOfBuffers){
        streamInfo->fillBufferIndex = 0;
    }
    
    streamInfo->bytesFilled = 0;
    streamInfo->packetsFilled = 0;
    
    //バッファが使われるまで他の処理をロックする
    //一番古いバッファが再生されるのを待つ
    pthread_mutex_lock(&streamInfo->mutex);{
        while (streamInfo->inuse[streamInfo->fillBufferIndex]){
            printf("WAITING... [%d]:\n",streamInfo->fillBufferIndex);
            pthread_cond_wait(&streamInfo->cond, &streamInfo->mutex);
        }
    }pthread_mutex_unlock(&streamInfo->mutex);
}


void propertyListenerProc(
                          void *							inClientData,
                          AudioFileStreamID				inAudioFileStream,
                          AudioFileStreamPropertyID		inPropertyID,
                          UInt32 *						ioFlags
                          ){
    
    StreamInfo* streamInfo = (StreamInfo*)inClientData;
    OSStatus err;
    NSLog(@"property%u",(unsigned int)inPropertyID);
    
    //オーディオデータパケットを解析する準備が完了
    if(inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets){
        
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
        
        AudioQueueAddPropertyListener(streamInfo->audioQueueObject,
                                      kAudioQueueProperty_IsRunning,
                                      audioQueuePropertyListenerProc,
                                      streamInfo);
        
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
    }
}


void packetsProc( void *inClientData,
                 UInt32                        inNumberBytes,
                 UInt32                        inNumberPackets,
                 const void                    *inInputData,
                 AudioStreamPacketDescription  *inPacketDescriptions ){
    
    StreamInfo* streamInfo = (StreamInfo*)inClientData;
    
    //固定ビットレート
        UInt32 offset = 0;
        UInt32 bufferByteSize = inNumberBytes;
        
        //bufferByteSize分のデータをバッファにコピーするまで続ける
        while (bufferByteSize){
            //現在のバッファにbufferByteSize分の空きがあるか
            UInt32 bufSpaceRemaining = kBufferSize - streamInfo->bytesFilled;
            //無ければエンキューする
            if(bufSpaceRemaining < bufferByteSize){
                enqueueBuffer(streamInfo);
            }
            
            UInt32 copySize;
            pthread_mutex_lock(&streamInfo->mutex2);{
                AudioQueueBufferRef fillBuf 
                = streamInfo->audioQueueBuffer[streamInfo->fillBufferIndex];
                bufSpaceRemaining = kBufferSize - streamInfo->bytesFilled;
                
                //bufferByteSize分の空きがあれば、それだけコピーする
                if (bufSpaceRemaining >= bufferByteSize){
                    copySize = bufferByteSize;
                }else{//無ければ、空きの分だけをコピーする
                    copySize = bufSpaceRemaining;
                }
                //inInputDataをoffset位置からbytesFilled以降にコピーする
                memcpy(fillBuf->mAudioData + streamInfo->bytesFilled, 
                       inInputData + offset, 
                       copySize);
                
            }pthread_mutex_unlock(&streamInfo->mutex2);
            
            //copySizeを次の処理に反映させる
            streamInfo->bytesFilled += copySize;
            bufferByteSize -= copySize;
            offset += copySize;
        }
    
}


-(void)recvAudio:(NSData *)data{
   
           AudioFileStreamParseBytes(_streamInfo.audioFileStream,
                                  (int)data.length,
                                  data.bytes,
                                  0);
    
}

@end

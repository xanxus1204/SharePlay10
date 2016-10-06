//
//  ExtAudioConverter.m
//  ExtAudio
//
//  Created by Norihisa Nagano
//

#import "ExtAudioConverter.h"

@implementation ExtAudioConverter


static void checkError(OSStatus err,const char *message){
    if(err){
        char property[5];
        *(UInt32 *)property = CFSwapInt32HostToBig(err);
        property[4] = '\0';
        NSLog(@"%s = %-4.4s, %d",message, property,(int)err);
        exit(1);
    }
}

-(void)convertFrom:(NSURL*)fromURL 
             toURL:(NSURL*)toURL{
    ExtAudioFileRef infile,outfile;
    OSStatus err;
    //ExtAudioFileの作成
    err = ExtAudioFileOpenURL((__bridge CFURLRef)fromURL, &infile);
    checkError(err,"ExtAudioFileOpenURL");
    
    AudioStreamBasicDescription inputFormat;
    AudioStreamBasicDescription outputFormat;
    AVAudioSession * audiosession =[AVAudioSession sharedInstance];
    
    [audiosession setActive:YES error:nil];
    [audiosession setCategory:AVAudioSessionCategoryAudioProcessing error:nil];
//    UInt32 audioCategory;
//    audioCategory = kAudioSessionCategory_AudioProcessing;
//    AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
//                            sizeof(audioCategory),
//                            &audioCategory);
    //変換するフォーマット(AAC)
    memset(&outputFormat, 0, sizeof(AudioStreamBasicDescription));
    outputFormat.mSampleRate       = 44100.0;
    outputFormat.mFormatID         = kAudioFormatMPEG4AAC;//AAC
    outputFormat.mChannelsPerFrame = 1;
    
    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                           0, NULL,
                           &size,
                           &outputFormat);

  
    err = ExtAudioFileGetProperty(infile,
                                  kExtAudioFileProperty_FileDataFormat,
                                  &size,
                                  &inputFormat);
    checkError(err,"ExtAudioFileGetProperty");	
    
    err = ExtAudioFileCreateWithURL((__bridge CFURLRef)toURL,
                                    kAudioFileM4AType, //AAC
                                    &outputFormat, 
                                    NULL, 
                                    kAudioFileFlags_EraseFile, 
                                    &outfile);
    checkError(err,"ExtAudioFileCreateWithURL");
    
    //書き込むファイルに、入力がリニアPCMであることを設定
    err = ExtAudioFileSetProperty(outfile,
                                  kExtAudioFileProperty_ClientDataFormat, 
                                  sizeof(AudioStreamBasicDescription), 
                                  &inputFormat);
    checkError(err,"kExtAudioFileProperty_ClientDataFormat");
    
    //読み込み位置を0に移動
    err = ExtAudioFileSeek(infile, 0);
    checkError(err,"ExtAudioFileSeek");
    
    //一度に読み込むフレーム数
    UInt32 readFrameSize = 1024;
    
    //読み込むバッファ領域を確保
    UInt32 bufferByteSize = sizeof(char) * readFrameSize * inputFormat.mBytesPerPacket;
    char *buffer = malloc(bufferByteSize);
    
    //AudioBufferListの作成
    AudioBufferList audioBufferList;
    audioBufferList.mNumberBuffers = 1;
    audioBufferList.mBuffers[0].mNumberChannels = inputFormat.mChannelsPerFrame;
    audioBufferList.mBuffers[0].mDataByteSize = bufferByteSize;
    audioBufferList.mBuffers[0].mData = buffer;
    
    while(1){
        UInt32 numPacketToRead = readFrameSize;
        err = ExtAudioFileRead(infile, &numPacketToRead, &audioBufferList);
        checkError(err,"ExtAudioFileRead");
        
        //読み込むフレームが無くなったら終了する
        if(numPacketToRead == 0)break;
        
        err = ExtAudioFileWrite(outfile, 
                                numPacketToRead,
                                &audioBufferList);
        checkError(err,"ExtAudioFileWrite");
    }
    
    ExtAudioFileDispose(infile);
    ExtAudioFileDispose(outfile);
    free(buffer);
}
@end

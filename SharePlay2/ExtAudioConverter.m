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

-(BOOL)convertFrom:(NSURL*)fromURL
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
    //変換するフォーマット(IMA4)
    memset(&outputFormat, 0, sizeof(AudioStreamBasicDescription));
    
    
    outputFormat.mSampleRate       = 44100.0;
    outputFormat.mFormatID         = kAudioFormatAppleIMA4;//IMA4
    outputFormat.mChannelsPerFrame = 2;
    

    
    
//    outputFormat.mSampleRate       = 44100.0;
//    outputFormat.mFormatID         = kAudioFormatMPEG4AAC;//AAC
//    outputFormat.mChannelsPerFrame = 2;
//    outputFormat.mFormatFlags = 0;
//    outputFormat.mFramesPerPacket = 1024;
//    outputFormat.mBitsPerChannel = 0;
//    outputFormat.mReserved = 0;
//    outputFormat.mBytesPerPacket = 0;
//    outputFormat.mBytesPerFrame = 0;
    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                           0, NULL,
                           &size,
                           &outputFormat);//変換後のフォーマット
    err = ExtAudioFileGetProperty(infile,//変換前のファイルのプロパティを取得
                                  kExtAudioFileProperty_FileDataFormat,
                                  &size,
                                  &inputFormat);
    checkError(err,"ExtAudioFileGetProperty");
    
    //リニアPCM以外からの変換であれば、リニアPCMとして読み込む
    if(inputFormat.mFormatID != kAudioFormatLinearPCM){
        //一旦変換するフォーマット(リニアPCM Little Endian)
        AudioStreamBasicDescription linearPCMFormat;
        linearPCMFormat.mSampleRate         = outputFormat.mSampleRate;
        linearPCMFormat.mFormatID			= kAudioFormatLinearPCM;
        linearPCMFormat.mFormatFlags		=  kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        linearPCMFormat.mFramesPerPacket	= 1;
        linearPCMFormat.mChannelsPerFrame	= outputFormat.mChannelsPerFrame;
        linearPCMFormat.mBitsPerChannel     = 16;
        linearPCMFormat.mBytesPerPacket     = 2 * outputFormat.mChannelsPerFrame;
        linearPCMFormat.mBytesPerFrame      = 2 * outputFormat.mChannelsPerFrame;
        linearPCMFormat.mReserved			= 0;
        
        //読み出すフォーマットをリニアPCMにする(中間フォーマット)
        inputFormat = linearPCMFormat;
    }
    //読み込むフォーマットを設定
    //必ずlinearPCMで読み出される
    err = ExtAudioFileSetProperty(infile,
                                  kExtAudioFileProperty_ClientDataFormat,
                                  sizeof(AudioStreamBasicDescription),
                                  &inputFormat);
    checkError(err,"ExtAudioFileSetProperty");
    
    
    
    err = ExtAudioFileCreateWithURL((__bridge CFURLRef)toURL,
                                    kAudioFileAIFCType, //IMA4
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
        if(numPacketToRead == 0){
            NSLog(@"変換完了");
           
            break;
            
        }
        err = ExtAudioFileWrite(outfile,
                                numPacketToRead,
                                &audioBufferList);
        checkError(err,"ExtAudioFileWrite");
    }
    ExtAudioFileDispose(infile);
    ExtAudioFileDispose(outfile);
    free(buffer);
    return  YES;
}
@end

//
//  AudioQueuePlayer.swift
//  SharePlay2
//
//  Created by 椛島優 on 2016/10/07.
//  Copyright © 2016年 椛島優. All rights reserved.
//
let kNumberBuffers = 3

import Foundation
import AudioToolbox
class AudioQueuePlayer: NSObject {
   
    var audioQueueObject:AudioQueueRef?
    var audioFileID:AudioFileID?
    var numPacketsToRead:UInt32!
    var startingPacketCount:Int64!
    var donePlayingfile:Bool?
    
 private  func prepareAudioQueue(url:NSURL) -> Void {
   
        AudioFileOpenURL(url,AudioFilePermissions.readPermission, kAudioFileM4AType,&audioFileID)
        var audioFormat:AudioStreamBasicDescription? = nil
        var size:UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        AudioFileGetProperty(audioFileID!, kAudioFilePropertyDataFormat, &size, &audioFormat)
        AudioQueueNewOutput(&audioFormat!, outputCallback as! AudioQueueOutputCallback, bridge(obj: self), nil, nil, 0, &audioQueueObject)
        var maxPacketSize:UInt32? = nil
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        
        AudioFileGetProperty(audioFileID!, kAudioFilePropertyPacketSizeUpperBound, &propertySize, &maxPacketSize)
        print(maxPacketSize)
        startingPacketCount = 0
        var buffers:[AudioQueueBufferRef?] = []
        
        numPacketsToRead = 1024
        let bufferSize:UInt32 = numPacketsToRead * maxPacketSize!
        print(bufferSize)
        
        for bufferIndex in 0..<3 {
            AudioQueueAllocateBuffer(audioQueueObject!, bufferSize, &buffers[bufferIndex])
            outputCallback(inUserData: bridge(obj: self), inAQ: audioQueueObject!, inBuffer: buffers[bufferIndex]!)
            if (donePlayingfile!) {break}
        }
        
    }
    func bridge<T : AnyObject>(obj : T) -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(Unmanaged.passUnretained(obj).toOpaque())
    }
    func bridge<T : AnyObject>(ptr : UnsafeMutableRawPointer) -> T {
        return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
    }
    
    func outputCallback(inUserData:UnsafeMutableRawPointer,inAQ:AudioQueueRef,inBuffer:AudioQueueBufferRef) -> Void {
        let player: AudioQueuePlayer = bridge(ptr: inUserData) as AudioQueuePlayer
        var numPackets:UInt32 = player.numPacketsToRead
        var numBytes:UInt32? = nil
        
        
        AudioFileReadPacketData(player.audioFileID!, false, &numBytes!, inBuffer.pointee.mPacketDescriptions, player.startingPacketCount, &numPackets, inBuffer)
        
        if (numPackets > 0){
            inBuffer.pointee.mAudioDataByteSize = numBytes!
            inBuffer.pointee.mPacketDescriptionCount = numPackets
            AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil)
            player.startingPacketCount = player.startingPacketCount + Int64(numPackets)
        }else{
            if !player.donePlayingfile! {
                print("stop")
                AudioQueueStop(inAQ, false)
                player.donePlayingfile = true
            }
        }
        }

    
    func play(url:NSURL) -> Void {
        prepareAudioQueue(url: url)
        AudioQueueStart(audioQueueObject!, nil)
    }
    
}

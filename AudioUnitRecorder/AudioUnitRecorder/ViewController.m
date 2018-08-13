//
//  ViewController.m
//  AudioUnitRecorder
//
//  Created by gaoguangxiao on 2018/8/13.
//  Copyright © 2018年 gaoguangxiao. All rights reserved.
//

#import "ViewController.h"

#import "XBAudioTool.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

#import "XBAudioDataWriter.h"
#import "XBPCMPlayer.h"
#define subPathPCM @"/Documents/record.pcm"
#define stroePath [NSHomeDirectory() stringByAppendingString:subPathPCM]
@interface ViewController ()<XBPCMPlayerDelegate>
{
    AudioUnit audioUnit;
    
    XBAudioDataWriter *dataWriter;
    NSData *data;
    
    Byte *recorderTempBuffer;
}
@property(nonatomic,strong)XBPCMPlayer *palyer;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
     dataWriter = [XBAudioDataWriter new];
}
- (IBAction)RecordOpration:(UIButton *)sender {
    //    1、判断是录音还是播放录音文件
    if (sender.tag == 0) {
        //先停止播放文件
        
        [self stopPlay];
        
        [self start];
        
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self stop];// 10秒停止录音
        });
    }else{
        [self playMP3New];
    }
}
- (void)playMP3New{
    NSString *path = stroePath;
    self.palyer = [[XBPCMPlayer alloc] initWithPCMFilePath:path rate:XBVoiceRate_44k channels:1 bit:16];
    
    self.palyer.delegate = self;
    [self.palyer play];
    
    
}
- (void)stopPlay{
    [self.palyer stop];
    self.palyer = nil;
}

- (void)playToEnd:(XBPCMPlayer *)player
{
    self.palyer = nil;
    NSLog(@"播放录音结束");
}

- (void)start
{
    [self delete];
    
    //设置录音文件路径
    
    [self initInputAudioUnitWithRate:44100 bit:16 channel:1];
    AudioOutputUnitStart(audioUnit);
}
- (void)stop{
    NSLog(@"录音停止");
    CheckError(AudioOutputUnitStop(audioUnit),
               "AudioOutputUnitStop failed");
    CheckError(AudioComponentInstanceDispose(audioUnit),
               "AudioComponentInstanceDispose failed");
}
- (void)initInputAudioUnitWithRate:(XBVoiceRate)rate bit:(XBVoiceBit)bit channel:(XBVoiceChannel)channel
{
    //设置AVAudioSession
    NSError *error = nil;
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error];
    [session setActive:YES error:nil];
    
    //初始化audioUnit 音频单元描述 kAudioUnitSubType_RemoteI
    AudioComponentDescription inputDesc = [XBAudioTool allocAudioComponentDescriptionWithComponentType:kAudioUnitType_Output componentSubType:kAudioUnitSubType_RemoteIO componentFlags:0 componentFlagsMask:0];
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &inputDesc);
    AudioComponentInstanceNew(inputComponent, &audioUnit);
    
    
    //设置输出流格式
    int mFramesPerPacket = 1;
//    kAudioFormatLinearPCM 设置PCM格式
    AudioStreamBasicDescription inputStreamDesc = [XBAudioTool allocAudioStreamBasicDescriptionWithMFormatID:kAudioFormatLinearPCM mFormatFlags:(kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsPacked) mSampleRate:rate mFramesPerPacket:mFramesPerPacket mChannelsPerFrame:channel mBitsPerChannel:bit];
    
    OSStatus status = AudioUnitSetProperty(audioUnit,
                                           kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Output,
                                           kInputBus,
                                           &inputStreamDesc,
                                           sizeof(inputStreamDesc));
    CheckError(status, "setProperty StreamFormat error");
    
    //麦克风输入设置为1（yes）
    int inputEnable = 1;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  kInputBus,
                                  &inputEnable,
                                  sizeof(inputEnable));
    CheckError(status, "setProperty EnableIO error");
    
    //设置回调
    AURenderCallbackStruct inputCallBackStruce;
    inputCallBackStruce.inputProc = inputCallBackFun;
    inputCallBackStruce.inputProcRefCon = (__bridge void * _Nullable)(self);
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &inputCallBackStruce,
                                  sizeof(inputCallBackStruce));
    CheckError(status, "setProperty InputCallback error");
}





static OSStatus inputCallBackFun(    void *                            inRefCon,
                                 AudioUnitRenderActionFlags *    ioActionFlags,
                                 const AudioTimeStamp *            inTimeStamp,
                                 UInt32                            inBusNumber,
                                 UInt32                            inNumberFrames,
                                 AudioBufferList * __nullable    ioData)
{
    
    ViewController *recorder = (__bridge ViewController *)(inRefCon);
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mData = NULL;
    bufferList.mBuffers[0].mDataByteSize = 0;
    
    AudioUnitRender(recorder->audioUnit,
                    ioActionFlags,
                    inTimeStamp,
                    kInputBus,
                    inNumberFrames,
                    &bufferList);
    
//    //回调中写 函数
//    recorder ->recorderTempBuffer = malloc(CONST_BUFFER_SIZE);
//
//    typeof(recorder) __weak weakSelf = recorder;
//    typeof(weakSelf) __strong strongSelf = weakSelf;
//
    AudioBuffer buffer = bufferList.mBuffers[0];
    int len = buffer.mDataByteSize;
//    memcpy(strongSelf->recorderTempBuffer, buffer.mData, len);

    [recorder->dataWriter writeBytes:buffer.mData len:len toPath:stroePath];
    

    
    return noErr;
}


- (void)delete
{
    NSString *pcmPath = stroePath;
    NSLog(@"音频路径：%@",pcmPath);
    if ([[NSFileManager defaultManager] fileExistsAtPath:pcmPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:pcmPath error:nil];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

//
//  LocalAudioViewController.m
//  AudioDemo
//
//  Created by 刘威振 on 16/1/5.
//  Copyright © 2016年 LiuWeiZhen. All rights reserved.
//
//

#import "LocalAudioViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "ZZAudioItem.h"
#import "ZZLRCParser.h"

@interface LocalAudioViewController () <AVAudioPlayerDelegate>

/* 控件 */
@property (weak, nonatomic  ) IBOutlet UILabel        *lrcLabel;     // 显示歌词
@property (weak, nonatomic  ) IBOutlet UISlider       *volumeSlider; // 音量控制
@property (strong, nonatomic) IBOutlet UISlider *progress; // 播放进度条

/* 数据 */
@property (nonatomic) NSMutableArray *audioList;        // 音频列表
@property (nonatomic) ZZAudioItem    *currentAudioItem; // 当前正在播放的音频对象

/* 控制器 */
@property (nonatomic) AVAudioPlayer *player;  // 播放器
@property (nonatomic) ZZLRCParser *lrcParser; // 歌词解析器
@property (nonatomic) NSTimer *timer;         // 定时器，每隔一段时间刷新进度

@end

@implementation LocalAudioViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initData];
    [self prepare];
}

- (void)initData {
    self.audioList = [NSMutableArray arrayWithArray:[ZZAudioItem allAudioItem]];
    self.currentAudioItem = self.audioList[0];
}

- (void)prepare {
    [_timer invalidate], _timer = nil;
    NSError *error = nil;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:_currentAudioItem.audioPath] error:&error];
    _player.delegate = self;
    [_player prepareToPlay]; // 准备播放
    if (error) return;
    self.lrcParser = [[ZZLRCParser alloc] initWithFilePath:_currentAudioItem.lrcPath]; // 歌词解析
}

// 播放
- (IBAction)play:(id)sender {
    if ([self.player play]) {
        NSLog(@"开始播放");
    }
    
    if (self.timer == nil) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(timerAction:) userInfo:nil repeats:YES]; // 每隔一小段时间，通过timerAction:方法更新显示的歌词，更新进度条 NSTimer对象有点特殊，它们retain target，所以在当前视图消失的时候应当把定时器invalide，销毁
    }
    [self.timer setFireDate:[NSDate date]]; // 触发定时器方法，写成[NSDate distantPast]也行
    
    [self configNowPlayingInfoCenter]; // 后台显示歌曲信息
}

// 暂停
- (IBAction)pause:(id)sender {
    [self.player pause];
    [self.timer setFireDate:[NSDate distantFuture]];  // 暂停定时器
}

// 停止
- (IBAction)stop:(id)sender {
    [self.player stop];
    
    self.player.currentTime = 0.0;  // 播放进度归零
    self.progress.value     = 0.0;  // 进度条归零
    [_timer invalidate], _timer = nil; // 定时器置空
}

// 静音 switch
- (IBAction)silenceSwitch:(UISwitch *)aSwitch {
    self.player.volume = aSwitch.isOn ? 0.0 : self.volumeSlider.value;
}

// 声音滑块
- (IBAction)volumeSliderAction:(id)sender {
    UISlider *slider = (UISlider *)sender;
    self.player.volume = slider.value; // player.volume范围范和默认的slider范围都是[0.0~1.0]
}

// 更改播放进度
- (IBAction)progressAction:(UISlider *)slider {
    self.player.currentTime = self.player.duration*_progress.value; // 正在播放（秒）
}

// 定时器刷新进度条
- (void)timerAction:(NSTimer *)timer {
    // 更新进度条 player.currentTime当前播放时间 player.duration整个歌曲共占用的时候
    self.progress.value = self.player.currentTime/self.player.duration;
    
    NSString *lrc = [self.lrcParser lrcByTime:self.player.currentTime];
    if (lrc.length <= 0) {
        return;
        // NSLog(@"%f %@", _player.currentTime, lrc);
    }
    self.lrcLabel.text = [self.lrcParser lrcByTime:self.player.currentTime];
}

// 上一首
- (IBAction)previousSong:(UIButton *)button {
    NSInteger index = [self.audioList indexOfObject:_currentAudioItem];
    if (index <= 0) {
        NSLog(@"已是第一首");
        return;
    } else {
        _currentAudioItem = [self.audioList objectAtIndex:--index];
        [self prepare];
        [self play:nil];
    }
}

// 下一首
- (IBAction)nextSong:(id)sender {
    NSInteger index = [self.audioList indexOfObject:_currentAudioItem];
    if (index >= self.audioList.count-1) {
        NSLog(@"已是最后一首");
        return;
    } else {
        _currentAudioItem = [self.audioList objectAtIndex:++index];
        [self prepare];
        [self play:nil];
    }
}

// 解决定时器的内存问题
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_timer invalidate], _timer = nil;
    // [self resignFirstResponder];
}

// 后台播放信息显示
- (void)configNowPlayingInfoCenter {
    if (NSClassFromString(@"MPNowPlayingInfoCenter")) { // 类MPNowPlayingInfoCenter是否存在，因为这个类是5.0之后出现的
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        
        /* 备注：下面这几个设置最好判断下是否为空，比如假设_lrcParser.title为空，会crash */
        [dict setObject:_lrcParser.title forKey:MPMediaItemPropertyTitle]; // 歌曲名
        [dict setObject:_lrcParser.author forKey:MPMediaItemPropertyArtist];  // 歌首，艺术家
        [dict setObject:_lrcParser.albume forKey:MPMediaItemPropertyAlbumTitle]; // 专辑名
        
        // MPMediaItem *item = [[MPMediaItem alloc] init];
        // item.title =
        
        UIImage *image = [_currentAudioItem image];
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:image];
        [dict setObject:artwork forKey:MPMediaItemPropertyArtwork];
        
        /**
         MPNowPlayingInfoCenter 用于播放APP中正在播放的媒体信息.
         播放的信息会显示在锁屏页面和多任务管理页面.如果用户是用airplay播放的话 会自动投射到相应的设备上.
         
         From apple: https://developer.apple.com/library/ios/documentation/MediaPlayer/Reference/MPNowPlayingInfoCenter_Class/index.html
         Use a now playing info center to set now-playing information for media being played by your app.
         */
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:dict];
        
        // [self becomeFirstResponder];
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    }
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type == UIEventTypeRemoteControl) {
        switch (event.subtype) {
            case UIEventSubtypeRemoteControlPause: { // 暂停
                [self pause:nil];
            }
                break;
            case UIEventSubtypeRemoteControlPlay: { // 播放
                [self play:nil];
            }
                break;
            case UIEventSubtypeRemoteControlNextTrack: { // 下一首
                [self nextSong:nil];
            }
                break;
            case UIEventSubtypeRemoteControlPreviousTrack: { // 上一首
                [self previousSong:nil];
            }
                break;
            default:
                break;
        }
    }
}

// 此句代码若不写，remoteControlReceivedWithEvent得不到调用
- (BOOL)canBecomeFirstResponder {
    return YES;
}

@end

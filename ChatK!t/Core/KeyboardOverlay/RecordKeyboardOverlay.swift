//
//  RecordKeyboardOverlay.swift
//  ChatK!t
//
//  Created by ben3 on 18/04/2021.
//

import Foundation
import DateTools
import RxSwift

public class RecordKeyboardOverlay: UIView, KeyboardOverlay {
    
    public static let key = "record"
    
    public var recordView: RecordView = .fromNib()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    public convenience init(delegate: RecordViewDelegate) {
        self.init(frame: CGRect.zero)
        setup(delegate)
    }

    public convenience init(frame: CGRect, delegate: RecordViewDelegate) {
        self.init(frame: frame)
        setup(delegate)
    }

    public convenience required init?(coder: NSCoder) {
        self.init()
    }

    public func setup(_ delegate: RecordViewDelegate) {
        addSubview(recordView)
        recordView.setDelegate(delegate)
        recordView.keepInsets.equal = 0
    }

    public func viewWillLayoutSubviews(view: UIView) {
        keepBottomInset.equal = view.safeAreaHeight() + ChatKit.config().chatOptionsBottomMargin
    }
    
    public static func new(_ delegate: RecordViewDelegate) -> RecordKeyboardOverlay {
        return RecordKeyboardOverlay(delegate: delegate)
    }
    
}

public protocol RecordViewDelegate {
    func send(audio: Data, duration: Int)
}

public class RecordView: UIView {
    
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    @IBOutlet weak var recordImageView: UIImageView!
    @IBOutlet weak var lockImageView: UIImageView!
    
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var micImageView: UIImageView!
    
    @IBOutlet weak var infoLabel: UILabel!
    public var delegate: RecordViewDelegate?
        
    public var timer: Timer?
    public var startTime: NSDate?
            
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        micImageView.image = ChatKit.asset(icon: "icn_30_mic").withRenderingMode(.alwaysTemplate)
        micImageView.tintColor = ChatKit.asset(color: "red")
        
        ChatKit.audioRecorder().prepare()
                
        cancel()
                
        updateMicButtonForPermission()
        
        lockImageView.isUserInteractionEnabled = false
        recordImageView.isUserInteractionEnabled = false

    }
    
    public func updateMicButtonForPermission(error: Error? = nil) {
        if ChatKit.audioRecorder().isAuth() {
            recordImageView.image = ChatKit.asset(icon: "icn_60_mic_button")
            recordImageView.highlightedImage = ChatKit.asset(icon: "icn_100_mic_button_red")
            infoLabel.text = ""
        } else {
            recordImageView.image = ChatKit.asset(icon: "icn_60_mic_unlock_button")
            recordImageView.highlightedImage = ChatKit.asset(icon: "icn_60_mic_unlock_button")
            infoLabel.text = t(Strings.audioPermissionDenied)
        }
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {

            let point = touch.location(in: self)

            let recordOver = recordImageView.frame.contains(point)
            
            if recordOver && !isRecording() {
                if !ChatKit.audioRecorder().isAuth() {
                    requestAuth()
                } else {
                    start()
                }
            }
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {

            let point = touch.location(in: self)

            let lockOver = lockImageView.frame.contains(point)
            
            // If we pan over the lock button lock the record button
            if !lockImageView.isHighlighted, isRecording(), lockOver {
                lock()
            }
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {

            let point = touch.location(in: self)

//            let lockOver = lockImageView.frame.contains(point)
            let recordOver = recordImageView.frame.contains(point)
                        
            if !lockImageView.isHighlighted {
                if ChatKit.audioRecorder().isAuth() {
                    if recordOver {
                        send()
                    } else {
                        cancel()
                    }
                }
            }
        }
    }
    
    public func setDelegate(_ delegate: RecordViewDelegate) {
        self.delegate = delegate
    }
    
    @IBAction func sendButtonPressed(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.send()
        }
    }
    
    @IBAction func deleteButtonPressed(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.cancel()
        }
    }
        
    public func requestAuth() {
        _ = ChatKit.audioRecorder().requestAuth().observe(on: MainScheduler.instance).subscribe(onCompleted: { [weak self] in
            ChatKit.audioRecorder().prepare()
            self?.updateMicButtonForPermission()
        }, onError: { [weak self] error in
            self?.updateMicButtonForPermission(error: error)
        })
    }
    
    public func lock() {
        lockImageView.isHighlighted = true
        sendButton.isHidden = false
        deleteButton.isHidden = false
    }
        
    public func send() {
        
        lockImageView.isHighlighted = false
        recordImageView.isHighlighted = false
    
        do {
            let result = try ChatKit.audioRecorder().stop()
            let time = result.1
            
            if let data = result.0, time > ChatKit.config().minimumAudioRecordingLength  {
                delegate?.send(audio: data, duration: time)
            }
        } catch {
            
        }
        
        cancel()
    }
    
    public func cancel() {

        infoLabel.text = ""
        lockImageView.isHighlighted = false
        recordImageView.isHighlighted = false

        sendButton.isHidden = true
        deleteButton.isHidden = true
        micImageView.isHidden = true

        timeLabel.isHidden = true
        timeLabel.text = ""
        timer?.invalidate()
                
        do {
            _ = try ChatKit.audioRecorder().stop()
        } catch {
            
        }
        ChatKit.audioRecorder().prepare()
    }
    
    public func isRecording() -> Bool {
        return ChatKit.audioRecorder().isRecording
    }
    
    public func start() {
                
        ChatKit.audioRecorder().record()

        recordImageView.isHighlighted = true

        startTime = NSDate()
        
        micImageView.isHidden = false
        timeLabel.isHidden = false
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] timer in
            DispatchQueue.main.async {
                if let start = self?.startTime {
                    let min = floor(start.minutesAgo())
                    let sec = floor(start.secondsAgo()) - min * 60
                    self?.timeLabel.text = String(format: "%.0f:%02.0f", min, sec)
                } else {
                    self?.timeLabel.text = ""
                }
            }
        })
    }
    
}

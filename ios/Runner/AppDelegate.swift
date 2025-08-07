import Flutter
import UIKit
import Speech
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var speechRecognitionHandler: SpeechRecognitionHandler?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        if let controller = window?.rootViewController as? FlutterViewController {
            let speechChannel = FlutterMethodChannel(name: "com.example.voice_expense_tracker/speech",
                                                     binaryMessenger: controller.binaryMessenger)
            speechRecognitionHandler = SpeechRecognitionHandler(channel: speechChannel)

            speechChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
                guard let self = self else { return }
                switch call.method {
                case "initialize":
                    self.speechRecognitionHandler?.initialize(result: result)
                case "startRecognition":
                    self.speechRecognitionHandler?.startRecognition(result: result)
                case "stopRecognition":
                    self.speechRecognitionHandler?.stopRecognition(result: result)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

class SpeechRecognitionHandler: NSObject, SFSpeechRecognizerDelegate {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let channel: FlutterMethodChannel
    private var lastRecognizedString: String = ""

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    func initialize(result: @escaping FlutterResult) {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        speechRecognizer?.delegate = self

        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    result(true)
                default:
                    result(false)
                }
            }
        }
    }

    func startRecognition(result: @escaping FlutterResult) {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            result(FlutterError(code: "AUDIO_SESSION_ERROR", message: "Failed to set up audio session", details: nil))
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }

        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] response, error in
            var isFinal = false

            if let response = response {
                let bestString = response.bestTranscription.formattedString
                self?.lastRecognizedString = bestString
                self?.channel.invokeMethod("onRecognitionResult", arguments: bestString)
                isFinal = response.isFinal
            }

            if error != nil || isFinal {
                self?.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self?.recognitionRequest = nil
                self?.recognitionTask = nil
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            result(true)
        } catch {
            result(FlutterError(code: "AUDIO_ENGINE_ERROR", message: "Failed to start audio engine", details: nil))
        }
    }

    func stopRecognition(result: @escaping FlutterResult) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        result(self.lastRecognizedString)
    }
}

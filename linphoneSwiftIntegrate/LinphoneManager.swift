//
//  LinphoneManager.swift
//  linphoneSwiftIntegrate
//
//  Created by Jenny Huang on 2019/4/30.
//  Copyright © 2019 Jenny Huang. All rights reserved.
//

import Foundation
import UIKit

var isSendNotification = false
var callStatus = ""
/*
 0: default
 1: Outgoing
 2: Incoming
 3: Failure Call
 4: Missed
 */
var callStatusNumber: NSInteger = 0

let G_CALL_COMING = "callComing"
let G_CALL_OUTGOING_RINGING = "callRingingRemote"
let G_CALL_STREAMS_RUNNING = "callStreamsRunning"
let G_CALL_ERROR = "callError"
let G_CALL_END = "callEnd"
let G_CALL_RELEASED = "callReleased"
let G_CALL_CONNECTED = "callConnected"
let G_CALL_OTHER_STATE = ""

var registrationStateChanged: LinphoneCoreRegistrationStateChangedCb = {
    (lc: Optional<OpaquePointer>, proxyConfig: Optional<OpaquePointer>, state: _LinphoneRegistrationState, message: Optional<UnsafePointer<Int8>>) in
    
    switch state{
    case LinphoneRegistrationNone: /**<Initial state for registrations */
        NSLog("LinphoneRegistrationNone")
        
    case LinphoneRegistrationProgress:
        NSLog("LinphoneRegistrationProgress")
        
    case LinphoneRegistrationOk:
        NSLog("LinphoneRegistrationOk")
        
    case LinphoneRegistrationCleared:
        NSLog("LinphoneRegistrationCleared")
        
    case LinphoneRegistrationFailed:
        NSLog("LinphoneRegistrationFailed")
        
    default:
        NSLog("Unkown registration state")
    }
    } as LinphoneCoreRegistrationStateChangedCb

var callStateChanged: LinphoneCoreCallStateChangedCb = {
    (lc: Optional<OpaquePointer>, call: Optional<OpaquePointer>, callState: LinphoneCallState,  message: Optional<UnsafePointer<Int8>>) in
    //    lc, call, callState, message in
    
    switch callState{
    case LinphoneCallStateIncomingReceived: /**<This is a new incoming call */
        NSLog("callStateChanged: LinphoneCallIncomingReceived")
        print("Call Coming!!!!!!!!")
        callStatus = G_CALL_COMING
        callStatusNumber = 4
        isRecord = false
        
    case LinphoneCallStateOutgoingRinging: /**<An outgoing call ringing at remote end*/
        NSLog("callStateChanged: LinphoneCallOutgoingRinging")
        print("Outgoing Call Ringing...")
        callStatus = G_CALL_OUTGOING_RINGING
        callStatusNumber = 3
        isRecord = false
        
    case LinphoneCallStateStreamsRunning: /**<The media streams are established and running*/
        NSLog("callStateChanged: LinphoneCallStreamsRunning")
        print("Talking...")
        callStatus = G_CALL_STREAMS_RUNNING
        
    case LinphoneCallStateConnected: /**<Connected, the call is answered */
        NSLog("callStateChanged: LinphoneCallConnected")
        print("Call Connected!")
        callStatus = G_CALL_CONNECTED
        callStatusNumber = callStatusNumber - 2
        isRecord = false
        
    case LinphoneCallStateError: /**<The call encountered an error*/
        NSLog("callStateChanged: LinphoneCallError")
        print("Call Error?!!!!")
        callStatus = G_CALL_ERROR
        
    case LinphoneCallStateEnd: /**<The call ended normally*/
        NSLog("callStateChanged: LinphoneCallEnd")
        print("Call End...")
        callStatus = G_CALL_END
        isRecord = false
        isSendNotification = false
        
    case LinphoneCallStateReleased:
        NSLog("callStateChanged: LinphoneCallReleased")
        print("Call Released!")
        callStatus = G_CALL_RELEASED
        
    default:
        NSLog("Default call state")
        print("@%#$^$R%&%^*%")
        callStatus = G_CALL_OTHER_STATE
    }}

var parentViewController: UIViewController!
//var lc: OpaquePointer!

struct OutgoingCallVT {
    static var lct: LinphoneCoreVTable = LinphoneCoreVTable()
}

class LinphoneManager {
    
    var lc: OpaquePointer!
    //    var lct = OutgoingCallVT.lct
    var lct: LinphoneCoreVTable = LinphoneCoreVTable()
    
    var calleeAccount = ""
    var calleeName: String = ""
    var calleeAddress: String!
    
    var viewController: SIPCallViewController!
    
    var account: String!
    var password: String!
    var domain: String!
    
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    lazy var sipCallPresenter: SIPCallPresenter = {
        let presenter = SIPCallPresenter(mainWindow: (UIApplication.shared.delegate?.window)!, viewController: sipCallViewController)
        return presenter
    }()
    
    var isShown = false
    
    init(account: String, password: String, domain: String) {
        
        
        print("linphone init")
        
        // Enable debug log to stdout
        linphone_core_set_log_file(nil)
        //        linphone_core_set_log_level(CTL_DEBUG)
        
        
        
        // Load config
        let configFilename = documentFile("linphonerc")
        let factoryConfigFilename = bundleFile("linphonerc-factory")
        
        let configFilenamePtr: UnsafePointer<Int8> = configFilename.cString(using: String.Encoding.utf8.rawValue)!
        let factoryConfigFilenamePtr: UnsafePointer<Int8> = factoryConfigFilename.cString(using: String.Encoding.utf8.rawValue)!
        let lpConfig = linphone_config_new_with_factory(configFilenamePtr, factoryConfigFilenamePtr)
        
        // Set Callback
        lct.registration_state_changed = registrationStateChanged
        lct.call_state_changed = callStateChanged
        
        lc = linphone_core_new_with_config(&lct, lpConfig, nil)
        
        // Set ring asset
        //        let ringbackPath = NSURL(fileURLWithPath: NSBundle.mainBundle().bundlePath).URLByAppendingPathComponent("/ringback.wav").absoluteString
        let ringbackPath = Bundle.main.path(forResource: "ringback", ofType: "wav")
        linphone_core_set_ringback(lc, ringbackPath!)
        
        let localRing = Foundation.URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent("/bell.wav").absoluteString
        linphone_core_set_ring(lc, localRing)
        
        self.account = account
        self.password = password
        self.domain = domain
        _ = setIdentify(account: account, password: password, domain: domain)
        
        //        NotificationCenter.default.addObserver(self, selector: #selector(reinstateBackgroundTask), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
    }
    
    fileprivate func bundleFile(_ file: NSString) -> NSString{
        return Bundle.main.path(forResource: file.deletingPathExtension, ofType: file.pathExtension)! as NSString
    }
    
    fileprivate func documentFile(_ file: NSString) -> NSString {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        
        let documentsPath: NSString = paths[0] as NSString
        return documentsPath.appendingPathComponent(file as String) as NSString
    }
    
    func demo() {
        //        makeCall()
        //        autoPickImcomingCall()
        idle()
    }
    
    var call: OpaquePointer!
    
    func makeCall() {
        
        //        setIdentify()
        print("callee: \(calleeAccount)")
        call = linphone_core_invite(lc, calleeAccount)
        UIApplication.topViewController()?.present(sipCallViewController, animated: true, completion: nil)
        
    }
    
    func receiveCall() {
        //        mainLoop(60)
        //        linphone_core_iterate(lc)
        self.scheduledTimerWithTimeIntervalBackgroundTask(second: 0.01)
    }
    
    func idle(){
        guard let proxyConfig = setIdentify(account: self.account, password: self.password, domain: self.domain) else {
            print("no identity")
            return
        }
        register(proxyConfig)
        mainLoop(100)
        shutdown()
    }
    
    func pickUp() {
        call = linphone_core_get_current_call(lc)
        linphone_core_accept_call(lc, call)
        //        mainLoop(10)
    }
    
    // MARK: - CallKit
    func pickUpWithCallKit() -> OpaquePointer? {
        
        //        let calls = linphone_core_get_calls(lc)
        let linphoneCall = linphone_core_get_current_call(lc)
        //        let callLog = linphone_call_get_call_log(call)
        //        let callID = linphone_call_log_get_call_id(callLog)
        //
        //        strcmp(callID, uuid)
        //        bctbx_compare_func
        //        let callTmp = bctbx_list_find_custom(calls, strcmp(callID, uuid), <#T##user_data: UnsafeRawPointer!##UnsafeRawPointer!#>)
        //        bctbx_compare_func
        return linphoneCall
    }
    
    func accept(call: OpaquePointer) {
        let localParams = linphone_core_create_call_params(lc, call)!
        
        linphone_call_accept_with_params(call, localParams)
        
        
    }
    
    
    
    
    func setIdentify(account: String, password: String, domain: String) -> OpaquePointer? {
        
        // Reference: http://www.linphone.org/docs/liblinphone/group__registration__tutorials.html
        
        let identity = "sip:" + account + "@" + domain;
        print("domain: \(domain)")
        
        /*create proxy config*/
        //        let proxy_cfg = linphone_proxy_config_new(); /* deprecated, use #linphone_core_create_proxy_config instead */
        let proxy_cfg = linphone_core_create_proxy_config(lc)
        
        
        /*parse identity*/
        let address = linphone_address_new(identity);
        
        if (address == nil){
            NSLog("\(identity) not a valid sip uri, must be like sip:toto@sip.linphone.org");
            return nil
        }
        
        //        let a = linphone_core_get_auth_info_list(lc!)
        
        // configure proxy entries
        linphone_proxy_config_set_identity(proxy_cfg, identity); /*set identity with user name and domain*/
        let port = linphone_address_get_port(address);
        //        print("port: \(port)")
        let server_addr = String(cString: linphone_address_get_domain(address))+":"+String(port); /*extract domain address from identity*/
        //        print("server_address: \(server_addr)")
        linphone_proxy_config_set_server_addr(proxy_cfg, server_addr); /* we assume domain = proxy server address*/
        
        linphone_proxy_config_enable_publish(proxy_cfg, 0)
        linphone_proxy_config_enable_register(proxy_cfg, 1); /* activate registration for this proxy config*/
        
        
        let info=linphone_auth_info_new(linphone_address_get_username(address), nil, password, nil, nil, nil); /*create authentication structure from identity*/
        linphone_core_add_auth_info(lc, info); /*add authentication info to LinphoneCore*/
        
        linphone_address_unref(address)/*release resource*/
        
        
        if linphone_core_add_proxy_config(lc, proxy_cfg) != -1 {
            linphone_core_set_default_proxy_config(lc, proxy_cfg);
        }
        
        //        linphone_core_add_proxy_config(lc, proxy_cfg); /*add proxy config to linphone core*/
        //        linphone_core_set_default_proxy_config(lc, proxy_cfg); /*set to default proxy*/
        
        
        //        linphone_address_destroy(from); /*release resource*/
        
        
        
        
        
        return proxy_cfg!
    }
    
    func register(_ proxy_cfg: OpaquePointer){
        linphone_proxy_config_enable_register(proxy_cfg, 1); /* activate registration for this proxy config*/
    }
    
    func mainLoop(_ sec: Int){
        let time = sec * 100
        /* main loop for receiving notifications and doing background linphonecore work: */
        for _ in 1...time{
            //            print("main loop call status: \(callStatus)")
            
            //            DispatchQueue.global().async(execute: {
            ////                print("teste")
            DispatchQueue.main.async {
                //                    print("main thread")
                linphone_core_iterate(self.lc); /* first iterate initiates registration */
            }
            //            })
            
            ms_usleep(10000);
            
            if(callStatus == G_CALL_COMING && !isRecord) {
                
                let address = linphone_core_get_current_call_remote_address(lc)
                /*
                 uriString: sip:110@192.168.88.231
                 uriString: sip:account@domain
                 */
                //                let uri = linphone_address_as_string_uri_only(address)
                //                let uriString = NSString(UTF8String: uri)
                /*
                 allString: "110" <sip:110@192.168.88.231>
                 allString: "displayname" <sip:account@domain>
                 */
                let remoteData = linphone_address_as_string(address)
                let remoteDataString = NSString(utf8String: remoteData!)
                calleeAccount = remoteDataString!.substring(with: NSRange(location: 1, length: 3))
                
            }
            
            if(callStatus == G_CALL_COMING && isRunningInBackground() && !isSendNotification) {
                // If call is coming and app is running in background, send local notification
                //                self.viewController.scheduleLocalNotification()
                //                isSendNotification = true
            }
            
            // Update UI when detect call state updated
            //            DispatchQueue.global().async(execute: {
            //                print("teste")
            DispatchQueue.main.async {
                //                    print("main thread")
                self.viewController.updateUIWhenCallStatusChanged(callStatus)
            }
            //            })
        }
    }
    
    func isRunningInBackground() -> Bool {
        let appState = UIApplication.shared.applicationState
        return appState == UIApplicationState.background
        
    }
    
    // MARK: - Background Task
    func scheduledTimerWithTimeIntervalBackgroundTask(second: Double){
        // Scheduling timer to Call the function **Countdown** with the interval of 1 seconds
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(second), target: self, selector: #selector(self.testBackgroundCall), userInfo: nil, repeats: true)
    }
    
    // MARK: - Performing Finite-Length Tasks�� or, Whatever
    func registerBackgroundTask() {
        
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            print("background task by Phone")
            self?.endBackgroundTask()
        }
        
        assert(backgroundTask != UIBackgroundTaskInvalid)
    }
    
    func endBackgroundTask() {
        print("Background task ended.")
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = UIBackgroundTaskInvalid
    }
    
    @objc func reinstateBackgroundTask() {
        if timer != nil && (backgroundTask == UIBackgroundTaskInvalid) {
            print("reinstate background task")
            registerBackgroundTask()
        }
    }
    
    @objc func testBackgroundCall() {
        
        linphone_core_iterate(lc)
        //        print("call status: \(callStatus)")
        
        switch UIApplication.shared.applicationState {
        case .active:
            //            print("App is active")
            if(callStatus == G_CALL_COMING) {
                if !isShown {
                    call = linphone_core_get_current_call(lc)
                    
                    if let address = linphone_call_get_remote_address(call) {
                        //                    let addressString = String(cString: address)
                        
                        if let displayName = linphone_address_get_display_name(address) {
                            let displayNameString = String(cString: displayName)
                            linphoneManager?.calleeName = displayNameString
                            
                            if let userName = linphone_address_get_username(address) {
                                let userNameString = String(cString: userName)
                                linphoneManager?.calleeAccount = userNameString
                            }
                            
                        }
                        
                        
                    }
                    //                linphoneManager?.calleeName
                    UIApplication.topViewController()?.present(sipCallViewController, animated: true, completion: nil)
                    isShown = !isShown
                    print("is show: \(isShown)")
                }
                
            } else if callStatus == G_CALL_END {
                if isShown {
                    sipCallViewController.dismiss(animated: true, completion: nil)
                    isShown = !isShown
                    print("is show: \(isShown)")
                }
                
            }
            
            DispatchQueue.main.async {
                self.viewController.updateUIWhenCallStatusChanged(callStatus)
            }
            
        case .background:
            //            print("App is backgrounded")
            //            print("Background time remaining = \(UIApplication.shared.backgroundTimeRemaining) seconds")
            //            if UIApplication.shared.backgroundTimeRemaining < 5 {
            //                reinstateBackgroundTask()
            //            }
            //            if(callStatus == G_CALL_COMING) {
            //                if #available(iOS 10.0, *) {
            //                    let provider = ProviderDelegate()
            //                    provider.reportIncomingCall(uuid: UUID(), handle: self.calleeName, completion: { error in })
            //                }
            //            }
            break
        case .inactive:
            print("App inactive")
            
            break
        }
        
        
    }
    
    //    func mainLoop2(sec: Int) {
    //        let time = sec * 100
    //        for _ in 1...time {
    //            linphone_core_iterate(lc);
    //            ms_usleep(10000);
    //            if( isCallEnd ) {
    //                print("leave main loop 2!!")
    //                break
    //            }
    //        }
    //    }
    
    func shutdown(){
        NSLog("Shutdown..")
        /* Unregistration */
        //        let proxy_cfg = linphone_core_get_default_proxy_config(lc); /* get default proxy config*/
        //        linphone_proxy_config_edit(proxy_cfg); /*start editing proxy configuration*/
        //        linphone_proxy_config_enable_register(proxy_cfg, 0); /*de-activate registration for this proxy config*/
        //        linphone_proxy_config_done(proxy_cfg); /*initiate REGISTER with expire = 0*/
        
        linphone_core_terminate_call(lc, call)
        //        linphone_core_terminate_all_calls(lc)
        print("terminate call")
        
        //        linphone_core_destroy(lc);
    }
}

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }
    
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if (cString.hasPrefix("#")) { cString.removeFirst() }
        
        if ((cString.count) != 6) {
            self.init(hex: "ff0000") // return red color for wrong hex input
            return
        }
        
        var rgbValue: UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        
        self.init(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                  green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                  blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                  alpha: alpha)
    }
}

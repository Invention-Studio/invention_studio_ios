//
//  LoginVC.swift
//  invention-studio-ios
//
//  Created by Noah Sutter on 1/22/18.
//  Copyright © 2018 Invention Studio at Georgia Tech. All rights reserved.
//

import UIKit
import WebKit
import FirebaseMessaging

class LoginVC: ISViewController, WKUIDelegate, WKNavigationDelegate, WKHTTPCookieStoreObserver {
    

    // VARIABLE DECLARATIONS
    //The Web View
    var webView: WKWebView!
    //The cookie we will receive once authenticated
    var CAScookie: HTTPCookie!
    //The flag used to know if the cookie has been received (used to know when to segue)
    var cookieReceived = false
    //The storage that will containt the cookies
    let storage = WKWebsiteDataStore.default()
    var cookieStore:WKHTTPCookieStore!

    var errorMessage: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //Preparing the request for the login page
#if DEBUG
        let redirectService = "https://sums-dev.gatech.edu/EditResearcherProfile.aspx" //Development
#else
        let redirectService = "https://sums.gatech.edu/EditResearcherProfile.aspx" //Production
#endif

        let myURL = URL(string: "https://login.gatech.edu/cas/login?service=" + redirectService)
        let myRequest = URLRequest(url: myURL!)

        //Setting up the cookie store
        cookieStore = storage.httpCookieStore
        cookieStore.add(self)

        //Making this class the navigation delegate
        webView.navigationDelegate = self

        //Requesting the login page
        webView.load(myRequest)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func loadView() {
        //Setting up the webview
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        view = webView
    }


    //This function is called when navigation is finished
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if self.cookieReceived {
            //Navigation has finished and we have the cookie:

            //Use this to block future calls that rely on the results of the two evaluateJavaScript (async) calls
            let jsEvalGroup = DispatchGroup()

            jsEvalGroup.enter() //Enter the dispatch group to block until completed
            //Asynchronus, will return and continue before completionHandler is called
            webView.evaluateJavaScript("document.querySelector('[id$=\"UsernameDisplay\"]').innerText", completionHandler: { (result, err) in
                let username = result as! String //Get the results
                UserDefaults.standard.set(username, forKey: "Username") //Save to user defaults
                jsEvalGroup.leave() //Mark action as completed in dispatch group
            });

            jsEvalGroup.enter() //Enter the dispatch group to block until completed
            //Asynchronus, will return and continue before completionHandler is called
            webView.evaluateJavaScript("document.querySelector('[id$=\"CalendarLink\"]').innerText",
                completionHandler: { (result, err) in
                    let calendarDisplay = result as! String //Get the results
                    let calendarLink = "https://sums.gatech.edu/SUMS/rest/iCalendar/ReturnData?Key=" //Static calendar link to be stripped
                    let userKey = calendarDisplay.replacingOccurrences(of: calendarLink, with: "") //Strip the calendar link
                    UserDefaults.standard.set(userKey, forKey: "UserKey") //Save to user defaults
                    jsEvalGroup.leave() //Mark action as completed in dispatch group
            });

            //When both evaluateJavaScript calls complete, enter this block
            jsEvalGroup.notify(queue: .main, execute: {
                var isInventionStudio = false
                //Used to block until User_Info API request is completed
                let apiEvalGroup = DispatchGroup()

                apiEvalGroup.enter()
                //Asynchronus, will return and continue before completionHandler is called
                SumsApi.User.Info(completion: { results, error in
                    if error != nil {
                        let parts = error!.components(separatedBy: ":")
                        self.alert(title: parts[0], message: parts[1])
                        return
                    }
                    
                    for u in results! {
                        //Check all of the user's tool groups
                        if u.isInventionStudio() {
                            isInventionStudio = true
                            UserDefaults.standard.set(u.equipmentGroupId, forKey: "DepartmentId")
                            UserDefaults.standard.set(u.userName, forKey: "Name")
                            break
                        }
                    }
                    apiEvalGroup.leave()
                })

                //When API call is complete
                apiEvalGroup.notify(queue: .main, execute: {

                    if isInventionStudio {let form = LoginForm()
                        if let username = UserDefaults.standard.string(forKey: "Username") {                            form.user_username = username
                        }
                        if let name = UserDefaults.standard.string(forKey: "Name") {
                            form.user_name = name
                        }
                        if let apiKey = UserDefaults.standard.string(forKey: "UserKey") {
                            form.api_key = apiKey
                        }

                        let loginEvalGroup = DispatchGroup()
                        var responseMessage = ""
                        loginEvalGroup.enter()
                        InventionStudioApi.User.login(form: form, completion: { message in
                            responseMessage = message
                            loginEvalGroup.leave()
                        })

                        loginEvalGroup.notify(queue: .main, execute: {
                            let parts = responseMessage.components(separatedBy: ":")
                            if parts[0] == "Login Error" {
                                self.errorMessage = responseMessage
                                self.performSegue(withIdentifier: "cancelLoginSegue", sender: self)
                            } else {
                                self.performSegue(withIdentifier: "cookieReceivedSegue", sender: self)
                            }
                        })
                        
                    } else {
                        //TODO: add need to sign agreement page
                        self.performSegue(withIdentifier: "safetyAgreementSegue", sender: self)
                    }
                })
            })
        }
    }

    //This function is called whenever there are changes to the cookie store
    func cookiesDidChange(in cookieStore:WKHTTPCookieStore) {
        cookieStore.getAllCookies({ (cookies) in
            for index in 0..<cookies.count {
                //Checking for the CAS cookie
                if cookies[index].name == "CASTGT" {
                    //Checking if the CAS cookie has changed
                    if cookies[index] != self.CAScookie {
                        //Updating our stored cookie and setting the cookie flag to true
                        self.CAScookie = cookies[index]
                        self.cookieReceived = true
                    }
                }
            }
        })
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "cookieReceivedSegue" {
            UserDefaults.standard.set(true, forKey: "LoggedIn")
            let weekInterval: TimeInterval = 60 * 60 * 24 * 7
            //TODO: Use server time
            UserDefaults.standard.set(NSDate().addingTimeInterval(weekInterval).timeIntervalSince1970, forKey:"LoginSession")

            if let username = UserDefaults.standard.string(forKey: "Username") {
                Messaging.messaging().subscribe(toTopic: "\(username)_ios")
            }
        }
    }

    func alert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
}


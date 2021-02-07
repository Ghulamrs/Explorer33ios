//
//  ViewController.swift
//  Explorer
//
//  Created by Home on 7/16/18.
//  Copyright © 2018 Home. All rights reserved.
//

import UIKit
import CoreFoundation
import Foundation

class ViewController: UIViewController {
    struct Response : Decodable {
        let success: Int
        let message: String
        
        init(json: [String: Any]) {
            success = json["success"] as? Int ?? 0
            message = json["message"] as? String ?? ""
        }
    }

    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var password2: UITextField!
    var response = [Response]()
    var user = UserPreference()

    override func viewDidLoad() {
        super.viewDidLoad()

        if user.loadUserInfo() != nil { // check! if already stored profile
            print("User: \(String(describing: user.pid)), Name: \(String(describing: user.name)) ")
//            let message = String("Pid: \(user.pid), Name: \(user.name) ")
//            self.showAlert(title: "Error", message: message)
            self.performSegue(withIdentifier: "SkipLogin", sender: self)
        }
    }

    @IBAction func SignUp(_ sender: UIButton) {
        if(username.hasText && password.hasText && password2.hasText) {
            let usernameLength = (username.text?.count)!
            let passwordLength = (password.text?.count)!
            if(usernameLength >= 3 && passwordLength > 5 && password.text == password2.text) {
                user.update(usr: username.text!, psw: password.text!)
                loginMessage()
            } else {
                let message = "Passwords enetered do not match !!!"
                self.showAlert(title: "Error", message: message)
            }
        } else {
            let message = "Please enter username and/or password !!!"
            self.showAlert(title: "Error", message: message)
        }
    }

    func showAlert(title: String, message: String, style: UIAlertController.Style = .alert) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: style)
        let action = UIAlertAction(title: title, style: .default) { (action) in
            self.dismiss(animated: true, completion: nil)
        }
        alertController.addAction(action)
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func Cancel(_ sender: UIButton) {
        exit(0)
    }

    func loginMessage() {
        let url = URL(string: user.myUrl+"login.php")
        var urlrequest = URLRequest(url: url!)
        urlrequest.httpMethod = "POST"

        let postString = String("name="+user.name+"&pswd="+user.pswd)
        urlrequest.httpBody = postString.data(using: .utf8, allowLossyConversion: true)
        URLSession.shared.dataTask(with: urlrequest, completionHandler: { (data, response, error) in
            
            if error != nil {
                print("Failed to get data from url")
                return
            }

            do {
                let decoder = JSONDecoder()
                self.response = [try decoder.decode(Response.self, from: data!)]
                DispatchQueue.main.async {
                    self.CloseUp()
                }
            }
            catch {
                print(error)
            }
        }).resume()
    }

    func CloseUp() {
        let result = response[0].success
        if  result > 0 {
            user.pid = UInt(result)
            user.saveUserInfo()
        }
        else {
//            ErrorRegistration(msg: response[0].message)
            user.saveUserInfo()
        }
    }

    func ErrorRegistration(msg: String) {
        let alert = UIAlertController(title: "Error Registration", message: msg, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

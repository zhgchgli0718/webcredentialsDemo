//
//  ViewController.swift
//  webcredentialsDemo
//
//  Created by Harris Li on 2021/2/2.
//

import AuthenticationServices
import UIKit

struct UnexpectedError: Error { }

class ViewController: UIViewController {

    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!
    
    @IBAction func generatePasswordButtonClicked(_ sender: Any) {
        let password = SecCreateSharedWebCredentialPassword() as String? ?? ""
        self.passwordTextField.text = password
        self.resultTextView.text = "SecCreateSharedWebCredentialPassword: \(password)"
    }
    
    @IBAction func saveButtonClicked(_ sender: Any) {
        let domain = "zhgchg.li"
        let password = self.passwordTextField.text //Pass NULL to remove a shared password if it exists.
                
        guard let account = self.usernameTextField.text else {
            self.resultTextView.text = "SecAddSharedWebCredential failure, account is nil"
            return
        }
        
        SecAddSharedWebCredential(domain as CFString, account as CFString, password as CFString?) { (error) in
            DispatchQueue.main.async {
                guard error == nil else {
                    self.resultTextView.text = "SecAddSharedWebCredential failure \(String(describing: error))"
                    print(error as Any)
                    return
                }
                self.resultTextView.text = "SecAddSharedWebCredential success"
            }
        }
    }
    
    @IBAction func selectButtonClicked(_ sender: Any) {
        if #available(iOS 13, *) {
            let request: ASAuthorizationPasswordRequest = ASAuthorizationPasswordProvider().createRequest()
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        } else {
            SecRequestSharedWebCredential(nil, nil) { (credentials, error) in
                guard error == nil else {
                    DispatchQueue.main.async {
                        self.credentialDidRequest?(.failure(error ?? UnexpectedError()))
                    }
                    return
                }
                guard CFArrayGetCount(credentials) > 0,
                      let dict = unsafeBitCast(CFArrayGetValueAtIndex(credentials, 0), to: CFDictionary.self) as? Dictionary<String, String>,
                      let account = dict[kSecAttrAccount as String],
                      let password = dict[kSecSharedPassword as String] else {
                    DispatchQueue.main.async {
                        self.credentialDidRequest?(.failure(error ?? UnexpectedError()))
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.credentialDidRequest?(.success((account, password)))
                }
            }
        }
    }
    
    @IBAction func submitButtonClicked(_ sender: Any) {
        var result = "Result: \n"
        result += "Account: \(String(describing: self.usernameTextField.text)) \n"
        result += "Password: \(String(describing: self.passwordTextField.text)) \n"
        
        self.resultTextView.text = result
    }
    
    private var credentialDidRequest: ((Result<(String, String), Error>) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        usernameTextField.textContentType = .username
        passwordTextField.textContentType = .password
        
        self.credentialDidRequest = { result in
            switch result {
            case .success(let info):
                self.usernameTextField.text = info.0
                self.passwordTextField.text = info.1
                self.resultTextView.text = "credentialDidRequest success \(info)"
            case .failure(let error):
                self.resultTextView.text = "credentialDidRequest failure \(error)"
                print(error)
            }
        }
    }
}

extension ViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        
        if let credential = authorization.credential as? ASPasswordCredential {
            credentialDidRequest?(.success((credential.user, credential.password)))
        }
        // else if as? ASAuthorizationAppleIDCredential... sign in with apple
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        credentialDidRequest?(.failure(error))
    }
}

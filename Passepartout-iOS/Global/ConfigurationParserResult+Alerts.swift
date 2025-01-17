//
//  OpenVPN.ConfigurationParserResult+Alerts.swift
//  Passepartout-iOS
//
//  Created by Davide De Rosa on 10/27/18.
//  Copyright (c) 2019 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of Passepartout.
//
//  Passepartout is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Passepartout is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Passepartout.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import UIKit
import TunnelKit
import SwiftyBeaver
import PassepartoutCore

private let log = SwiftyBeaver.self

extension OpenVPN.ConfigurationParser.Result {
    static func from(_ url: URL, withErrorAlertIn viewController: UIViewController, passphrase: String?,
                     passphraseBlock: @escaping (String) -> Void, passphraseCancelBlock: (() -> Void)?) -> OpenVPN.ConfigurationParser.Result? {

        let result: OpenVPN.ConfigurationParser.Result
        let fm = FileManager.default

        log.debug("Parsing configuration URL: \(url)")
        do {
            result = try OpenVPN.ConfigurationParser.parsed(fromURL: url, passphrase: passphrase)
        } catch let e as ConfigurationError {
            switch e {
            case .encryptionPassphrase, .unableToDecrypt(_):
                let alert = Macros.alert(url.normalizedFilename, L10n.ParsedFile.Alerts.EncryptionPassphrase.message)
                alert.addTextField { (field) in
                    field.isSecureTextEntry = true
                }
                alert.addDefaultAction(L10n.Global.ok) {
                    guard let passphrase = alert.textFields?.first?.text else {
                        return
                    }
                    passphraseBlock(passphrase)
                }
                alert.addCancelAction(L10n.Global.cancel) {
                    passphraseCancelBlock?()
                }
                viewController.present(alert, animated: true, completion: nil)
            
            default:
                let message = localizedMessage(forError: e)
                alertImportError(url: url, in: viewController, withMessage: message)
                try? fm.removeItem(at: url)
            }
            return nil
        } catch let e {
            let message = localizedMessage(forError: e)
            alertImportError(url: url, in: viewController, withMessage: message)
            try? fm.removeItem(at: url)
            return nil
        }
        return result
    }
    
    private static func alertImportError(url: URL, in vc: UIViewController, withMessage message: String) {
        let alert = Macros.alert(url.normalizedFilename, message)
//        alert.addDefaultAction(L10n.ParsedFile.Alerts.Buttons.report) {
//            var attach = IssueReporter.Attachments(debugLog: false, configurationURL: url)
//            attach.description = message
//            IssueReporter.shared.present(in: vc, withAttachments: attach)
//        }
        alert.addCancelAction(L10n.Global.ok)
        vc.present(alert, animated: true, completion: nil)
    }

    static func alertImportWarning(url: URL, in vc: UIViewController, withWarning warning: ConfigurationError, completionHandler: @escaping (Bool) -> Void) {
        let message = details(forWarning: warning)
        let alert = Macros.alert(url.normalizedFilename, L10n.ParsedFile.Alerts.PotentiallyUnsupported.message(message))
        alert.addDefaultAction(L10n.Global.ok) {
            completionHandler(true)
        }
        alert.addCancelAction(L10n.Global.cancel) {
            completionHandler(false)
        }
        vc.present(alert, animated: true, completion: nil)
    }
    
    private static func localizedMessage(forError error: Error) -> String {
        if let appError = error as? ConfigurationError {
            switch appError {
            case .malformed(let option):
                log.error("Could not parse configuration URL: malformed option, \(option)")
                return L10n.ParsedFile.Alerts.Malformed.message(option)

            case .missingConfiguration(let option):
                log.error("Could not parse configuration URL: missing configuration, \(option)")
                return L10n.ParsedFile.Alerts.Missing.message(option)
                
            case .unsupportedConfiguration(let option):
                log.error("Could not parse configuration URL: unsupported configuration, \(option)")
                return L10n.ParsedFile.Alerts.Unsupported.message(option)
                
            default:
                break
            }
        }
        log.error("Could not parse configuration URL: \(error)")
        return L10n.ParsedFile.Alerts.Parsing.message(error.localizedDescription)
    }
    
    private static func details(forWarning warning: ConfigurationError) -> String {
        switch warning {
        case .malformed(let option):
            return option
            
        case .missingConfiguration(let option):
            return option
            
        case .unsupportedConfiguration(let option):
            return option
            
        default:
            return "" // XXX: should never get here
        }
    }
}

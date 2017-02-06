//
//  UIProcedure.swift
//  Kiwix
//
//  Created by Chris Li on 1/18/17.
//  Copyright © 2017 Chris Li. All rights reserved.
//

import MessageUI
import ProcedureKit

// MARK: - Feedback

class FeedbackMailOperation: UIProcedure, MFMailComposeViewControllerDelegate {
    let controller = MFMailComposeViewController()
    
    init(context: UIViewController) {
        controller.setToRecipients(["chris@kiwix.org"])
        controller.setSubject(Localized.Setting.Feedback.subject)
        super.init(present: controller, from: context, withStyle: PresentationStyle.present, inNavigationController: false, finishAfterPresenting: false)
        controller.mailComposeDelegate = self
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        if let error = error {
            let alert = AlertProcedure.Feedback.emailNotSent(context: controller, message: error.localizedDescription)
            alert.addDidFinishBlockObserver(block: { [weak self] (alert, errors) in
                self?.presented.dismiss(animated: true, completion: nil)
                self?.finish(withError: error)
            })
            try? produce(operation: alert)
        } else {
            guard result == .sent else {
                presented.dismiss(animated: true, completion: nil)
                finish()
                return
            }
            let alert = AlertProcedure.Feedback.emailSent(context: controller)
            alert.addDidFinishBlockObserver(block: { [weak self] (alert, errors) in
                self?.presented.dismiss(animated: true, completion: nil)
                self?.finish()
            })
            try? produce(operation: alert)
        }
    }
}

extension AlertProcedure {
    class Feedback {
        static func emailSent(context: UIViewController) -> AlertProcedure {
            let alert = AlertProcedure(presentAlertFrom: context)
            alert.title = Localized.Setting.Feedback.Success.title
            alert.message = Localized.Setting.Feedback.Success.message
            alert.add(actionWithTitle: Localized.Common.ok, style: .default)
            return alert
        }
        
        static func emailNotConfigured(context: UIViewController) -> AlertProcedure {
            let alert = AlertProcedure(presentAlertFrom: context)
            alert.title = Localized.Setting.Feedback.NotConfiguredError.title
            alert.message = Localized.Setting.Feedback.NotConfiguredError.message
            alert.add(actionWithTitle: Localized.Common.ok, style: .cancel)
            return alert
        }
        
        static func emailNotSent(context: UIViewController, message: String?) -> AlertProcedure {
            let alert = AlertProcedure(presentAlertFrom: context)
            alert.title = Localized.Setting.Feedback.ComposerError.title
            alert.message = message
            alert.add(actionWithTitle: Localized.Common.ok, style: .cancel)
            return alert
        }
    }
    
    static func rateKiwix(context: UIViewController) -> AlertProcedure {
        let alert = AlertProcedure(presentAlertFrom: context)
        alert.title = Localized.Setting.rateApp
        alert.message = Localized.Setting.RateApp.message
        alert.add(actionWithTitle: Localized.Setting.RateApp.goToAppStore, style: .default) { _ in
            let url = URL(string: "http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=997079563&pageNumber=0&sortOrdering=2&type=Purple+Software&mt=8")!
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        alert.add(actionWithTitle: Localized.Common.cancel, style: .cancel)
        return alert
    }
    
}

// MARK: - Library 

extension AlertProcedure {
    class Library {
        static func languageFilter(context: UIViewController) -> AlertProcedure {
            assert(Thread.isMainThread)
            let preferredLangCodes = Locale.preferredLangCodes
            let languages = Language.fetchAll(AppDelegate.persistentContainer.viewContext)
            let alert = AlertProcedure(presentAlertFrom: context)
            alert.title = Localized.Library.LanguageFilterAlert.title
            alert.message = {
                let lang = Locale.preferredLangNames
                return "You have set " + lang.joined(separator: ", ") + " as the preferred language of the device. " + "Would you like to hide books in other languages?"
            }()
            alert.add(actionWithTitle: "Hide Other Languages", style: .default) { (procedure, action) in
                languages.forEach({ $0.isDisplayed = preferredLangCodes.contains($0.code) })
            }
            alert.add(actionWithTitle: "Show All Languages", style: .default) { (procedure, action) in
                languages.forEach({$0.isDisplayed = false})
            }
            alert.addDidFinishBlockObserver { _ in
                let managedObjectContext = AppDelegate.persistentContainer.viewContext
                if managedObjectContext.hasChanges { try? managedObjectContext.save() }
                (context as? LibraryBooksController)?.reloadFetchedResultController()
            }
            return alert
        }
        
        static func more(context: UIViewController, book: Book) -> AlertProcedure {
            assert(Thread.isMainThread)
            let alert = AlertProcedure(presentAlertFrom: context, withPreferredStyle: .actionSheet, waitForDismissal: true)
            alert.title = book.title
            alert.message = book.desc
            if book.state == .cloud {
                alert.add(actionWithTitle: Localized.Library.download, style: .default) { _ in
                    Network.shared.start(bookID: book.id)
                    alert.finish()
                }
                alert.add(actionWithTitle: Localized.Library.copyURL, style: .default) { _ in
                    guard let url = book.url else {return}
                    UIPasteboard.general.string = url.absoluteString
                    alert.finish()
                }
            } else if book.state == .local {
                alert.add(actionWithTitle: "Remove", style: .default) { _ in
                    guard let fileURL = ZimMultiReader.shared.readers[book.id]?.fileURL else {return}
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
            
            alert.add(actionWithTitle: Localized.Common.cancel, style: .cancel) { _ in alert.finish() }
            return alert
        }
        
        static func refreshError(context: UIViewController, message: String) -> AlertProcedure {
            assert(Thread.isMainThread)
            let alert = AlertProcedure(presentAlertFrom: context)
            alert.title = Localized.Library.RefreshError.title
            alert.message = message
            alert.add(actionWithTitle: Localized.Common.ok)
            return alert
        }
    }
}


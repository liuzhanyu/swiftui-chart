//
//  NotificationServiceHandler.swift
//  NotificationService
//
//  Created by 韩颖 on 2026/7/18.
//

import Foundation
import UserNotifications

actor NotificationServiceHandler {
    
    private var activeWork: NotificationWork?
    
    func didReceive(work: NotificationWork) async {

        activeWork = work
        
        // MARK: 下载通知附件
        
        if let downloadUrl = URL(string: "urlstr") {
            do {
                let attachment = try await downloadAttachment(from: downloadUrl)
                
                guard activeWork != nil else {
                    return
                }
                
                work.content.attachments = [attachment]
            } catch {
                
            }
        }
        
        finishActiveWork()
    }
    
    private func downloadAttachment(
        from remoteURL: URL
    ) async throws -> UNNotificationAttachment {
        let (temporaryURL, _) =
            try await URLSession.shared.download(
                from: remoteURL
            )

        let identifier = UUID().uuidString

        let fileExtension = remoteURL.pathExtension.isEmpty
            ? "jpg"
            : remoteURL.pathExtension

        let destinationURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(identifier)
            .appendingPathExtension(fileExtension)

        try FileManager.default.moveItem(
            at: temporaryURL,
            to: destinationURL
        )

        return try UNNotificationAttachment(
            identifier: identifier,
            url: destinationURL,
            options: nil
        )
    }
    
    // MARK: - Expiration
    
    func serviceExtensionTimeWillExpire() {
        guard let activeWork else {
            return
        }
        finishActiveWork()
    }
    
    
    private func finishActiveWork() {
        guard let work = activeWork else {
            return
        }
        activeWork = nil
        work.complete()
    }
}


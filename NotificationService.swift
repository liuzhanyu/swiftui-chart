//
//  NotificationService.swift
//  NotificationService
//
//  Created by 韩颖 on 2026/7/18.
//
//


import Foundation
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {

    private let handler = NotificationServiceHandler()

    // 系统方法 接收到富文本通知
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler:
            @escaping (UNNotificationContent) -> Void
    ) {
        guard let mutableContent =
                request.content.mutableCopy()
                    as? UNMutableNotificationContent
        else {
            contentHandler(request.content)
            return
        }

        // 在进入 Task 之前包装非 Sendable 系统回调。
        let notificationWork = NotificationWork(
            content: mutableContent,
            contentHandler: contentHandler
        )

        // 避免 Task 捕获 self。
        let handler = self.handler

        Task {
            await handler.didReceive(work: notificationWork)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // 避免 Task 捕获 self。
        let handler = self.handler

        Task {
            await handler.serviceExtensionTimeWillExpire()
        }
    }
}

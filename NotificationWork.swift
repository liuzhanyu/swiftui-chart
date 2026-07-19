//
//  NotificationWork.swift
//  NotificationService
//
//  Created by 韩颖 on 2026/7/18.
//

import Foundation
import UserNotifications

// MARK: - Notification Work

/// UserNotifications 提供的 contentHandler 在部分 SDK 中没有标记为 @Sendable。
///
/// 这里使用一个范围很小的 @unchecked Sendable 对象，把以下内容一起交给 actor：
///
/// 1. mutable notification content
/// 2. contentHandler
///
/// 安全约束：
/// - 创建完成后只允许 NotificationServiceHandler actor 访问。
/// - contentHandler 只允许通过 actor 的 finish 方法调用。
/// - actor 保证 contentHandler 最多执行一次。

class NotificationWork: @unchecked Sendable {
    let content: UNMutableNotificationContent
    private let contentHandler:((UNNotificationContent) -> Void)

    init(
        content: UNMutableNotificationContent,
        contentHandler:
            @escaping (UNNotificationContent) -> Void
    ) {
        self.content = content
        self.contentHandler = contentHandler
    }

    /// 只能由 NotificationServiceHandler actor 调用。
    func complete() {
        contentHandler(content)
    }
}

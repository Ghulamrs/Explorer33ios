//
//  Queue.swift
//  Explorer
//
//  Created by Home on 2/8/19.
//  Copyright © 2019 Home. All rights reserved.
//

import Foundation

class QueueItem<T> {
    let value: T!
    var next: QueueItem?
    
    init(_ newvalue: T?) {
        self.value = newvalue
    }
}

public class Queue<T> {
    typealias Element = T
    var front: QueueItem<Element>
    var back:  QueueItem<Element>
    var count: Int

    public init () {
        back = QueueItem(nil)
        front = back
        count = 0
    }
    
    func enque (value: Element) {
        back.next = QueueItem(value)
        back = back.next!
        count += 1
    }
    
    func deque () -> Element? {
        if let newhead = front.next {
            count -= 1
            front = newhead
            return newhead.value
        } else {
            return nil
        }
    }
    
    public func isEmpty() -> Bool {
        return front === back
    }
}

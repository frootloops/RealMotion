//
//  ViewController.swift
//  RealMotion
//
//  Created by Arsen Gasparyan on 13/06/16.
//  Copyright © 2016 Arsen Gasparyan. All rights reserved.
//

import UIKit
import CoreMotion
import AudioToolbox

class ViewController: UIViewController {
    @IBOutlet weak var typeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var actionButton: UIButton!
    private let motionManager = CMMotionManager()
    private var previousAcceleration = CMAcceleration(x: 0, y: 0, z: 0)
    private var ds = [Double]()
    private var date = NSDate()
    private let types = ["shaking", "walking", "running"]
    private var outputStream: NSOutputStream!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func action(sender: UIButton) {
        if sender.selected {
            sender.selected = false
            motionManager.stopAccelerometerUpdates()
            outputStream?.close()
            return
        }
        
        
        AudioServicesPlaySystemSound(1005)
        sender.selected = true
        sleep(1)
        date = NSDate()
        motionManager.accelerometerUpdateInterval = 1.0 / 60
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH:mm:ss"
        
        let documents = try! NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory,
            inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
        
        let title = dateFormatter.stringFromDate(date) + "_" + types[typeSegmentedControl.selectedSegmentIndex]
        let path = documents.URLByAppendingPathComponent("\(title).csv").path!
        outputStream = NSOutputStream(toFileAtPath: path, append: true)!
        outputStream.open()
        
        self.outputStream.write("x,y\n")
        var index = 1
        motionManager.startAccelerometerUpdatesToQueue(.mainQueue()) { [weak self] data, error in
            guard let `self` = self, data = data else { return }
            let d = self.calculateD(data.acceleration, b: self.previousAcceleration)
            self.ds.append(d)
            
            if self.ds.count == 10 {
                let wma = self.calculateWMA(self.ds)
                if wma > 0.0 {
                    self.outputStream.write("\(index),\(wma)\n")
                    index += 1
                    print(wma)
                }
                self.ds.removeFirst()
                
                if index == 400 {
                    self.action(sender)
                    AudioServicesPlaySystemSound(1005)
                }
            }
            
            self.previousAcceleration = data.acceleration
        }

    }
}

private extension ViewController {
    // MARK: Helpers
    
    private func calculateD(a: CMAcceleration, b: CMAcceleration) -> Double {
        
        let sum = (a.x * b.x) + (a.y * b.y) + (a.z * b.z)
        let root = sqrt(pow(a.x, 2.0) + pow(a.y, 2.0) + pow(a.z, 2.0)) *
            sqrt(pow(b.x, 2.0) + pow(b.y, 2.0) + pow(b.z, 2.0))
        
        return sum / root
    }
    
    private func calculateWMA(ds: [Double]) -> Double {
        assert(ds.count == 10)
        let sum = ds.enumerate().map{ index, element in
            Double(index + 1) * element
        }.reduce(0.0, combine: +)
        
        return sum / 55.0
    }
}

private extension NSOutputStream {
    
    /// Write String to outputStream
    ///
    /// - parameter string:                The string to write.
    /// - parameter encoding:              The NSStringEncoding to use when writing the string. This will default to UTF8.
    /// - parameter allowLossyConversion:  Whether to permit lossy conversion when writing the string.
    ///
    /// - returns:                         Return total number of bytes written upon success. Return -1 upon failure.
    
    func write(string: String, encoding: NSStringEncoding = NSUTF8StringEncoding, allowLossyConversion: Bool = true) -> Int {
        if let data = string.dataUsingEncoding(encoding, allowLossyConversion: allowLossyConversion) {
            var bytes = UnsafePointer<UInt8>(data.bytes)
            var bytesRemaining = data.length
            var totalBytesWritten = 0
            
            while bytesRemaining > 0 {
                let bytesWritten = self.write(bytes, maxLength: bytesRemaining)
                if bytesWritten < 0 {
                    return -1
                }
                
                bytesRemaining -= bytesWritten
                bytes += bytesWritten
                totalBytesWritten += bytesWritten
            }
            
            return totalBytesWritten
        }
        
        return -1
    }
    
}


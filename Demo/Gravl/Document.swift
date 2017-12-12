//
//  Document.swift
//  Gravl
//
//  Created by Logan Murray on 2016-12-16.
//  Copyright © 2016 Logan Murray. All rights reserved.
//

import Cocoa

class Document: NSDocument, NSTextViewDelegate {

	@IBOutlet var inputView: NSTextView!
	@IBOutlet var outputView: NSTextView!
	@IBOutlet weak var languageSelector: NSSegmentedControl!
	
	var parser: Gravl.Parser = Gravl.Parser()
	var tempStorage: String? = nil
	
	override init() {
		super.init()
	}
	
	override func awakeFromNib() {
		languageSelector.selectedSegment = 0
		inputView.font = NSFont(name: "FiraCode-Retina", size: 14)
		outputView.font = NSFont(name: "FiraCode-Retina", size: 12)
		
		inputView.delegate = self
		
		if tempStorage != nil {
			inputView.string = tempStorage
			tempStorage = nil
			parseText()
		} else {
			inputView.selectAll(self)
		}
	}

	@IBAction func languageChanged(_ sender: NSSegmentedControl) {
		parseText()
	}
	
	override class func autosavesInPlace() -> Bool {
		return true
	}

	override var windowNibName: String? {
		return "Document"
	}

	override func data(ofType typeName: String) throws -> Data {
		return inputView.string?.data(using: String.Encoding.utf8) ?? Data()
	}

	override func read(from data: Data, ofType typeName: String) throws {
		tempStorage = String(data: data, encoding: String.Encoding.utf8)
		
		if inputView?.string != nil {
			inputView.string = tempStorage
			tempStorage = nil
			parseText()
		}
	}
	
	func textDidChange(_ notification: Notification) {
		parseText()
	}
	
	private func parseText() {
		guard let text = inputView?.string else {
			return
		}
		
		let t1 = Date()
		parser.parse(text)
		let t2 = Date()
		Swift.print("Parse time:      \((t2.timeIntervalSince(t1) * 1000 * 100).rounded() / 100) ms")
		
		if let root = parser.node {
			outputView.string = root.description
			outputView.textColor = NSColor.black
			
			let t3 = Date()
			Swift.print("Serialize time:  \((t3.timeIntervalSince(t2) * 1000 * 100).rounded() / 100) ms")

			// uncomment to enable reparse compare verification
//			let reparser = Gravl.Parser()
//			reparser.parse(root.description)
//			if reparser.node?.attributes[0].value.description == root.description {
//				Swift.print("Reparse compare successful!")
//			} else {
//				Swift.print("Reparse compare failed. :(\n\(reparser.node?.description ?? "Parse failed.")")
//			}
		} else {
			outputView.string = "\(parser.error!.errorDescription)"
			outputView.textColor = NSColor.red
		}
	}
}

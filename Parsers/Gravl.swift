//
//  Gravl.swift
//  Gravl
//
//  Created by Logan Murray on 2016-12-16.
//  Copyright © 2016 Logan Murray. All rights reserved.
//

import Foundation

public class Gravl {

	public class Node {
		let value: String // the name of a node is its value
		let attributes: [String: Node]
		let childNodes: [Node]
		
		private static let reservedCharacterSet = CharacterSet(charactersIn: Parser.reservedChars + Parser.whitespaceChars)
		
		fileprivate init(value: String, attributes: [String: Node], childNodes: [Node]) {
			self.value = value
			self.attributes = attributes
			self.childNodes = childNodes
		}
		
		public func serialize(options: SerializationOptions = SerializationOptions()) -> String {
			var result = ""
			var quote = Node.quoteForSymbol(value)
			let textNode = self is TextNode
			let escapedValue = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
			result += "\(textNode ? "" : "[")\(quote)\(escapedValue)\(quote)"
			var complexAttributes = [String]() // record the keys for attributes that have node values
			
			for attribute in attributes.keys.sorted() {
				if options.complexAttributesOnBottom && !(attributes[attribute] is TextNode) {
					complexAttributes.append(attribute)
					continue
				}
				let separator = options.inlineAttributes ? " " : "\n\(options.indentation)"
				quote = Node.quoteForSymbol(attribute)
				result += "\(separator)\(quote)\(attribute)\(quote)"
				let attrValue = attributes[attribute]!.serialize(options: options)
				result += "\(options.beforeEquals)=\(options.afterEquals)\(attrValue)"
			}
			
			for attribute in complexAttributes.sorted() {
				let separator = "\n\(options.indentation)"
				quote = Node.quoteForSymbol(attribute)
				result += "\(separator)\(quote)\(attribute)\(quote)\(options.beforeEquals)="
				let valueLines = attributes[attribute]!.serialize(options: options)
				for valueLine in valueLines.components(separatedBy: "\n") {
					result += "\n\(options.indentation)\(options.indentation)\(valueLine)"
				}
			}
			
			if !(attributes.isEmpty || options.inlineAttributes) || !complexAttributes.isEmpty && !childNodes.isEmpty {
				result += options.afterAttributes
			}
			
			for childNode in childNodes {
				let childLines = childNode.serialize(options: options).components(separatedBy: "\n")
				for childLine in childLines {
					result += "\n\(options.indentation)\(childLine)"
				}
			}
			
			let multiLine = !(attributes.isEmpty || options.inlineAttributes) || !childNodes.isEmpty
			result += "\(multiLine ? "\n" : "")\(textNode ? "" : "]")"
			
			return result
		}
		
		private static func quoteForSymbol(_ symbol: String) -> String {
			return symbol.rangeOfCharacter(from: reservedCharacterSet) != nil ? "\"" : ""
		}
	}
	
	// this is an empty subclass to represent implicit (symbolic) nodes;
	// because it inherits from Node you don't actually have to care unless you need to
	public class TextNode: Node {
		fileprivate init(value: String) {
			super.init(value: value, attributes: [String: Node](), childNodes: [Node]())
		}
	}
	
	public struct SerializationOptions {
		public var indentation: String = "  "
		public var inlineAttributes = true
		public var afterAttributes = "\n" // put a blank line between attributes and child nodes
		public var beforeEquals = ""
		public var afterEquals = ""
		public var complexAttributesOnBottom = true // sorts complex attributes to the bottom for readability
	}
	
	public class Parser {
		public static let reservedChars = "[]\"=#"
		public static let whitespaceChars = " \t\n\r"
		
		private let name: String
		private var buffer: String
		private var index: String.Index
		private var glyphIndex: String.Index? = nil // the index of the next glyph, or nil if unknown
		fileprivate var line = 1
		fileprivate var col = 0
		
		public var document: Node?
		public var error: ParserError?
		
		public init(name: String? = nil) {
			self.name = name ?? "Document"
			self.buffer = ""
			self.index = buffer.startIndex
		}

		public func parse(string: String) -> Node? {
			buffer = string
			index = buffer.startIndex
			glyphIndex = nil
			line = 1
			col = 0
			document = nil
			error = nil
			
			do {
				document = try recordNodeBody(name: name)
				
				if let char = peekGlyph() {
					throw ParserError(self, fault: .unexpectedChar(char: char, reason: "Extraneous character found in document. Ensure all brackets and quotes are balanced."))
				}
			} catch let error as ParserError {
				self.error = error
				print("\(error.errorDescription)")
				return nil
			} catch {
				// this can never happen, but swift complains without it *shrug*
			}
			
			return document
		}
		
		// MARK: Recording States
		
		private func recordNode() throws -> Node {
			var char = try readGlyph()
			assert(char == "[")
			
			let name = try recordSymbol()
			
			if name == "" {
				throw ParserError(self, fault: .unexpectedChar(char: try readChar(), reason: "Nodes must be named."));
			}
			
			let node = try recordNodeBody(name: name)
			
			char = try readGlyph()
			assert(char == "]")
//			if char != "]" { // is this actually possible?
//				throw ParserError(self, fault: .unexpectedChar(char: char, reason: "Attributes must be defined before child nodes."))
//			}
			
			return node
		}
		
		private func recordNodeBody(name: String) throws -> Node {
			var attributes = [String: Node]()
			var childNodes = [Node]()
			
			// look for any attributes
			while true {
				let symbol = try recordSymbol()
				
				if symbol == "" {
					break // no more attributes
				}
				
				if peekGlyph() == "=" { // this is an attribute
					_ = try readGlyph() // absorb the =
					
					if attributes[symbol] != nil {
						throw ParserError(self, fault: .duplicateAttribute(attribute: symbol, node: name))
					}
					
					if peekGlyph() == "[" {
						let value = try recordNode()
						attributes[symbol] = value
					} else {
						let value = try recordSymbol()
						
						if value == "" {
							throw ParserError(self, fault: .unexpectedChar(char: try readChar(), reason: "Attributes must have values."))
						}
						
						attributes[symbol] = TextNode(value: value)
					}
				} else {
					childNodes.append(TextNode(value: symbol)) // add the symbol as a TextNode and break
					break // as soon as we record a child node we are no longer in attribute record mode
				}
			}
			
			// add remaining nodes as children
			while peekGlyph() != nil && peekGlyph() != "]" { // we also need to consider eof now
				if peekGlyph() == "=" {
					if childNodes.count == 0 {
						throw ParserError(self, fault: .unexpectedChar(char: try readGlyph(), reason: "Nodes must be named."))
					} else {
						throw ParserError(self, fault: .unexpectedChar(char: try readGlyph(), reason: "Attributes must be defined before child nodes."))
					}
				}
				
				var node: Node
				
				if peekGlyph() == "[" {
					node = try recordNode()
				} else {
					let value = try recordSymbol()
					assert(value != "")
					
					node = TextNode(value: value)
				}
				
				childNodes.append(node)
			}
			
			return Node(value: name, attributes: attributes, childNodes: childNodes)
		}
		
		private func recordSymbol() throws -> String {
//			if peekGlyph() == nil {
//				throw ParserError(self, fault: .unexpectedEOF)
//			}
			if peekGlyph() == "\"" {
				return try recordString()
			}
			
			var symbol = ""
			
			while glyphIndex != nil && index != glyphIndex! {
				_ = try readChar()
			}
			
			while peekChar() != nil && !isReservedChar(peekChar()!) && !isWhitespace(peekChar()!) {
				symbol.append(try readChar())
			}
			
			return symbol
		}
		
		private func recordString() throws -> String {
			var char = try readGlyph()
			assert(char == "\"")
			
			var string = ""
			
			while peekChar() != nil && peekChar() != "\"" {
				if peekChar() == "\\" {
					string.append(try recordEscapedChar())
				} else {
					string.append(try readChar())
				}
			}
			
			char = try readChar()
			assert(char == "\"")
			
			return string
		}
		
		private func recordEscapedChar() throws -> Character {
			var char = try readChar() // absorb \
			assert(char == "\\")

			char = try readChar()
			if char != "\\" && char != "\"" {
				throw ParserError(self, fault: .unexpectedChar(char: char, reason: "A backslash must be followed by either \" or \\."))
			}
			
			return char
		}
		
		// MARK: Helper Methods
		
		private func peekChar() -> Character? {
			if index == buffer.endIndex {
//				throw ParserError(self, fault: .unexpectedEOF)
				return nil
			}
			
			return buffer[index]
		}
		
		private func readChar() throws -> Character {
			if glyphIndex == index { // if we've reached glyphIndex, reset it because it's no longer pointing ahead
				glyphIndex = nil
			}

			guard let char = peekChar() else {
				throw ParserError(self, fault: .unexpectedEOF)
			}
			
			if char == "\n" {
				line += 1
				col = 0
			} else {
				col += 1
			}
			
			index = buffer.index(after: index) // swift 3, everyone *sigh*
			
			return char
		}
		
		// a glyph is any non-whitespace character
		// comments are also handled (skipped over) at this level, making them effectively equivalent to whitespace
		private func peekGlyph() -> Character? {
			if let glyphIndex = glyphIndex { // if glyphIndex is set, it means we've already located the next glyph
				return buffer[glyphIndex]
			}
			
			//var char = peekChar()
			var insideComment = false
			glyphIndex = index
			
			while true {
				if glyphIndex == buffer.endIndex {
					glyphIndex = nil
					// no glyph found before the eof
					return nil
				}
				
				// handle # comments
				if !insideComment && buffer[glyphIndex!] == "#" {
					insideComment = true
				} else if insideComment && buffer[glyphIndex!] == "\n" {
					insideComment = false
				}
				
				if !insideComment && !isWhitespace(buffer[glyphIndex!]) {
					break
				}
				
				glyphIndex = buffer.index(after: glyphIndex!)
			}
			
			return buffer[glyphIndex!]
		}
		
		private func readGlyph() throws -> Character {
			guard let glyph = peekGlyph() else { // ensures glyphIndex is set or nil if eof
				throw ParserError(self, fault: .unexpectedEOF)
			}
			
			while glyphIndex != nil {
				_ = try readChar() // we need to do this so the line/col counters are accurate
			}
			
			return glyph
		}
		
		private func isWhitespace(_ char: Character) -> Bool {
//			return char == " " || char == "\t" || char == "\n" || char == "\r"
			return Parser.whitespaceChars.characters.contains(char)
		}
		
		// any of: [ ] = " #
		private func isReservedChar(_ char: Character) -> Bool {
			return Parser.reservedChars.characters.contains(char)
		}
	}
	
	public struct ParserError: Error {
		fileprivate enum Fault {
			case unexpectedChar(char: Character, reason: String)
			case duplicateAttribute(attribute: String, node: String)
			case unexpectedEOF
		}
		
		fileprivate let fault: Fault
		
		public let line: Int
		public let col: Int
		
		fileprivate init(_ parser: Parser, fault: Fault) {
			self.fault = fault
			self.line = parser.line
			self.col = parser.col
		}
		
		public var message: String {
			get {
				switch fault {
					case .unexpectedChar(let char, let reason):
						return "Unexpected character: \"\(char)\". \(reason)"
					
					case .duplicateAttribute(let attribute, let node):
						return "Duplicate attribute. The attribute \"\(attribute)\" has already been defined for the node [\(node)]."
					
					case .unexpectedEOF:
						return "Unexpected end of file. Ensure all brackets and quotes are balanced."
				}
			}
		}
		
		public var errorDescription: String {
			get {
				return "\(message) (Line: \(line), Col: \(col))"
			}
		}
	}
}

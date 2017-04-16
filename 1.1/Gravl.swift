//
//  Gravl.swift
//  Gravl 1.1
//
//  Created by Logan Murray on 2016-12-16.
//  Copyright © 2016 Logan Murray. All rights reserved.
//

import Foundation

public class Gravl {

	public class Node: CustomStringConvertible {
		let attributes: [(name: String?, value: Node)]
		var position: (line: Int, col: Int)
		
		private static let reservedCharacterSet = CharacterSet(charactersIn: Parser.reservedChars + Parser.whitespaceChars + "\\")
		
		public var value: String? {
			get {
				if let first = attributes.first {
					if first.name == nil {
						return first.value.value
					}
				}
				return nil
			}
		}
		
		public var description: String {
			get {
				return serialize()
			}
		}
		
		fileprivate init(attributes: [(String?, Node)]) {
			self.attributes = attributes
			self.position = (-1, -1)
		}
		
		// note: this function currently sacrifices some efficiency for readability of output
		// i plan to add a serialize option for fast serialization that outputs a minified string
		public func serialize(options: SerializationOptions = SerializationOptions()) -> String {
			var result = ""
			var maxLength = 0 // track longest attribute name
			
			if let textNode = self as? TextNode {
				assert(textNode.value != nil)
				return Node.serializeSymbol(textNode.value!)
			}
			
			var firstAttribute = true
			var lastExplicit: Bool? = nil
			
			// determine longest attribute name for padding
			for (attribute, _) in attributes {
				if var attribute = attribute {
					attribute = Node.serializeSymbol(attribute)
					maxLength = max(attribute.characters.count, maxLength)
				}
			}
			
			for (attribute, value) in attributes {
				let explicit = attribute != nil
				
				if lastExplicit != nil && explicit != lastExplicit {
					result += options.contentSeparator
				}
				
				let lines = value.serialize(options: options).components(separatedBy: "\n")
				
				if var attribute = attribute {
					attribute = Node.serializeSymbol(attribute) // could be optimized to avoid doing this twice
					result += "\n\(options.indentation)"
					if lines.count == 1 {
						result += attribute.padding(toLength: max(maxLength, attribute.characters.count), withPad: " ", startingAt: 0)
					} else {
						result += attribute
					}
					result += "\(options.beforeEquals)=\(options.afterEquals)"
				}
				
				if lines.count == 1 {
					if !firstAttribute && !explicit {
						result += "\n\(options.indentation)"
					}
					result += lines.first!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
				} else {
					for line in lines {
						if explicit {
							result += "\n\(options.indentation)\(options.indentation)\(line)"
						} else {
							result += "\n\(options.indentation)\(line)"
						}
					}
				}
				
				lastExplicit = firstAttribute && !explicit ? nil : explicit
				firstAttribute = false
			}
			
			let trimmed = result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
			let multiLine = trimmed.contains("\n")
			if multiLine {
				return "[\(result)\n]"
			} else {
				return "[\(trimmed)]"
			}
		}
		
		private static func serializeSymbol(_ symbol: String) -> String {
			let quote = symbol.rangeOfCharacter(from: reservedCharacterSet) != nil ? "\"" : ""
			let escaped = symbol.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
			return "\(quote)\(escaped)\(quote)"
		}
	}
	
	// aka primitive node, leaf node, value node
	// not really a true subclass as it can't have attributes or child nodes of its own
	public class TextNode: Node {
		private var _value: String?
		
		fileprivate init(value: String) {
			super.init(attributes: [])
			_value = value
		}
		
		public override var value: String? {
			get {
				return _value
			}
		}
	}
	
	public struct SerializationOptions {
		public var indentation      = "  "
		public var newline          = "\n"
		public var beforeEquals     = " "
		public var afterEquals      = " "
		public var contentSeparator = "\n" // separates default (unnamed) attributes from named attributes
	}
	
	public class Parser {
		public static let reservedChars = "[]\"=,"
		public static let whitespaceChars = " \t\n\r"
		
		private var buffer: String {
			didSet {
				parse()
			}
		}
		
		private var index: String.Index
		private var glyphIndex: String.Index? = nil // the index of the next glyph, or nil if unknown
		fileprivate var line = 1
		fileprivate var col = 0
		
		public var node: Node?
		public var error: ParserError?
		
		public init(_ gravl: String = "") {
			self.buffer = gravl
			self.index = buffer.startIndex // this is pointless but again swift complains without it
			
			parse()
		}

		private func parse() {
			index = buffer.startIndex
			glyphIndex = nil
			line = 1
			col = 0
			node = nil
			error = nil
			
			do {
				node = try readNodeBody()
				
				if let char = peekGlyph() {
					throw ParserError(position: (line: line, col: col), fault: .unexpectedChar(char: char, reason: "Extraneous character found in document. Ensure all brackets and quotes are balanced."))
				}
			} catch let error as ParserError {
				self.error = error
//				print("\(error.errorDescription)")
				node = nil
			} catch {
				// this can never happen, but swift complains without it *shrug*
			}
		}
		
		// MARK: Read Functions
		
		/// Reads consecutive nodes joined by a comma (`,`).
		private func readNodes() throws -> [Node] {
			var nodes = [Node]()
			
			while true {
				if let node = try readNode() {
					nodes.append(node)
				} else {
					break
				}
				
				if peekGlyph() == "," {
					_ = try readGlyph()
				} else {
					break
				}
			}
			
			return nodes
		}
		
		/// Reads a single node, whether a recursive node or text node.
		private func readNode() throws -> Node? {
			guard var glyph = peekGlyph() else { // ensures glyphIndex is set or nil if eof
				return nil
			}
			
			if glyph == "[" {
				_ = try readGlyph() // absorb [
				
				let position = glyphPosition()
				let node = try readNodeBody()
				node.position = position
				
				glyph = try readGlyph()
				
				if glyph != "]" {
					throw ParserError(position: (line: line, col: col), fault: .unexpectedChar(char: glyph, reason: "Character is not a valid node starting character."))
				}
				
				return node
			} else {
				let position = glyphPosition()
				let symbol = try readSymbol()
				
				if symbol.isEmpty {
					return nil
				}
				
				let node = TextNode(value: symbol)
				node.position = position
				
				return node
			}
		}
		
		private func readNodeBody() throws -> Node {
			var attributes = [(String?, Node)]()
			
			while true {
				var nodes = try readNodes()
				var names = [String?]()
				
				if nodes.isEmpty {
					break
				}
				
				let char = peekGlyph()
				
				if char == "=" {
					_ = try readGlyph() // absorb =
					
					for name in nodes {
						if !(name is TextNode) {
							throw ParserError(position: name.position, fault: .illegalAttribute)
						} else {
							assert(name.value != nil) // could a TextNode ever be nil?
							names.append(name.value)
						}
					}
					
					nodes = try readNodes()
					
					if nodes.isEmpty {
						throw ParserError(position: (line: line, col: col), fault: .illegalValue)
					}
				}
				
				if names.isEmpty {
					names.append(nil)
				}
				
				// cross-join attributes on values
				for name in names {
					for value in nodes {
						attributes.append((name, value))
					}
				}
			}
			
			return Node(attributes: attributes)
		}
		
		private func readSymbol() throws -> String {
			if peekGlyph() == "\"" {
				return try readString()
			}
			
			var symbol = ""
			
			// catch up to glyphIndex
			while glyphIndex != nil && index != glyphIndex! {
				_ = try readChar()
			}
			
			while true {
				if let char = peekChar() {
					if char == "\\" {
						symbol.append(try readEscapedChar())
						continue
					} else if !isReservedChar(peekChar()!) && !isWhitespace(peekChar()!) {
						symbol.append(try readChar())
						continue
					}
				}
				break
			}
			
			return symbol
		}
		
		private func readString() throws -> String {
			var char = try readGlyph()
			assert(char == "\"")
			
			var string = ""
			
			while peekChar() != nil && peekChar() != "\"" {
				if peekChar() == "\\" {
					string.append(try readEscapedChar())
				} else {
					string.append(try readChar())
				}
			}
			
			char = try readChar()
			assert(char == "\"")
			
			return string
		}
		
		private func readEscapedChar() throws -> Character {
			var char = try readChar() // absorb \
			assert(char == "\\")

			char = try readChar()
			switch char {
				case "\\":
					return "\\"
				
				case " ":
					return " ";
				
				case "n":
					return "\n"
				
				case "t":
					return "\t"
				
				default:
					break
			}
			
			// allow any reserved character to be escaped in a symbol
			if Parser.reservedChars.characters.contains(char) {
				return char
			}
			
			throw ParserError(position: (line: line, col: col), fault: .unexpectedChar(char: char, reason: "A backslash must be followed by a reserved character, \"n\", \"t\" or a space."))
		}
		
		// MARK: Helper Methods
		
		private func peekChar() -> Character? {
			if index == buffer.endIndex {
				return nil
			}
			
			return buffer[index]
		}
		
		private func readChar() throws -> Character {
			if glyphIndex == index { // if we've reached glyphIndex, reset it because it's no longer pointing ahead
				glyphIndex = nil
			}

			guard let char = peekChar() else {
				throw ParserError(position: (line: line, col: col), fault: .unexpectedEOF)
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
		
		// a glyph is defined as any non-whitespace character
		// comments are also handled at this level, making them effectively equivalent to whitespace
		private func peekGlyph() -> Character? {
			if glyphIndex == buffer.endIndex {
				return nil
			}
			if let glyphIndex = glyphIndex { // if glyphIndex is set, it means we've already located the next glyph
				return buffer[glyphIndex]
			}
			
			var insideComment = false
			glyphIndex = index
			
			while true {
				if glyphIndex == buffer.endIndex {
					// no glyph found before the eof
					return nil
				}
				
				// handle comments
				if !insideComment && buffer[glyphIndex!] == "/" {
					let nextIndex = buffer.index(after: glyphIndex!)
					if nextIndex != buffer.endIndex && buffer[nextIndex] == "/" {
						glyphIndex = nextIndex // absorb second /
						insideComment = true
					}
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
				throw ParserError(position: (line: line, col: col), fault: .unexpectedEOF)
			}
			
			while glyphIndex != nil {
				_ = try readChar() // we need to do this so the line/col counters are accurate
			}
			
			return glyph
		}
		
		private func glyphPosition() -> (line: Int, col: Int) {
			var index = self.index
			var line = self.line
			var col = self.col
			
			_ = peekGlyph() // make sure glyphIndex is set
			
			while index != glyphIndex {
				let char = buffer[index]
				
				if char == "\n" {
					line += 1
					col = 0
				} else {
					col += 1
				}
				
				index = buffer.index(after: index)
			}
			
			return (line: line, col: col)
		}
		
		// any of: [ ] = " ,
		private func isReservedChar(_ char: Character) -> Bool {
			return Parser.reservedChars.characters.contains(char)
		}
		
		private func isWhitespace(_ char: Character) -> Bool {
			return Parser.whitespaceChars.characters.contains(char)
		}
	}
	
	public struct ParserError: Error {
		fileprivate enum Fault {
			case unexpectedChar(char: Character, reason: String)
			case illegalAttribute
			case illegalValue
			case unexpectedEOF
		}
		
		fileprivate let fault: Fault
		
		public let line: Int
		public let col: Int
		
		fileprivate init(position: (line: Int, col: Int), fault: Fault) {
			self.line = position.line
			self.col = position.col
			self.fault = fault
		}
		
		public var message: String {
			get {
				switch fault {
					case .unexpectedChar(let char, let reason):
						return "Unexpected character: \"\(char)\". \(reason)"
					
					case .illegalAttribute:
						return "Illegal attribute. Attribute names must be strings."
					
					case .illegalValue:
						return "Missing attribute value."
					
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

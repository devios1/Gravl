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
		public struct Metadata {
			/// The position (line number and column) of the initial character that defines the current node in its original source.
			///
			/// Note that these numbers, per convention, start at 1, unlike the other indices in this structure which start at 0.
			var position: (line: Int, col: Int) = (-1, -1)
			/// Represents the index of the current node in its parent node.
			var localIndex: Int = -1
			/// Represents the index of the attribute that this value is assigned to. Two sibling nodes may share the same `attributeIndex` but have different `localIndex`es, for example if multiple values are joined with `,`.
			var attributeIndex: Int = -1
		}
		
		/// Represents the attributes (child nodes) of the current node.
		public var attributes: [(name: String?, value: Node)]
		/// Contains metadata about the current node such as its position in the source file.
		public var metadata = Metadata()
		
		/// Returns the `String` value of the current node.
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
		
		/// Returns just the node's unattributed nodes in an array.
		public var values: [Node] {
			get {
				return values();
			}
		}
		
		/// Returns the node's `values` flattened into an array of `String`s.
		public var flatValues: [String] {
			get {
				var values: [String] = []
				for value in self.values() {
					values += value.flatValues
				}
				return values
			}
		}
		
		public var description: String {
			get {
				return serialize()
			}
		}
		
		internal init(attributes: [(String?, Node)]) {
			self.attributes = attributes
		}
		
		public func values(for attribute: String? = nil) -> [Node] {
			var values: [Node] = []
			for (name, value) in attributes {
				if name == attribute {
					values.append(value)
				}
			}
			return values
		}
		
		public func serialize(options: SerializationOptions = SerializationOptions()) -> String {
			var result = ""
			var maxLength = 0 // tracks longest attribute name (if alignValues is enabled)
			
			if let valueNode = self as? ValueNode {
				assert(valueNode.value != nil)
				return Parser.serializeSymbol(valueNode.value!, options: options)
			}
			
			var firstAttribute = true
			var lastExplicit: Bool? = nil
			
			if options.alignValues {
				// determine longest attribute name for padding
				for (attribute, _) in attributes {
					if var attribute = attribute {
						attribute = Parser.serializeSymbol(attribute, options: options)
						maxLength = max(attribute.count, maxLength)
					}
				}
			}
			
			for (attribute, value) in attributes {
				let explicit = attribute != nil
				
				if options is MinifiedSerialization {
					var row: String
					var firstCharacter: Character
					let serializedValue = value.serialize(options: options)
					if explicit {
						let escapedAttribute = Parser.serializeSymbol(attribute!, options: options)
						firstCharacter = escapedAttribute.first!
						row = "\(options.attributeColor)\(escapedAttribute)\(options.equalsColor)=\(options.valueColor)\(serializedValue)"
					} else {
						firstCharacter = serializedValue.first!
						row = "\(options.defaultValueColor)\(serializedValue)"
					}
					if !firstAttribute && !Parser.reservedChars.contains(result.last!) && !Parser.reservedChars.contains(firstCharacter) {
						result += "\(options.whitespaceColor) "
					}
					result += row
					firstAttribute = false
					continue
				}
				
				if lastExplicit != nil && explicit != lastExplicit {
					result += options.contentSeparator
				}
				
				let lines = value.serialize(options: options).components(separatedBy: "\n")
				
				if var attribute = attribute {
					attribute = Parser.serializeSymbol(attribute, options: options)
					result += "\n\(options.indentation)"
					result += options.attributeColor
					
					if options.alignValues && lines.count == 1 {
						result += attribute.padding(toLength: max(maxLength, attribute.count), withPad: " ", startingAt: 0)
					} else {
						result += attribute
					}
					result += "\(options.whitespaceColor)\(options.beforeEquals)\(options.equalsColor)=\(options.whitespaceColor)\(options.afterEquals)"
				}
				
				if lines.count == 1 {
					if !firstAttribute && !explicit {
						result += "\(options.whitespaceColor)\n\(options.indentation)"
					} else if firstAttribute && !explicit {
						result += options.defaultValueColor
					} else {
						result += options.valueColor
					}
					result += lines.first!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
					result += options.whitespaceColor
				} else {
					for line in lines {
						if explicit {
							result += "\(options.whitespaceColor)\n\(options.indentation)\(options.indentation)\(line)"
						} else {
							result += "\(options.whitespaceColor)\n\(options.indentation)\(line)"
						}
					}
				}
				
				lastExplicit = firstAttribute && !explicit ? nil : explicit
				firstAttribute = false
			}
			
			if options is MinifiedSerialization {
				return "\(options.bracketColor)[\(result)\(options.bracketColor)]"
			}
			
			let trimmed = result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
			let multiLine = trimmed.contains("\n")
			if multiLine {
				return "\(options.bracketColor)[\(result)\n\(options.bracketColor)]"
			} else {
				return "\(options.bracketColor)[\(trimmed)\(options.bracketColor)]"
			}
		}
	}
	
	public class ValueNode: Node {
		private var _value: String?
		
		internal init(value: String) {
			super.init(attributes: [])
			_value = value
		}
		
		public override var value: String? {
			get {
				return _value
			}
		}
		
		public override var flatValues: [String] {
			get {
				if let value = _value {
					return [value]
				} else {
					return []
				}
			}
		}
	}
	
	public class SerializationOptions {
		var indentation      = "  "
		var beforeEquals     = " "
		var afterEquals      = " "
		var contentSeparator = "\n" // separates default (unnamed) attributes from named attributes
		var alignValues      = true // aligns all attributed values per node
		
		// support for colorization using color codes
		var whitespaceColor			= ""
		var bracketColor				= ""
		var attributeColor			= ""
		var equalsColor					= ""
		var stringColor					= ""
		var valueColor					= ""
		var defaultValueColor		= ""
		
		public init() {
		}
	}
	
	/// This serialization scheme results in the smallest serialized string without altering the meaning of the document.
	///
	/// It also provides the fastest serialization option by shortcutting some of the logic used in normal serialization.
	///
	/// **Note:** Instances of this scheme do support colorization, however doing so obviously does not result in the minimum string size.
	public class MinifiedSerialization: SerializationOptions {
		override public init() {
			super.init()
			indentation = ""
			beforeEquals = ""
			afterEquals = ""
			contentSeparator = ""
			alignValues = false
		}
	}
	
	public class Parser {
		public static var logErrors = false // turn on to print parse errors to the console
		
		public static let reservedChars = "[]\"=,"
		public static let whitespaceChars = " \t\n\r"
		
		private static let reservedCharacterSet = CharacterSet(charactersIn: Parser.reservedChars + Parser.whitespaceChars + "\\")
		
		private var buffer: String
		private var index: String.Index
		private var glyphIndex: String.Index? // the index of the next glyph, or nil if unknown
		private var position: (line: Int, col: Int) = (1, 0)
		private var localIndex = -1
		private var attributeIndex = -1
		
		public var node: Node?
		public var error: ParserError?
		
		public init() {
			self.buffer = ""
			self.index = buffer.startIndex
		}
		
		@discardableResult
		public func parse(_ gravl: String) -> Node? {
			self.buffer = gravl
			
			index = buffer.startIndex
			glyphIndex = nil
			position.line = 1
			position.col = 0
			node = nil
			error = nil
			
			do {
				node = try readNodeBody()
				
				if let char = peekGlyph() {
					_ = try readGlyph()
					throw ParserError(position: position, fault: .unexpectedChar(char: char, reason: "Extraneous character found in document. Ensure all brackets and quotes are balanced."))
				}
			} catch let error as ParserError {
				self.error = error
				if Parser.logErrors {
					print("\(error.errorDescription)")
				}
				node = nil
			} catch {
				// this can never happen, but Swift complains without it
			}
			
			return node
		}
		
		// MARK: Read Methods
		
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
				
				node.metadata.position = position
				
				glyph = try readGlyph()
				
				if glyph != "]" {
					throw ParserError(position: position, fault: .unexpectedChar(char: glyph, reason: "Character is not a valid node starting character."))
				}
				
				return node
				
			} else {
			
				let isString = peekGlyph() == "\"" // this allows for empty strings
				let position = glyphPosition() // either the first character or the "
				let symbol = try readSymbol()
				
				if symbol.isEmpty && !isString {
					return nil
				}
				
				let node = ValueNode(value: symbol)
				
				node.metadata.position = position
				
				return node
			}
		}
		
		private func readNodeBody() throws -> Node {
			localIndex = -1
			attributeIndex = -1
			
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
						names += name.flatValues as [String?]
					}
					
					nodes = try readNodes()
					
					if nodes.isEmpty {
						let glyph = try readGlyph()
						throw ParserError(position: position, fault: .unexpectedChar(char: glyph, reason: "Character is not a valid node starting character."))
					}
				}
				
				if names.isEmpty {
					names.append(nil)
				}
				
				// cross-join attributes on values
				for name in names {
					attributeIndex += 1
					
					for value in nodes {
						localIndex += 1
						
						value.metadata.localIndex = localIndex
						value.metadata.attributeIndex = attributeIndex
						
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
					} else if !Parser.isReservedChar(peekChar()!) && !Parser.isWhitespace(peekChar()!) {
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
			if Parser.reservedChars.contains(char) {
				return char
			}
			
			throw ParserError(position: position, fault: .unexpectedChar(char: char, reason: "A backslash must be followed by a reserved character, \"n\", \"t\" or a space."))
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
				throw ParserError(position: position, fault: .unexpectedEOF)
			}
			
			if char == "\n" {
				position.line += 1
				position.col = 0
			} else {
				position.col += 1
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
				
				if !insideComment && !Parser.isWhitespace(buffer[glyphIndex!]) {
					break
				}
				
				glyphIndex = buffer.index(after: glyphIndex!)
			}
			
			return buffer[glyphIndex!]
		}
		
		private func readGlyph() throws -> Character {
			guard let glyph = peekGlyph() else { // ensures glyphIndex is set or nil if eof
				throw ParserError(position: position, fault: .unexpectedEOF)
			}
			
			while glyphIndex != nil {
				_ = try readChar() // we need to do this so the line/col counters are accurate
			}
			
			return glyph
		}
		
		private func glyphPosition() -> (line: Int, col: Int) {
			var index = self.index
			var line = position.line
			var col = position.col
			
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
		
		// MARK: Static Methods
		
		private static func isReservedChar(_ char: Character) -> Bool {
			return Parser.reservedChars.contains(char)
		}
		
		private static func isWhitespace(_ char: Character) -> Bool {
			return Parser.whitespaceChars.contains(char)
		}
		
		public static func serializeSymbol(_ symbol: String, options: SerializationOptions) -> String {
			let needsQuote = symbol.rangeOfCharacter(from: reservedCharacterSet) != nil || symbol.isEmpty
			let quote = needsQuote ? "\"" : ""
			let escaped = symbol.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
			return "\(needsQuote ? options.stringColor : "")\(quote)\(escaped)\(quote)"
		}
	}
	
	public struct ParserError: Error {
		fileprivate enum Fault {
			case unexpectedChar(char: Character, reason: String)
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

#
#  Gravl.py
#  Gravl
#
#  Created by Logan Murray on 2017-01-04.
#  Copyright (c) 2017 Logan Murray. All rights reserved.
#

from sys import stderr

class Node:
	"A gravl node"

	def __init__(self, value, attributes, childNodes):
		self.value = value
		self.attributes = attributes
		self.childNodes = childNodes

class TextNode(Node):
	"A gravl text node"

	def __init__(self, value):
		self.value = value
		self.attributes = {}
		self.childNodes = []

class Parser:
	"A gravl parser"

	__reservedChars = "[]\"=#"
	__whitespaceChars = " \t\n\r"

	document = None
	error = None

	def __init__(self, name = "Document"):
		self.__name = name

	def parse(self, string, encoding = "utf-8"):
		self.__buffer = string.decode(encoding)
		self.__index = 0
		self.__glyphIndex = None # the index of the next glyph, or null if unknown
		self.__line = 1
		self.__col = 0

		try:
			self.document = self.__recordNodeBody(self.__name)

			char = self.__peekGlyph()
			if char is not None:
				raise ParserError, ParserError(self, "Extraneous character: " + char)

		except ParserError, e:
			self.error = e
			stderr.write("Gravl parse error: " + e.message + " (line %d, col %d)\n" % (e.line, e.col))
			self.document = None

		return self.document

	def __recordNode(self):
		char = self.__readGlyph()
		assert char == "["

		name = self.__recordSymbol()

		if name == "":
			raise ParserError, ParserError(self, "Nodes must be named.")

		node = self.__recordNodeBody(name)

		char = self.__readGlyph()
		assert char == "]"

		return node

	def __recordNodeBody(self, name):
		attributes = {}
		childNodes = []

		# look for attributes
		while True:
			symbol = self.__recordSymbol()

			if symbol == "":
				break

			if self.__peekGlyph() == "=":
				self.__readGlyph() # absorb the =

				if attributes.has_key(symbol):
					raise ParserError, ParserError(self, "Duplicate attribute: \"" + symbol + "\"")

				if self.__peekGlyph() == "[":
					value = self.__recordNode()
					attributes[symbol] = value
				else:
					value = self.__recordSymbol()

					if value == "":
						raise ParserError, ParserError(self, "Attributes must have values.")

					attributes[symbol] = TextNode(value)
			else:
				childNodes.append(TextNode(symbol))
				break # no more attributes

		while self.__peekGlyph() is not None and self.__peekGlyph() != "]":
			if self.__peekGlyph() == "=":
				if len(childNodes) == 0:
					raise ParserError, ParserError(self, "Nodes must be named.")
				else:
					raise ParserError, ParserError(self, "Attributes must be defined before child nodes.")

			if self.__peekGlyph() == "[":
				node = self.__recordNode()
			else:
				value = self.__recordSymbol()
				assert value != ""
				node = TextNode(value)

			childNodes.append(node)

		return Node(name, attributes, childNodes)

	def __recordSymbol(self):
		if self.__peekGlyph() == "\"":
			return self.__recordString()

		symbol = ""

		while self.__glyphIndex is not None and self.__index != self.__glyphIndex:
			self.__readChar()

		while self.__peekChar() is not None and not self.__isReservedChar(self.__peekChar()) and not self.__isWhitespace(self.__peekChar()):
			symbol += self.__readChar()

		return symbol

	def __recordString(self):
		char = self.__readGlyph()
		assert char == "\""

		string = ""

		while self.__peekChar() is not None and self.__peekChar() != "\"":
			if self.__peekChar() == "\\":
				string += self.__recordEscapedChar()
			else:
				string += self.__readChar()

		char = self.__readChar()
		assert char == "\""

		return string

	def __recordEscapedChar(self):
		char = self.__readChar() # absorb the \
		assert char == "\\"

		char = self.__readChar()
		if char != "\\" and char != "\"":
			raise ParserError, ParserError(self, "A backslash must be followed by either \" or \\.")

		return char

	# Helper Methods

	def __peekChar(self):
		if self.__index == len(self.__buffer):
			return None

		return self.__buffer[self.__index]

	def __readChar(self):
		if self.__glyphIndex == self.__index:
			self.__glyphIndex = None

		char = self.__peekChar()
		if char is None:
			raise ParserError, ParserError(self, "Unexpected EOF.")

		if char == "\n":
			self.__line += 1
			self.__col = 0
		else:
			self.__col += 1

		self.__index += 1

		return char

	def __peekGlyph(self):
		if self.__glyphIndex == len(self.__buffer):
			return None
		if self.__glyphIndex is not None:
			return self.__buffer[self.__glyphIndex]

		insideComment = False
		self.__glyphIndex = self.__index

		while True:
			if self.__glyphIndex == len(self.__buffer):
				#self.__glyphIndex = None
				return None

			char = self.__buffer[self.__glyphIndex]

			# handle # comments
			if not insideComment and char == "#":
				insideComment = True
			elif insideComment and char == "\n":
				insideComment = False

			if not insideComment and not self.__isWhitespace(char):
				break

			self.__glyphIndex += 1

		return self.__buffer[self.__glyphIndex]

	def __readGlyph(self):
		glyph = self.__peekGlyph()
		if glyph is None:
			raise ParserError, ParserError(self, "Unexpected EOF.")

		while self.__glyphIndex is not None:
			self.__readChar() # advances the index and increments line/col counts

		return glyph

	def __isReservedChar(self, char):
		return self.__reservedChars.find(char) != -1

	def __isWhitespace(self, char):
		return self.__whitespaceChars.find(char) != -1

class ParserError:
	def __init__(self, parser, message):
		self.message = message
		self.line = parser._Parser__line
		self.col = parser._Parser__col

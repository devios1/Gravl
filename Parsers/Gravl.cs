//
//  Gravl.cs
//  Gravl
//
//  Created by Logan Murray on 2017-01-09.
//  Copyright © 2017 Logan Murray. All rights reserved.
//

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;

namespace Gravl {
	public class Node {
		public string value { get; internal set; }
		public Dictionary<string, Node> attributes { get; internal set; }
		public Node[] childNodes { get; internal set; }

		internal Node(string value, Dictionary<string, Node> attributes, Node[] childNodes) {
			this.value = value;
			this.attributes = attributes;
			this.childNodes = childNodes;
		}
	}

	public class TextNode : Node {
		internal TextNode(string value)
			: base(value, new Dictionary<string, Node>(), new Node[0]) {
		}
	}

	public class Parser {
		static string reservedChars = "[]\"=#";
		static string whitespaceChars = " \t\n\r";

		string name;
		string buffer;
		int index;
		int? glyphIndex = null;
		internal int line = 1;
		internal int col = 0;

		public Node document { get; internal set; }
		public ParserError error { get; internal set; }

		public Parser(string name = "Document") {
			this.name = name;
		}

		public Node parse(string text) {
			this.buffer = text;
			index = 0;
			glyphIndex = null;
			line = 1;
			col = 0;
			document = null;
			error = null;

			try {
				document = readNodeBody(name);

				var char_ = peekGlyph();
				if (char_ != null)
					throw new ParserError(this, "Extraneous character: " + char_);
			} catch (ParserError e) {
				error = e;
				Debug.WriteLine(String.Format("Gravl parse error: " + e.message + " (line {0}, col {1})", e.line, e.col));
				document = null;
			}

			return document;
		}

		private Node readNode() {
			var char_ = readGlyph();
			Debug.Assert(char_ == '[');

			var name = readSymbol();
			if (name == "")
				throw new ParserError(this, "Nodes must be named.");

			var node = readNodeBody(name);

			char_ = readGlyph();
			Debug.Assert(char_ == ']');

			return node;
		}

		private Node readNodeBody(string name) {
			var attributes = new Dictionary<string, Node>();
			var childNodes = new List<Node>(); // convert to array later

			// look for attributes
			while (true) {
				var symbol = readSymbol();

				if (symbol == "")
					break;

				if (peekGlyph() == '=') {
					readGlyph(); // absorb the =

					if (attributes.ContainsKey(symbol))
						throw new ParserError(this, String.Format("Duplicate attribute: \"{0}\"", symbol));

					if (peekGlyph() == '[') {
						var value = readNode();
						attributes[symbol] = value;
					} else {
						var value = readSymbol();

						if (value == "")
							throw new ParserError(this, "Attributes must have values.");

						attributes[symbol] = new TextNode(value);
					}
				} else {
					childNodes.Add(new TextNode(symbol));
					break;
				}
			}

			while (peekGlyph() != null && peekGlyph() != ']') {
				if (peekGlyph() == '=') {
					if (childNodes.Count == 0)
						throw new ParserError(this, "Nodes must be named.");
					else
						throw new ParserError(this, "Attributes must be defined before child nodes.");
				}

				if (peekGlyph() == '[') {
					childNodes.Add(readNode());
				} else {
					var value = readSymbol();
					Debug.Assert(value != "");
					childNodes.Add(new TextNode(value));
				}
			}

			return new Node(name, attributes, childNodes.ToArray());
		}

		private string readSymbol() {
			if (peekGlyph() == '\"')
				return readString();

			var symbol = "";

			while (glyphIndex != null && index != glyphIndex)
				readChar();

			while (peekChar() != null && !isReservedChar((char)peekChar()) && !isWhitespace((char)peekChar()))
				symbol += readChar();

			return symbol;
		}

		private string readString() {
			var char_ = readGlyph();
			Debug.Assert(char_ == '\"');

			var string_ = "";

			while (peekChar() != null && peekChar() != '\"') {
				if (peekChar() == '\\')
					string_ += readEscapedChar();
				else
					string_ += readChar();
			}

			char_ = readChar();
			Debug.Assert(char_ == '\"');

			return string_;
		}

		private char readEscapedChar() {
			var char_ = readChar(); // absorb the \
			Debug.Assert(char_ == '\\');

			char_ = readChar();
			if (char_ != '\\' && char_ != '\"')
				throw new ParserError(this, "A backslash must be followed by either \" or \\.");

			return char_;
		}

		// Helper Methods

		private char? peekChar() {
			if (index == buffer.Length)
				return null;

			return buffer[index];
		}

		private char readChar() {
			if (glyphIndex == index)
				glyphIndex = null;

			var char_ = peekChar();
			if (char_ == null)
				throw new ParserError(this, "Unexpected EOF.");

			if (char_ == '\n') {
				line += 1;
				col = 0;
			} else {
				col += 1;
			}

			index += 1;

			return (char)char_;
		}

		private char? peekGlyph() {
			if (glyphIndex == buffer.Length)
				return null;
			if (glyphIndex != null)
				return buffer[(int)glyphIndex];

			var insideComment = false;
			glyphIndex = index;

			while (true) {
				if (glyphIndex == buffer.Length)
					return null;

				var char_ = buffer[(int)glyphIndex];

				// handle # comments
				if (!insideComment && char_ == '#')
					insideComment = true;
				else if (insideComment && char_ == '\n')
					insideComment = false;

				if (!insideComment && !isWhitespace(char_))
					break;

				glyphIndex += 1;
			}

			return buffer[(int)glyphIndex];
		}

		private char readGlyph() {
			var glyph = peekGlyph();
			if (glyph == null)
				throw new ParserError(this, "Unexpected EOF.");

			while (glyphIndex != null)
				readChar();

			return (char)glyph;
		}

		private static bool isReservedChar(char char_) {
			return reservedChars.Contains(char_);
		}

		private static bool isWhitespace(char char_) {
			return whitespaceChars.Contains(char_);
		}
	}

	public class ParserError : Exception {
		public string message { get; set; }
		public int line { get; set; }
		public int col { get; set; }

		internal ParserError(Parser parser, string message) {
			this.message = message;
			this.line = parser.line;
			this.col = parser.col;
		}
	}
}

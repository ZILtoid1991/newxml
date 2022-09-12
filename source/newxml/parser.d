/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements a low level XML parser.
+
+   The methods a parser should implement are documented in
+   $(LINK2 ../interfaces/isParser, `newxml.interfaces.isParser`);
+
+   Authors:
+   Lodovico Giaretta
+   László Szerémi
+
+   License:
+   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
+
+   Copyright:
+   Copyright Lodovico Giaretta 2016 --
+/

module newxml.parser;

import newxml.interfaces;
import newxml.faststrings;
import newxml.validation;

import std.algorithm.comparison : equal;
import std.exception : enforce;
import std.typecons : Flag, Yes, No;

public class ParserException : XMLException {
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
@safe:
/++
+   A low level XML parser.
+
+   The methods a parser should implement are documented in
+   $(LINK2 ../interfaces/isLexer, `newxml.interfaces.isLexer`);
+
+   Params:
+       L = the underlying lexer type
+       preserveWhitespace = if set to `Yes` (default is `No`), the parser will not remove element content whitespace 
+   (i.e. the whitespace that separates tags), but will report it as text.
+/
struct Parser(L, Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace)
    if (isLexer!L)
{
    import std.meta : staticIndexOf;

    alias CharacterType = L.CharacterType;
    alias StringType = CharacterType[];
    /++
    +   The structure returned in output from the low level parser.
    +   Represents an XML token, delimited by specific patterns, based on its kind.
    +   This delimiters are not present in the content field.
    +/
    struct XMLToken
    {
        /++ The content of the token, delimiters excluded +/
        CharacterType[] content;

        /++ Represents the kind of token +/
        XMLKind kind;
    }
    ///The lexer associated with the parser.
    package L lexer;
    private bool ready;
    private bool insideDTD;
    ///if set to `true` (default is `false`), the parser will try to parse any and all badly formed document as long as
    ///it can be processed.
    public bool processBadDocument;
    ///if set to `true` (which is default), then the parser will test for invalid characters, and will throw an 
    ///exception on errors. Turning it off can speed up parsing.
    public bool testTextValidity = true;
    public XMLVersion xmlVersion;
    private XMLToken next;
    ///Contains character and text entities. Text entities might contain additional nodes and elements.
    ///By default, it is filled with XML entities.
    public StringType[StringType] chrEntities;

    //mixin UsesErrorHandler!ErrorHandler;

    this(L lexer) {
        this.lexer = lexer;
        chrEntities = xmlPredefinedEntities!CharacterType();
    }
    /++ Generic constructor; forwards its arguments to the lexer constructor +/
    this(Args...)(Args args)
    {
        lexer = L(args);
        chrEntities = xmlPredefinedEntities!CharacterType();
    }
    static if (needSource!L)
    {
        alias InputType = L.InputType;

        /++
        +   See detailed documentation in
        +   $(LINK2 ../interfaces/isParser, `newxml.interfaces.isParser`)
        +/
        void setSource(InputType input)
        {
            lexer.setSource(input);
            chrEntities = xmlPredefinedEntities!CharacterType();
            ready = false;
            insideDTD = false;
        }
    }

    static if (isSaveableLexer!L)
    {
        auto save()
        {
            Parser result = this;
            result.lexer = lexer.save;
            return result;
        }
    }

    private CharacterType[] fetchContent(size_t start = 0, size_t stop = 0)
    {
        return lexer.get[start..($ - stop)];
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isParser, `newxml.interfaces.isParser`)
    +/
    bool empty()
    {
        static if (preserveWhitespace == No.preserveWhitespace)
            lexer.dropWhile(" \r\n\t");

        return !ready && lexer.empty;
    }

    /// ditto
    auto front()
    {
        if (!ready)
            fetchNext();
        return next;
    }

    /// ditto
    void popFront()
    {
        front();
        ready = false;
    }

    private void fetchNext()
    {
        if (!preserveWhitespace || insideDTD)
            lexer.dropWhile(" \r\n\t");

        assert(!lexer.empty);

        lexer.start();

        // dtd end
        if (insideDTD && lexer.testAndAdvance(']'))
        {
            lexer.dropWhile(" \r\n\t");
            enforce!ParserException(lexer.testAndAdvance('>')
                , "No \">\" character have been found after an \"<\"!");
            next.kind = XMLKind.dtdEnd;
            next.content = null;
            insideDTD = false;
        }

        // text element
        else if (!lexer.testAndAdvance('<'))
        {
            lexer.advanceUntil('<', false);
            next.kind = XMLKind.text;
            if (!processBadDocument)
                next.content = xmlUnescape(fetchContent(), chrEntities);
            else
                next.content = xmlUnescape!(No.strict)(fetchContent(), chrEntities);
            if (testTextValidity)
            {
                if (xmlVersion == XMLVersion.XML1_0)
                {
                    enforce!ParserException(isValidXMLText10(next.content)
                        , "Text contains invalid characters!");
                }
                else
                {
                    enforce!ParserException(isValidXMLText11(next.content)
                        , "Text contains invalid characters!");
                }
            }
        }

        // tag end
        else if (lexer.testAndAdvance('/'))
        {
            lexer.advanceUntil('>', true);
            next.content = fetchContent(2, 1);
            next.kind = XMLKind.elementEnd;
        }
        // processing instruction
        else if (lexer.testAndAdvance('?'))
        {
            do
                lexer.advanceUntil('?', true);
            while (!lexer.testAndAdvance('>'));
            next.content = fetchContent(2, 2);
            next.kind = XMLKind.processingInstruction;
        }
        // tag start
        else if (!lexer.testAndAdvance('!'))
        {
            size_t c;
            while ((c = lexer.advanceUntilAny("\"'/>", true)) < 2)
                if (c == 0)
                    lexer.advanceUntil('"', true);
                else
                    lexer.advanceUntil('\'', true);

            if (c == 2)
            {
                lexer.advanceUntil('>', true); // should be the first character after '/'
                next.content = fetchContent(1, 2);
                next.kind = XMLKind.elementEmpty;
            }
            else
            {
                next.content = fetchContent(1, 1);
                next.kind = XMLKind.elementStart;
            }
        }

        // cdata or conditional
        else if (lexer.testAndAdvance('['))
        {
            lexer.advanceUntil('[', true);
            // cdata
            if (lexer.get.length == 9 && equal(lexer.get()[3..$], "CDATA["))
            {
                do
                    lexer.advanceUntil('>', true);
                while (!equal(lexer.get()[($-3)..$], "]]>"));
                next.content = fetchContent(9, 3);
                next.kind = XMLKind.cdata;
            }
            // conditional
            else
            {
                int count = 1;
                do
                {
                    lexer.advanceUntilAny("[>", true);
                    if (lexer.get()[($-3)..$] == "]]>")
                        count--;
                    else if (lexer.get()[($-3)..$] == "<![")
                        count++;
                }
                while (count > 0);
                next.content = fetchContent(3, 3);
                next.kind = XMLKind.conditional;
            }
        }
        // comment
        else if (lexer.testAndAdvance('-'))
        {
            lexer.testAndAdvance('-'); // second '-'
            do
                lexer.advanceUntil('>', true);
            while (!equal(lexer.get()[($-3)..$], "-->"));
            next.content = fetchContent(4, 3);
            next.kind = XMLKind.comment;
        }
        // declaration or doctype
        else
        {
            size_t c;
            while ((c = lexer.advanceUntilAny("\"'[>", true)) < 2)
                if (c == 0)
                    lexer.advanceUntil('"', true);
                else
                    lexer.advanceUntil('\'', true);

            // doctype
            if (lexer.get.length>= 9 && equal(lexer.get()[2..9], "DOCTYPE"))
            {
                next.content = fetchContent(9, 1);
                if (c == 2)
                {
                    next.kind = XMLKind.dtdStart;
                    insideDTD = true;
                }
                else next.kind = XMLKind.dtdEmpty;
            }
            // declaration
            else
            {
                if (c == 2)
                {
                    size_t cc;
                    while ((cc = lexer.advanceUntilAny("\"'>", true)) < 2)
                        if (cc == 0)
                            lexer.advanceUntil('"', true);
                        else
                            lexer.advanceUntil('\'', true);
                }
                auto len = lexer.get().length;
                if (len > 8 && equal(lexer.get()[2..9], "ATTLIST"))
                {
                    next.content = fetchContent(9, 1);
                    next.kind = XMLKind.attlistDecl;
                }
                else if (len > 8 && equal(lexer.get()[2..9], "ELEMENT"))
                {
                    next.content = fetchContent(9, 1);
                    next.kind = XMLKind.elementDecl;
                }
                else if (len > 9 && equal(lexer.get()[2..10], "NOTATION"))
                {
                    next.content = fetchContent(10, 1);
                    next.kind = XMLKind.notationDecl;
                }
                else if (len > 7 && equal(lexer.get()[2..8], "ENTITY"))
                {
                    next.content = fetchContent(8, 1);
                    next.kind = XMLKind.entityDecl;
                }
                else
                {
                    next.content = fetchContent(2, 1);
                    next.kind = XMLKind.declaration;
                }
            }
        }

        ready = true;
    }
}

/++
+   Returns an instance of `Parser` from the given lexer.
+
+   Params:
+       preserveWhitespace = whether the returned `Parser` shall skip element content
+                            whitespace or return it as text nodes
+       lexer = the _lexer to build this `Parser` from
+
+   Returns:
+   A `Parser` instance initialized with the given lexer
+/
auto parser(Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace, T)(T lexer)
    if (isLexer!T)
{
    auto parser = Parser!(T, preserveWhitespace)();
    //parser.errorHandler = handler;
    parser.lexer = lexer;
    return parser;
}
/* ///Ditto
auto parser(Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace, T)(auto ref T input)
{
    auto lx = input.lexer;
    auto parser = Parser!(typeof(lx), preserveWhitespace)(lx);
    //parser.errorHandler = handler;
    return parser;
} */

import newxml.lexers;
import std.experimental.allocator.gc_allocator;//import stdx.allocator.gc_allocator;

/++
+   Instantiates a parser suitable for the given `InputType`.
+
+   This is completely equivalent to
+   ---
+   auto parser =
+        chooseLexer!(InputType, reuseBuffer)(alloc, handler)
+       .parser!(preserveWhitespace)(handler)
+   ---
+/
auto chooseParser(InputType, Flag!"preserveWhitespace" preserveWhitespace = No.preserveWhitespace)()
{
    return chooseLexer!(InputType)()
          .parser!(preserveWhitespace)();
}

unittest
{
    import newxml.lexers;
    import std.algorithm : find;
    import std.string : stripRight;

    string xml = q"{
    <!DOCTYPE mydoc https://myUri.org/bla [
        <!ELEMENT myelem ANY>
        <!ENTITY   myent    "replacement text">
        <!ATTLIST myelem foo cdata #REQUIRED >
        <!NOTATION PUBLIC 'h'>
        <!FOODECL asdffdsa >
    ]>
    }";

    auto parser = xml.lexer.parser;

    alias XMLKind = typeof(parser.front.kind);

    assert(parser.front.kind == XMLKind.dtdStart);
    assert(parser.front.content == " mydoc https://myUri.org/bla ");
    parser.popFront;

    assert(parser.front.kind == XMLKind.elementDecl);
    assert(parser.front.content == " myelem ANY");
    parser.popFront;

    assert(parser.front.kind == XMLKind.entityDecl);
    assert(parser.front.content == "   myent    \"replacement text\"");
    parser.popFront;

    assert(parser.front.kind == XMLKind.attlistDecl);
    assert(parser.front.content == " myelem foo cdata #REQUIRED ");
    parser.popFront;

    assert(parser.front.kind == XMLKind.notationDecl);
    assert(parser.front.content == " PUBLIC 'h'");
    parser.popFront;

    assert(parser.front.kind == XMLKind.declaration);
    assert(parser.front.content == "FOODECL asdffdsa ");
    parser.popFront;

    assert(parser.front.kind == XMLKind.dtdEnd);
    assert(!parser.front.content);
    parser.popFront;

    assert(parser.empty);
}

/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
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

module newxml.cursor;

import newxml.interfaces;
import newxml.faststrings;

import newxml.validation;

import std.meta : staticIndexOf;
import std.range.primitives;
import std.typecons;


public class CursorException : XMLException {
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
package struct Attribute(StringType)
{
    StringType value;
    private StringType _name;
    private size_t colon;

    this(StringType qualifiedName, StringType value)
    {
        this.value = value;
        name = qualifiedName;
    }

    @property auto name() inout
    {
        return _name;
    }
    @property void name(StringType _name)
    {
        this._name = _name;
        auto i = _name.fastIndexOf(':');
        if (i > 0)
            colon = i;
        else
            colon = 0;
    }
    @property auto prefix() inout
    {
        return name[0..colon];
    }
    @property StringType localName()
    {
        if (colon)
            return name[colon+1..$];
        else
            return name;
    }
    StringType toString() {
        return name ~ " = \"" ~ value ~ "\"";
    }
}

/++
+   An implementation of the $(LINK2 ../interfaces/isCursor, `isCursor`) trait.
+
+   This is the only provided cursor that builds on top of a parser (and not on top of another cursor), so it is part 
+   of virtually every parsing chain. All documented methods are implementations of the specifications dictated by
+   $(LINK2 ../interfaces/isCursor, `isCursor`).
+   Parameters:
+       P = The parser.
+       conflateCData = 
+       processBadDocument = If set to `Yes` (default is `No`), then it'll ignore errors as long as it can still 
+   process the document. Otherwise it'll throw an appropriate exception if an error is encountered.
+/
struct Cursor(P, Flag!"conflateCDATA" conflateCDATA = Yes.conflateCDATA,
    Flag!"processBadDocument" processBadDocument = No.processBadDocument)
    if (isLowLevelParser!P)
{
    struct AttributesRange
    {
        private StringType content;
        private Attribute!StringType attr;
        private Cursor* cursor;
        private bool error;

        private this(StringType str, ref Cursor cur) @system nothrow
        {
            content = str;
            cursor = &cur;
        }

        bool empty() @safe
        {
            if (error)
                return true;

            auto i = content.fastIndexOfNeither(" \r\n\t");
            if (i >= 0)
            {
                content = content[i..$];
                return false;
            }
            return true;
        }

        auto front() @safe
        {
            if (attr == attr.init)
            {
                auto i = content.fastIndexOfNeither(" \r\n\t");
                assert(i >= 0, "No more attributes...");
                content = content[i..$];

                auto sep = fastIndexOf(content[0..$], '=');
                if (sep == -1)
                {
                    // attribute without value???
                    static if (processBadDocument == No.processBadDocument) 
                    {
                        throw new CursorException("Invalid attribute syntax!");
                    }
                    else 
                    {
                        error = true;
                        return attr.init;
                    }
                }

                auto name = content[0..sep];
                
                
                auto delta = fastIndexOfAny(name, " \r\n\t");
                if (delta >= 0)
                {
                    auto j = name[delta..$].fastIndexOfNeither(" \r\n\t");
                    if (j != -1)
                    {
                        // attribute name contains spaces???
                        static if (processBadDocument == No.processBadDocument) 
                        {
                            throw new CursorException("Invalid attribute syntax!");
                        } 
                        else 
                        {
                            error = true;
                            return attr.init;
                        }
                    }
                    name = name[0..delta];
                }
                if (!isValidXMLName(name)) 
                {
                    static if (processBadDocument == No.processBadDocument)
                    {
                        throw new CursorException("Invalid attribute name!");
                    }
                    else 
                    {
                        error = true;
                    }
                }
                attr.name = name;

                size_t attEnd;
                size_t quote;
                delta = (sep + 1 < content.length) ? fastIndexOfNeither(content[sep + 1..$], " \r\n\t") : -1;
                if (delta >= 0)
                {
                    quote = sep + 1 + delta;
                    if (content[quote] == '"' || content[quote] == '\'')
                    {
                        delta = fastIndexOf(content[(quote + 1)..$], content[quote]);
                        if (delta == -1)
                        {
                            // attribute quotes never closed???
                            static if (processBadDocument == No.processBadDocument) 
                            {
                                throw new CursorException("Invalid attribute syntax!");
                            } 
                            else 
                            {
                                error = true;
                                return attr.init;
                            }
                        }
                        attEnd = quote + 1 + delta;
                    }
                    else
                    {
                        static if (processBadDocument == No.processBadDocument) 
                        {
                            throw new CursorException("Invalid attribute syntax!");
                        } 
                        else 
                        {
                            error = true;
                            return attr.init;
                        }
                    }
                }
                else
                {
                    // attribute without value???
                    static if (processBadDocument == No.processBadDocument) 
                    {
                        throw new CursorException("Invalid attribute syntax!");
                    } 
                    else 
                    {
                        error = true;
                        return attr.init;
                    }
                }
                //attr.value = content[(quote + 1)..attEnd];
                static if (processBadDocument == No.processBadDocument) 
                    attr.value = xmlUnescape(content[(quote + 1)..attEnd], cursor.parser.chrEntities);
                else
                    attr.value = xmlUnescape!No.strict(content[(quote + 1)..attEnd], cursor.parser.chrEntities);
                content = content[attEnd+1..$];
            }
            return attr;
        }

        auto popFront() @safe
        {
            front();
            attr = attr.init;
        }
    }
    /++ The type of characters in the input, as returned by the underlying low level parser. +/
    alias CharacterType = P.CharacterType;

    /++ The type of sequences of CharacterType, as returned by this parser +/
    alias StringType = CharacterType[];

    private P parser;
    private ElementType!P currentNode;
    private bool starting, _documentEnd = true, nextFailed, _xmlDeclNotFound;
    private ptrdiff_t colon;
    private size_t nameBegin, nameEnd;
    public StringType encoding;
    public StringType docType;
    ///Loads system entities if needed.
    ///If not used, then it can protect against certain system entity attacks at the
    ///cost of having this feature disabled.
    public @safe StringType delegate(StringType path) sysEntityLoader;

    /++ Generic constructor; forwards its arguments to the parser constructor +/
    this(Args...)(Args args)
    {
        parser = P(args);
    }

    static if (isSaveableLowLevelParser!P)
    {
        public auto save()
        {
            auto result = this;
            result.parser = parser.save;
            return result;
        }
    }
    ///Returns true if XML declaration was not found.
    public @property bool xmlDeclNotFound() @nogc @safe pure nothrow
    {   
        return _xmlDeclNotFound;
    }
    /+
    /** 
     * Preprocesses the document, mainly the declaration (sets document version and encoding) and the Document type.
     * NOTE: Does not want to process anything beyond the first processing instruction (`<?xml [...] ?>`) for unknown
     * reasons, and I cannot get the debugger to find the reason.
     */
    public void preprocess() {
        import std.array;
        int i;
        do
        {
            i++;
            switch (currentNode.kind) {
                case XMLKind.document:
                    //enter();
                    break;
                case XMLKind.processingInstruction:
                    auto attrl = attributes().array;
                    foreach (attr ; attrl) {
                        //Attribute!StringType attr = attrl.front;
                        switch (attr.name) {
                            case "version":
                                if (attr.value == "1.0")
                                {
                                    parser.xmlVersion = XMLVersion.XML1_0;
                                }
                                else if (attr.value == "1.1")
                                {
                                    parser.xmlVersion = XMLVersion.XML1_1;
                                }
                                break;
                            case "encoding":
                                encoding = attr.value;
                                break;
                            default:
                                break;  //Check whether other types of attributes are allowed here.
                        }
                    }
                    //exit();
                    /+if (!enter())
                        goto exitloop;+/
                    break;
                case XMLKind.dtdStart: 
                    docType = content();
                    if (!enter())
                        goto exitloop;
                    break;
                case XMLKind.dtdEmpty:
                    docType = content();
                    goto exitloop;
                case XMLKind.entityDecl:
                    StringType entName = name();
                    //Check for external entities.
                    parser.chrEntities[entName] = content();
                    break;
                case XMLKind.attlistDecl, XMLKind.elementDecl, XMLKind.notationDecl, XMLKind.declaration:
                    break;
                default:
                    goto exitloop;   
            }

        }
        while (next);
        exitloop:
        exit();
    }+/

    private bool advanceInput()
    {
        colon = colon.max;
        nameEnd = 0;
        parser.popFront();
        if (!parser.empty)
        {
            currentNode = parser.front;
            return true;
        }
        _documentEnd = true;
        return false;
    }


    static if (needSource!P)
    {
        /++
        +   The type of input accepted by this parser,
        +   i.e., the one accepted by the underlying low level parser.
        +/
        alias InputType = P.InputType;

        /++
        +   Initializes this cursor (and the underlying low level parser) with the given input.
        +/
        void setSource(InputType input)
        {
            parser.setSource(input);
            initialize();
        }
    }

    private void initialize()
    {
        // reset private fields
        nextFailed = false;
        _xmlDeclNotFound = false;
        colon = colon.max;
        nameEnd = 0;

        if (!parser.empty)
        {
            if (parser.front.kind == XMLKind.processingInstruction &&
                parser.front.content.length >= 3 &&
                fastEqual(parser.front.content[0..3], "xml"))
            {
                currentNode = parser.front;
            }
            else
            {
                // document without xml declaration???
                // It turns out XML declaration is not mandatory, just assume UTF-8 and XML version 1.0 if it's missing!
                currentNode.kind = XMLKind.processingInstruction;
                currentNode.content = "xml version = \"1.0\" encoding = \"UTF-8\"";
                _xmlDeclNotFound = true;
            }
            starting = true;
            _documentEnd = false;
        }
        else
            _documentEnd = true;
    }

    /++ Returns whether the cursor is at the end of the document. +/
    bool documentEnd()
    {
        return _documentEnd;
    }

    /++
    +   Returns whether the cursor is at the beginning of the document
    +   (i.e. whether no `enter`/`next`/`exit` has been performed successfully and thus
    +   the cursor points to the xml declaration)
    +/
    bool atBeginning()
    {
        return starting;
    }

    /++
    +   Advances to the first child of the current node and returns `true`.
    +   If it returns `false`, the cursor is either on the same node (it wasn't
    +   an element start) or it is at the close tag of the element it was called on
    +   (it was a pair open/close tag without any content)
    +/
    bool enter()
    {
        if (starting)
        {
            starting = false;
            if (currentNode.content is parser.front.content)
                return advanceInput();
            else
            {
                nameEnd = 0;
                nameBegin = 0;
            }

            currentNode = parser.front;
            return true;
        }
        else if (currentNode.kind == XMLKind.elementStart)
        {
            return advanceInput() && currentNode.kind != XMLKind.elementEnd;
        }
        else if (currentNode.kind == XMLKind.dtdStart)
        {
            return advanceInput() && currentNode.kind != XMLKind.dtdEnd;
        }
        else
            return false;
    }

    /++ Advances to the end of the parent of the current node. +/
    void exit()
    {
        if (!nextFailed)
            while (next()) {}

        nextFailed = false;
    }

    /++
    +   Advances to the _next sibling of the current node.
    +   Returns whether it succeded. If it fails, either the
    +   document has ended or the only meaningful operation is `exit`.
    +/
    bool next()
    {
        if (parser.empty || starting || nextFailed)
            return false;
        else if (currentNode.kind == XMLKind.dtdStart)
        {
            /+while (advanceInput && currentNode.kind != XMLKind.dtdEnd) 
            {
                
            }+/
        }
        else if (currentNode.kind == XMLKind.elementStart)
        {
            int count = 1;
            static if (processBadDocument == No.processBadDocument)
                StringType currName = name;
            while (count > 0 && !parser.empty)
            {
                if (!advanceInput)
                    return false;
                if (currentNode.kind == XMLKind.elementStart)
                    count++;
                else if (currentNode.kind == XMLKind.elementEnd)
                    count--;
            }
            static if (processBadDocument == No.processBadDocument)
            {
                if (count != 0 || currName != name)
                    throw new CursorException("Document is malformed!");
            }
        }
        if (!advanceInput || currentNode.kind == XMLKind.elementEnd || currentNode.kind == XMLKind.dtdEnd)
        {
            nextFailed = true;
            return false;
        }
        return true;
    }

    /++ Returns the _kind of the current node. +/
    XMLKind kind() const
    {
        if (starting)
            return XMLKind.document;

        static if (conflateCDATA == Yes.conflateCDATA)
            if (currentNode.kind == XMLKind.cdata)
                return XMLKind.text;

        return currentNode.kind;
    }

    /++
    +   If the current node is an element or a doctype, returns its complete _name;
    +   it it is a processing instruction, return its target;
    +   otherwise, returns an empty string;
    +/
    StringType name()
    {
        switch (currentNode.kind)
        {
            case XMLKind.document:
            case XMLKind.text:
            case XMLKind.cdata:
            case XMLKind.comment:
            case XMLKind.declaration:
            case XMLKind.conditional:
            case XMLKind.dtdStart:
            case XMLKind.dtdEmpty:
            case XMLKind.dtdEnd:
                return [];
            default:
                if (!nameEnd)
                {
                    ptrdiff_t i, j;
                    if ((j = fastIndexOfNeither(currentNode.content, " \r\n\t")) >= 0)
                        nameBegin = j;
                    if ((i = fastIndexOfAny(currentNode.content[nameBegin..$], " \r\n\t")) >= 0)
                        nameEnd = i + nameBegin;
                    else
                        nameEnd = currentNode.content.length;
                }
                return currentNode.content[nameBegin..nameEnd];
        }
    }

    /++
    +   If the current node is an element, returns its local name (without namespace prefix);
    +   otherwise, returns the same result as `name`.
    +/
    StringType localName()
    {
        auto name = name();
        if (currentNode.kind == XMLKind.elementStart || currentNode.kind == XMLKind.elementEnd)
        {
            if (colon == colon.max)
                colon = fastIndexOf(name, ':');
            return name[(colon+1)..$];
        }
        return name;
    }

    /++
    +   If the current node is an element, returns its namespace _prefix;
    +   otherwise, the result in unspecified;
    +/
    StringType prefix()
    {
        if (currentNode.kind == XMLKind.elementStart || currentNode.kind == XMLKind.elementEnd)
        {
            auto name = name;
            if (colon == colon.max)
                colon = fastIndexOf(name, ':');

            if (colon >= 0)
                return name[0..colon];
            else
                return [];
        }
        return [];
    }

    /++
    +   If the current node is an element, return its _attributes as a range of triplets
    +   (`prefix`, `name`, `value`); if the current node is the document node, return the _attributes
    +   of the xml declaration (encoding, version, ...); otherwise, returns an empty array.
    +/
    auto attributes() @trusted
    {
        

        auto kind = currentNode.kind;
        if (kind == XMLKind.elementStart || kind == XMLKind.elementEmpty || kind == XMLKind.processingInstruction)
        {
            name;
            return AttributesRange(currentNode.content[nameEnd..$], this);
        }
        else
            return AttributesRange();
    }

    /++
    +   Return the text content of a cdata section, a comment or a text node;
    +   in all other cases, returns the entire node without the name
    +/
    StringType content()
    {
        if (currentNode.kind == XMLKind.entityDecl) 
        {
            sizediff_t b = fastIndexOfAny(currentNode.content[nameEnd..$], "\"\'");
            sizediff_t e = fastLastIndexOf(currentNode.content[nameEnd..$], currentNode.content[b + nameEnd]);
            if (b > 0 && e > 0)
            {
                if (b + 1 <= e)
                    return currentNode.content[nameEnd + b + 1..nameEnd + e];
                else
                    return null;
            }
            else
            {
                static if (processBadDocument == No.processBadDocument)
                    throw new CursorException("Entity content not found!");
                else
                    return null;
            }
        }
        /* else if (currentNode.kind == XMLKind.dtdStart || currentNode.kind == XMLKind.dtdEmpty)
        {
            sizediff_t b = fastLastIndexOfAny(currentNode.content[nameEnd..$], " \r\n\t");
            if (b == -1)
                return null;
            sizediff_t e = fastIndexOfAny(currentNode.content[nameEnd + b..$], " \r\n\t");
            if (e == -1)
                return currentNode.content[nameEnd + b + 1..$];
            else
                return currentNode.content[nameEnd + b + 1..nameEnd + e];
        } */
        else
            return currentNode.content[nameEnd..$];
    }

    /++ Returns the entire text of the current node. +/
    StringType wholeContent() const
    {
        return currentNode.content;
    }
}

/++
+   Instantiates a specialized `Cursor` with the given underlying `parser` and
+   the given error handler (defaults to an error handler that just asserts 0).
+/
template cursor(Flag!"conflateCDATA" conflateCDATA = Yes.conflateCDATA)
{
    /* auto cursor(T)(auto ref T parser)
        if(isLowLevelParser!T)
    {
        return cursor(parser);
    } */
    auto cursor(T)(auto ref T parser)
        if(isLowLevelParser!T)
    {
        auto cursor = Cursor!(T, conflateCDATA)();
        cursor.parser = parser;
        if (!cursor.parser.empty)
        {
            cursor.initialize;
        }
        return cursor;
    }
}

unittest
{
    import newxml.lexers;
    import newxml.parser;
    import std.string : lineSplitter, strip;
    import std.algorithm : map;
    import std.array : array;
    import std.conv : to;

    wstring xml = q"{
    <?xml encoding = "utf-8" ?>
    <!DOCTYPE mydoc https://myUri.org/bla [
        <!ELEMENT myelem ANY>
        <!ENTITY   myent    "replacement text">
        <!ATTLIST myelem foo cdata #REQUIRED >
        <!NOTATION PUBLIC 'h'>
        <!FOODECL asdffdsa >
    ]>
    <aaa xmlns:myns="something">
        <myns:bbb myns:att='>'>
            <!-- lol -->
            Lots of Text!
            On multiple lines!
        </myns:bbb>
        <![CDATA[ Ciaone! ]]>
        <ccc/>
    </aaa>
    }";

    auto cursor = xml.lexer.parser.cursor;

    assert(cursor.atBeginning);

    // <?xml encoding = "utf-8" ?>
    assert(cursor.kind() == XMLKind.document);
    assert(cursor.name() == "xml");
    assert(cursor.prefix() == "");
    assert(cursor.localName() == "xml");
    assert(cursor.attributes().array == [Attribute!wstring("encoding", "utf-8")]);
    assert(cursor.content() == " encoding = \"utf-8\" ");

    assert(cursor.enter());
        assert(!cursor.atBeginning);

        // <!DOCTYPE mydoc https://myUri.org/bla [
        assert(cursor.kind == XMLKind.dtdStart);
        assert(cursor.wholeContent == " mydoc https://myUri.org/bla ");

        assert(cursor.enter);
            // <!ELEMENT myelem ANY>
            assert(cursor.kind == XMLKind.elementDecl);
            assert(cursor.wholeContent == " myelem ANY");

            assert(cursor.next);
            // <!ENTITY   myent    "replacement text">
            assert(cursor.kind == XMLKind.entityDecl);
            assert(cursor.wholeContent == "   myent    \"replacement text\"");
            assert(cursor.name == "myent");
            assert(cursor.content == "replacement text", to!string(cursor.content));

            assert(cursor.next);
            // <!ATTLIST myelem foo cdata #REQUIRED >
            assert(cursor.kind == XMLKind.attlistDecl);
            assert(cursor.wholeContent == " myelem foo cdata #REQUIRED ");

            assert(cursor.next);
            // <!NOTATION PUBLIC 'h'>
            assert(cursor.kind == XMLKind.notationDecl);
            assert(cursor.wholeContent == " PUBLIC 'h'");

            assert(cursor.next);
            // <!FOODECL asdffdsa >
            assert(cursor.kind == XMLKind.declaration);
            assert(cursor.wholeContent == "FOODECL asdffdsa ");

            assert(!cursor.next);

            //assert(cursor.parser._chrEntities["myent"] == "replacement text");
        cursor.exit;

        // ]>
        assert(cursor.kind == XMLKind.dtdEnd);
        assert(!cursor.wholeContent);
        assert(cursor.next);

        // <aaa xmlns:myns="something">
        assert(cursor.kind() == XMLKind.elementStart);
        assert(cursor.name() == "aaa");
        assert(cursor.prefix() == "");
        assert(cursor.localName() == "aaa");
        assert(cursor.attributes().array == [Attribute!wstring("xmlns:myns", "something")]);
        assert(cursor.content() == " xmlns:myns=\"something\"");

        assert(cursor.enter());
            // <myns:bbb myns:att='>'>
            assert(cursor.kind() == XMLKind.elementStart);
            assert(cursor.name() == "myns:bbb");
            assert(cursor.prefix() == "myns");
            assert(cursor.localName() == "bbb");
            assert(cursor.attributes().array == [Attribute!wstring("myns:att", ">")]);
            assert(cursor.content() == " myns:att='>'");

            assert(cursor.enter());
            cursor.exit();

            // </myns:bbb>
            assert(cursor.kind() == XMLKind.elementEnd);
            assert(cursor.name() == "myns:bbb");
            assert(cursor.prefix() == "myns");
            assert(cursor.localName() == "bbb");
            assert(cursor.attributes().empty);
            assert(cursor.content() == []);

            assert(cursor.next());
            // <![CDATA[ Ciaone! ]]>
            assert(cursor.kind() == XMLKind.text);
            assert(cursor.name() == "");
            assert(cursor.prefix() == "");
            assert(cursor.localName() == "");
            assert(cursor.attributes().empty);
            assert(cursor.content() == " Ciaone! ");

            assert(cursor.next());
            // <ccc/>
            assert(cursor.kind() == XMLKind.elementEmpty);
            assert(cursor.name() == "ccc");
            assert(cursor.prefix() == "");
            assert(cursor.localName() == "ccc");
            assert(cursor.attributes().empty);
            assert(cursor.content() == []);

            assert(!cursor.next());
        cursor.exit();

        // </aaa>
        assert(cursor.kind() == XMLKind.elementEnd);
        assert(cursor.name() == "aaa");
        assert(cursor.prefix() == "");
        assert(cursor.localName() == "aaa");
        assert(cursor.attributes().empty);
        assert(cursor.content() == []);

        assert(!cursor.next());
    cursor.exit();

    assert(cursor.documentEnd);
    assert(!cursor.atBeginning);
}

/++
+   Returns an input range of the children of the node currently pointed by `cursor`.
+
+   Advancing the range returned by this function also advances `cursor`. It is thus
+   not recommended to interleave usage of this function with raw usage of `cursor`.
+/
auto children(T)(ref T cursor) @trusted
    if (isCursor!T)
{
    struct XMLRange
    {
        T* cursor;
        bool endReached;

        bool empty() const { return endReached; }
        void popFront() { endReached = !cursor.next(); }
        ref T front() { return *cursor; }

        ~this() { cursor.exit; }
    }
    auto workaround() @system {
        return XMLRange(&cursor, cursor.enter);    
    }
    return workaround();
}

unittest
{
    import newxml.lexers;
    import newxml.parser;
    import std.string : lineSplitter, strip;
    import std.algorithm : map, equal;
    import std.array : array;
    import std.exception : assertThrown;
    import std.stdio;

    string xml = q{
    <?xml encoding = "utf-8" ?>
    <aaa xmlns:myns="something">
        <myns:bbb myns:att='>'>
            <!-- lol -->
            Lots of Text!
            On multiple lines!
        </myns:bbb>
        <![CDATA[ Ciaone! ]]>
        <ccc/>
    </aaa>
    };
    string xml_bad = q{
        <?xml encoding = "utf-8" ?>
        <AAA>
            <BBB attr = "this should fail &#xFFFFFFFFFF;" />
        </AAA>
    };

    //import std.experimental.allocator.mallocator;//import stdx.allocator.mallocator;

    //auto handler = () { assert(0, "Some problem here..."); };
    auto lexer = RangeLexer!(string)();
    
    auto cursor = lexer.parser.cursor!(Yes.conflateCDATA)();
    assert(cursor.documentEnd);
    cursor.setSource(xml);

    // <?xml encoding = "utf-8" ?>
    assert(cursor.kind() == XMLKind.document);
    assert(cursor.name() == "xml");
    assert(cursor.prefix() == "");
    assert(cursor.localName() == "xml");
    auto attrs = cursor.attributes;
    assert(attrs.front == Attribute!string("encoding", "utf-8"));
    attrs.popFront;
    assert(attrs.empty);
    assert(cursor.content() == " encoding = \"utf-8\" ");

    {
        auto range1 = cursor.children;
        // <aaa xmlns:myns="something">
        assert(range1.front.kind() == XMLKind.elementStart);
        assert(range1.front.name() == "aaa");
        assert(range1.front.prefix() == "");
        assert(range1.front.localName() == "aaa");
        attrs = range1.front.attributes;
        assert(attrs.front == Attribute!string("xmlns:myns", "something"));
        attrs.popFront;
        assert(attrs.empty);
        assert(range1.front.content() == " xmlns:myns=\"something\"");

        {
            auto range2 = range1.front.children();
            // <myns:bbb myns:att='>'>
            assert(range2.front.kind() == XMLKind.elementStart);
            assert(range2.front.name() == "myns:bbb");
            assert(range2.front.prefix() == "myns");
            assert(range2.front.localName() == "bbb");
            attrs = range2.front.attributes;
            assert(attrs.front == Attribute!string("myns:att", ">"));
            attrs.popFront;
            assert(attrs.empty);
            assert(range2.front.content() == " myns:att='>'");

            {
                auto range3 = range2.front.children();
                // <!-- lol -->
                assert(range3.front.kind() == XMLKind.comment);
                assert(range3.front.name() == "");
                assert(range3.front.prefix() == "");
                assert(range3.front.localName() == "");
                assert(range3.front.attributes.empty);
                assert(range3.front.content() == " lol ");

                range3.popFront;
                assert(!range3.empty);
                // Lots of Text!
                // On multiple lines!
                assert(range3.front.kind() == XMLKind.text);
                assert(range3.front.name() == "");
                assert(range3.front.prefix() == "");
                assert(range3.front.localName() == "");
                assert(range3.front.attributes().empty);
                // split and strip so the unittest does not depend on the newline policy or indentation of this file
                static immutable linesArr = ["Lots of Text!", "            On multiple lines!", "        "];
                assert(range3.front.content().lineSplitter.equal(linesArr));

                range3.popFront;
                assert(range3.empty);
            }

            range2.popFront;
            assert(!range2.empty);
            // <<![CDATA[ Ciaone! ]]>
            assert(range2.front.kind() == XMLKind.text);
            assert(range2.front.name() == "");
            assert(range2.front.prefix() == "");
            assert(range2.front.localName() == "");
            assert(range2.front.attributes().empty);
            assert(range2.front.content() == " Ciaone! ");

            range2.popFront;
            assert(!range2.empty());
            // <ccc/>
            assert(range2.front.kind() == XMLKind.elementEmpty);
            assert(range2.front.name() == "ccc");
            assert(range2.front.prefix() == "");
            assert(range2.front.localName() == "ccc");
            assert(range2.front.attributes().empty);
            assert(range2.front.content() == []);

            range2.popFront;
            assert(range2.empty());
        }

        range1.popFront;
        assert(range1.empty);
    }

    assert(cursor.documentEnd());
    {
        cursor.setSource(xml_bad);
        auto range1 = cursor.children();
        assert(range1.front.name == "AAA");
        auto range2 = range1.front.children();
        assert(range2.front.name == "BBB");
        auto range3 = range2.front.attributes();
        assertThrown!XMLException(range3.front());
    
    }
}

import std.traits : isArray;

/++
+   A cursor that wraps another cursor, copying all output strings.
+
+   The cursor specification ($(LINK2 ../interfaces/isCursor, `newxml.interfaces.isCursor`))
+   clearly states that a cursor (as the underlying parser and lexer) is free to reuse
+   its internal buffers and thus invalidate every output. This wrapper returns freshly
+   allocated strings, thus allowing references to its outputs to outlive calls to advancing
+   methods.
+
+   This type should not be instantiated directly, but using the helper function
+   `copyingCursor`.
+/
struct CopyingCursor(CursorType, Flag!"intern" intern = No.intern)
    if (isCursor!CursorType && isArray!(CursorType.StringType))
{
    alias StringType = CursorType.StringType;

    //mixin UsesAllocator!Alloc;

    CursorType cursor;
    alias cursor this;

    static if (intern == Yes.intern)
    {
        import std.typecons: Rebindable;

        Rebindable!(immutable StringType)[const StringType] interned;
    }

    private auto copy(StringType str) @system
    {
        static if (intern == Yes.intern)
        {
            auto match = str in interned;
            if (match)
                return *match;
        }

        import std.traits : Unqual;
        import std.experimental.allocator;//import stdx.allocator;
        import std.range.primitives : ElementEncodingType;
        import core.stdc.string : memcpy;

        alias ElemType = ElementEncodingType!StringType;
        ElemType[] cp;//auto cp = cast(ElemType[]) allocator.makeArray!(Unqual!ElemType)(str.length);
        cp.length = str.length;
        memcpy(cast(void*)cp.ptr, cast(void*)str.ptr, str.length * ElemType.sizeof);

        static if (intern == Yes.intern)
        {
            interned[str] = cp;
        }

        return cp;
    }

    auto name() @trusted
    {
        return copy(cursor.name);
    }
    auto localName() @trusted
    {
        return copy(cursor.localName);
    }
    auto prefix() @trusted
    {
        return copy(cursor.prefix);
    }
    auto content() @trusted
    {
        return copy(cursor.content);
    }
    auto wholeContent() @trusted
    {
        return copy(cursor.wholeContent);
    }

    auto attributes() @trusted
    {
        struct CopyRange
        {
            typeof(cursor.attributes()) attrs;
            alias attrs this;

            private CopyingCursor* parent;

            auto front()
            {
                auto attr = attrs.front;
                return Attribute!StringType(
                        parent.copy(attr.name),
                        parent.copy(attr.value),
                    );
            }
        }
        return CopyRange(cursor.attributes, &this);
    }
}

/++
+   Instantiates a suitable `CopyingCursor` on top of the given `cursor` and allocator.
+/
auto copyingCursor(Flag!"intern" intern = No.intern, CursorType)(auto ref CursorType cursor)
{
    auto res = CopyingCursor!(CursorType, intern)();
    res.cursor = cursor;
    return res;
}

unittest
{
    import newxml.lexers;
    import newxml.parser;
    

    wstring xml = q{
    <?xml encoding = "utf-8" ?>
    <aaa>
        <bbb>
            <aaa>
            </aaa>
        </bbb>
        Hello, world!
    </aaa>
    };

    auto cursor =
         xml
        .lexer
        .parser
        .cursor!(Yes.conflateCDATA)
        .copyingCursor!(Yes.intern)();

    assert(cursor.enter);
    auto a1 = cursor.name;
    assert(cursor.enter);
    auto b1 = cursor.name;
    assert(cursor.enter);
    auto a2 = cursor.name;
    assert(!cursor.enter);
    auto a3 = cursor.name;
    cursor.exit;
    auto b2 = cursor.name;
    cursor.exit;
    auto a4 = cursor.name;

    assert(a1 is a2);
    assert(a2 is a3);
    assert(a3 is a4);
    assert(b1 is b2);
}
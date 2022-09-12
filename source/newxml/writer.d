/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements components to put XML data in `OutputRange`s
+/

module newxml.writer;

import newxml.interfaces;
@safe:
private string ifCompiles(string code)
{
    return "static if (__traits(compiles, " ~ code ~ ")) " ~ code ~ ";\n";
}
private string ifCompilesElse(string code, string fallback)
{
    return "static if (__traits(compiles, " ~ code ~ ")) " ~ code ~ "; else " ~ fallback ~ ";\n";
}
private string ifAnyCompiles(string code, string[] codes...)
{
    if (codes.length == 0)
        return "static if (__traits(compiles, " ~ code ~ ")) " ~ code ~ ";";
    else
        return "static if (__traits(compiles, " ~ code ~ ")) " ~ code ~
                "; else " ~ ifAnyCompiles(codes[0], codes[1..$]);
}

import std.typecons : tuple;
import std.string;

private auto xmlDeclarationAttributes(StringType, Args...)(Args args)
{
    static assert(Args.length <= 3, "Too many arguments for xml declaration");

    // version specification
    static if (is(Args[0] == int))
    {
        assert(args[0] == 10 || args[0] == 11, "Invalid xml version specified");
        StringType versionString = args[0] == 10 ? "1.0" : "1.1";
        auto args1 = args[1..$];
    }
    else static if (is(Args[0] == StringType))
    {
        StringType versionString = args[0];
        auto args1 = args[1..$];
    }
    else
    {
        StringType versionString = [];
        auto args1 = args;
    }

    // encoding specification
    static if (is(typeof(args1[0]) == StringType))
    {
        auto encodingString = args1[0];
        auto args2 = args1[1..$];
    }
    else
    {
        StringType encodingString = [];
        auto args2 = args1;
    }

    // standalone specification
    static if (is(typeof(args2[0]) == bool))
    {
        StringType standaloneString = args2[0] ? "yes" : "no";
        auto args3 = args2[1..$];
    }
    else
    {
        StringType standaloneString = [];
        auto args3 = args2;
    }

    // catch other erroneous parameters
    static assert(typeof(args3).length == 0,
                  "Unrecognized attribute type for xml declaration: " ~ typeof(args3[0]).stringof);

    return tuple(versionString, encodingString, standaloneString);
}

/++
+   A collection of ready-to-use pretty-printers
+/
struct PrettyPrinters
{
    /++
    +   The minimal pretty-printer. It just guarantees that the input satisfies
    +   the xml grammar.
    +/
    struct Minimalizer(StringType)
    {
        // minimum requirements needed for correctness
        enum StringType beforeAttributeName = " ";
        enum StringType betweenPITargetData = " ";
    }
    /++
    +   A pretty-printer that indents the nodes with a tabulation character
    +   `'\t'` per level of nesting.
    +/
    struct Indenter(StringType)
    {
        // inherit minimum requirements
        Minimalizer!StringType minimalizer;
        alias minimalizer this;

        enum StringType afterNode = "\n";
        enum StringType attributeDelimiter = "'";

        uint indentation;
        enum StringType tab = "\t";
        void decreaseLevel() { indentation--; }
        void increaseLevel() { indentation++; }

        void beforeNode(Out)(ref Out output)
        {
            foreach (i; 0..indentation)
                output ~= tab;
        }
    }
}

/++
+   Component that outputs XML data to an `OutputRange`.
+
+   To format the XML data, it calls specific methods of the `PrettyPrinter`, if
+   they are defined. Otherwise, it just prints the data with the minimal markup required.
+   The currently available format callbacks are:
+   $(UL
+       $(LI `beforeNode`, called as the first operation of outputting every XML node;
+                          expected to return a string to be printed before the node)
+       $(LI `afterNode`, called as the last operation of outputting every XML node;
+                         expected to return a string to be printed after the node)
+       $(LI `increaseLevel`, called after the start of a node that may have children
+                             (like a start tag or a doctype with an internal subset))
+       $(LI `decreaseLevel`, called before the end of a node that had some children
+                             (i.e. before writing a closing tag or the end of a doctype
+                              with an internal subset))
+       $(LI `beforeAttributeName`, called to obtain a string to be used as spacing
+                                   between the tag name and the first attribute name
+                                   and between the attribute value and the name of the
+                                   next attribute; it is not used between the value
+                                   of the last attribute and the closing `>`, nor between
+                                   the tag name and the closing `>` if the element
+                                   has no attributes)
+       $(LI `beforeElementEnd`, called to obtain a string to be used as spacing
+                                before the closing `>` of a tag, that is after the
+                                last attribute name or after the tag name if the
+                                element has no attributes)
+       $(LI `afterAttributeName`, called to obtain a string to be used as spacing
+                                  between the name of an attribute and the `=` sign)
+       $(LI `beforeAttributeValue`, called to obtain a string to be used as spacing
+                                  between the `=` sign and the value of an attribute)
+       $(LI `formatAttribute(outputRange, attibuteValue)`, called to write out the value
+                                                           of an attribute)
+       $(LI `formatAttribute(attributeValue)`, called to obtain a string that represents
+                                               the formatted attribute to be printed; used
+                                               when the previous method is not defined)
+       $(LI `attributeDelimiter`, called to obtain a string that represents the delimiter
+                                  to be used when writing attributes; used when the previous
+                                  two methods are not defined; in this case the attribute
+                                  is not subject to any formatting, except prepending and
+                                  appending the string returned by this method)
+       $(LI `afterCommentStart`, called to obtain a string that represents the spacing
+                                 to be used between the `<!--` opening and the comment contents)
+       $(LI `beforeCommentEnd`, called to obtain a string that represents the spacing
+                                to be used between the comment contents and the closing `-->`)
+       $(LI `betweenPITargetData`, called to obtain a string to be used as spacing
+                                   between the target and data of a processing instruction)
+       $(LI `beforePIEnd`, called to obtain a string to be used as spacing between
+                           the processing instruction data and the closing `?>`)
+   )
+   Template arguments:
+       _StringType = The type of string to be targeted. The function `writeDOM` will take care of all UTF conversion
+   if necessary.
+       PrettyPrinter = A struct, that will handle any and all formatting.
+       validateTagOrder = If set to `Yes`, then tag order will be validated during writing.
+/
struct Writer(_StringType, alias PrettyPrinter = PrettyPrinters.Minimalizer)
    if(is(_StringType == string) || is(_StringType == wstring) || is(_StringType == dstring))
{
    alias StringType = _StringType;

    static if (is(PrettyPrinter))
        private PrettyPrinter prettyPrinter;
    else static if (is(PrettyPrinter!StringType))
        private PrettyPrinter!StringType prettyPrinter;
    else
        static assert(0, "Invalid pretty printer type for string type " ~ StringType.stringof);

    StringType output;
    
    bool startingTag = false, insideDTD = false;

    this(typeof(prettyPrinter) pretty)
    {
        prettyPrinter = pretty;
    }

    private template expand(string methodName)
    {
        import std.meta : AliasSeq;
        alias expand = AliasSeq!(
            "prettyPrinter." ~ methodName ~ "(output)",
            "output ~= prettyPrinter." ~ methodName
        );
    }
    private template formatAttribute(string attribute)
    {
        import std.meta : AliasSeq;
        alias formatAttribute = AliasSeq!(
            "prettyPrinter.formatAttribute(output, " ~ attribute ~ ")",
            "output ~= prettyPrinter.formatAttribute(" ~ attribute ~ ")",
            "defaultFormatAttribute(" ~ attribute ~ ", prettyPrinter.attributeDelimiter)",
            "defaultFormatAttribute(" ~ attribute ~ ")"
        );
    }

    private void defaultFormatAttribute(StringType attribute, StringType delimiter = "'")
    {
        // TODO: delimiter escaping
        output ~= delimiter;
        output ~= attribute;
        output ~= delimiter;
    }

    /++
    +   Outputs an XML declaration.
    +
    +   Its arguments must be an `int` specifying the version
    +   number (`10` or `11`), a string specifying the encoding (no check is performed on
    +   this parameter) and a `bool` specifying the standalone property of the document.
    +   Any argument can be skipped, but the specified arguments must respect the stated
    +   ordering (which is also the ordering required by the XML specification).
    +/
    void writeXMLDeclaration(Args...)(Args args)
    {
        auto attrs = xmlDeclarationAttributes!StringType(args);

        output ~= "<?xml";

        if (attrs[0])
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output ~= "version";
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output ~= "=";
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"attrs[0]"));
        }
        if (attrs[1])
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output ~= "encoding";
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output ~= "=";
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"attrs[1]"));
        }
        if (attrs[2])
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output ~= "standalone";
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output ~= "=";
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"attrs[2]"));
        }

        mixin(ifAnyCompiles(expand!"beforePIEnd"));
        output ~= "?>";
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    void writeXMLDeclaration(StringType version_, StringType encoding, StringType standalone)
    {
        output ~= "<?xml";

        if (version_)
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output ~= "version";
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output ~= "=";
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"version_"));
        }
        if (encoding)
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output ~= "encoding";
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output ~= "=";
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"encoding"));
        }
        if (standalone)
        {
            mixin(ifAnyCompiles(expand!"beforeAttributeName"));
            output ~= "standalone";
            mixin(ifAnyCompiles(expand!"afterAttributeName"));
            output ~= "=";
            mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
            mixin(ifAnyCompiles(formatAttribute!"standalone"));
        }

        output ~= "?>";
        mixin(ifAnyCompiles(expand!"afterNode"));
    }

    /++
    +   Outputs a comment with the given content.
    +/
    void writeComment(StringType comment)
    {
        closeOpenThings;

        mixin(ifAnyCompiles(expand!"beforeNode"));
        output ~= "<!--";
        mixin(ifAnyCompiles(expand!"afterCommentStart"));

        mixin(ifCompilesElse(
            "prettyPrinter.formatComment(output, comment)",
            "output ~= comment"
        ));

        mixin(ifAnyCompiles(expand!"beforeCommentEnd"));
        output ~= "-->";
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    /++
    +   Outputs a text node with the given content.
    +/
    void writeText(StringType text)
    {
        //assert(!insideDTD);
        closeOpenThings;

        mixin(ifAnyCompiles(expand!"beforeNode"));
        mixin(ifCompilesElse(
            "prettyPrinter.formatText(output, comment)",
            "output ~= text"
        ));
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    /++
    +   Outputs a CDATA section with the given content.
    +/
    void writeCDATA(StringType cdata)
    {
        assert(!insideDTD);
        closeOpenThings;

        mixin(ifAnyCompiles(expand!"beforeNode"));
        output ~= "<![CDATA[";
        output ~= cdata;
        output ~= "]]>";
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    /++
    +   Outputs a processing instruction with the given target and data.
    +/
    void writeProcessingInstruction(StringType target, StringType data)
    {
        closeOpenThings;

        mixin(ifAnyCompiles(expand!"beforeNode"));
        output ~= "<?";
        output ~= target;
        mixin(ifAnyCompiles(expand!"betweenPITargetData"));
        output ~= data;

        mixin(ifAnyCompiles(expand!"beforePIEnd"));
        output ~= "?>";
        mixin(ifAnyCompiles(expand!"afterNode"));
    }

    private void closeOpenThings()
    {
        if (startingTag)
        {
            mixin(ifAnyCompiles(expand!"beforeElementEnd"));
            output ~= ">";
            mixin(ifAnyCompiles(expand!"afterNode"));
            startingTag = false;
            mixin(ifCompiles("prettyPrinter.increaseLevel"));
        }
    }

    void startElement(StringType tagName)
    {
        closeOpenThings();

        mixin(ifAnyCompiles(expand!"beforeNode"));
        output ~= "<";
        output ~= tagName;
        startingTag = true;
    }
    void closeElement(StringType tagName)
    {
        bool selfClose;
        mixin(ifCompilesElse(
            "selfClose = prettyPrinter.selfClosingElements",
            "selfClose = true"
        ));

        if (selfClose && startingTag)
        {
            mixin(ifAnyCompiles(expand!"beforeElementEnd"));
            output ~= "/>";
            startingTag = false;
        }
        else
        {
            closeOpenThings;

            mixin(ifCompiles("prettyPrinter.decreaseLevel"));
            mixin(ifAnyCompiles(expand!"beforeNode"));
            output ~= "</";
            output ~= tagName;
            mixin(ifAnyCompiles(expand!"beforeElementEnd"));
            output ~= ">";
        }
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    void writeAttribute(StringType name, StringType value)
    {
        assert(startingTag, "Cannot write attribute outside element start");

        mixin(ifAnyCompiles(expand!"beforeAttributeName"));
        output ~= name;
        mixin(ifAnyCompiles(expand!"afterAttributeName"));
        output ~= "=";
        mixin(ifAnyCompiles(expand!"beforeAttributeValue"));
        mixin(ifAnyCompiles(formatAttribute!"value"));
    }

    void startDoctype(StringType content)
    {
        assert(!insideDTD && !startingTag);

        mixin(ifAnyCompiles(expand!"beforeNode"));
        output ~= "<!DOCTYPE";
        output ~= content;
        mixin(ifAnyCompiles(expand!"afterDoctypeId"));
        output ~= "[";
        insideDTD = true;
        mixin(ifAnyCompiles(expand!"afterNode"));
        mixin(ifCompiles("prettyPrinter.increaseLevel"));
    }
    void closeDoctype()
    {
        assert(insideDTD);

        mixin(ifCompiles("prettyPrinter.decreaseLevel"));
        insideDTD = false;
        mixin(ifAnyCompiles(expand!"beforeDTDEnd"));
        output ~= "]>";
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
    void writeDeclaration(StringType decl, StringType content)
    {
        //assert(insideDTD);

        mixin(ifAnyCompiles(expand!"beforeNode"));
        output ~= "<!";
        output ~= decl;
        output ~= content;
        output ~= ">";
        mixin(ifAnyCompiles(expand!"afterNode"));
    }
}

unittest
{
    import std.array : Appender;
    import std.typecons : refCounted;

    //string app;
    auto writer = Writer!(string)();
    //writer.setSink(app);

    writer.writeXMLDeclaration(10, "utf-8", false);
    assert(writer.output == "<?xml version='1.0' encoding='utf-8' standalone='no'?>", writer.output);

    //static assert(isWriter!(typeof(writer)));
}

unittest
{
    import std.array : Appender;
    import std.typecons : refCounted;
    
    auto writer = Writer!(string, PrettyPrinters.Indenter)();

    writer.startElement("elem");
    writer.writeAttribute("attr1", "val1");
    writer.writeAttribute("attr2", "val2");
    writer.writeComment("Wonderful comment");
    writer.startElement("self-closing");
    writer.closeElement("self-closing");
    writer.writeText("Wonderful text");
    writer.writeCDATA("Wonderful cdata");
    writer.writeProcessingInstruction("pi", "it works");
    writer.closeElement("elem");

    import std.string : lineSplitter;
    auto splitter = writer.output.lineSplitter;

    assert(splitter.front == "<elem attr1='val1' attr2='val2'>", splitter.front);
    splitter.popFront;
    assert(splitter.front == "\t<!--Wonderful comment-->");
    splitter.popFront;
    assert(splitter.front == "\t<self-closing/>");
    splitter.popFront;
    assert(splitter.front == "\tWonderful text");
    splitter.popFront;
    assert(splitter.front == "\t<![CDATA[Wonderful cdata]]>");
    splitter.popFront;
    assert(splitter.front == "\t<?pi it works?>");
    splitter.popFront;
    assert(splitter.front == "</elem>");
    splitter.popFront;
    assert(splitter.empty);
}

import dom = newxml.dom;
import newxml.domstring;

/++
+   Outputs the entire DOM tree rooted at `node` using the given `writer`.
+/
void writeDOM(WriterType)(auto ref WriterType writer, dom.Node node)
{
    import std.traits : ReturnType;
    import newxml.faststrings;
    alias Document = typeof(node.ownerDocument);
    alias Element = ReturnType!(Document.documentElement);
    alias StringType = writer.StringType;

    switch (node.nodeType) with (dom.NodeType)
    {
        case document:
            auto doc = cast(Document)node;
            DOMString xmlVersion = doc.xmlVersion, xmlEncoding = doc.xmlEncoding;
            writer.writeXMLDeclaration(xmlVersion ? xmlVersion.transcodeTo!StringType() : null, 
                    xmlEncoding ? xmlEncoding.transcodeTo!StringType() : null, doc.xmlStandalone);
            foreach (child; doc.childNodes)
                writer.writeDOM(child);
            break;
        case element:
            auto elem = cast(Element)node;
            writer.startElement(elem.tagName.transcodeTo!StringType);
            if (elem.hasAttributes)
                foreach (attr; elem.attributes)
                    writer.writeAttribute(attr.nodeName.transcodeTo!StringType, 
                            xmlEscape(attr.nodeValue.transcodeTo!StringType));
            foreach (child; elem.childNodes)
                writer.writeDOM(child);
            writer.closeElement(elem.tagName.transcodeTo!StringType);
            break;
        case text:
            writer.writeText(xmlEscape(node.nodeValue.transcodeTo!StringType));
            break;
        case cdataSection:
            writer.writeCDATA(xmlEscape(node.nodeValue.transcodeTo!StringType));
            break;
        case comment:
            writer.writeComment(node.nodeValue.transcodeTo!StringType);
            break;
        default:
            break;
    }
}

unittest
{
    import newxml.domimpl;
    Writer!(string, PrettyPrinters.Minimalizer) wrt = Writer!(string)(PrettyPrinters.Minimalizer!string());

    dom.DOMImplementation domimpl = new DOMImplementation;
    dom.Document doc = domimpl.createDocument(null, new DOMString("doc"), null);
    dom.Element e0 = doc.createElement(new DOMString("text"));
    doc.firstChild.appendChild(e0);
    e0.setAttribute(new DOMString("something"), new DOMString("other thing"));
    e0.appendChild(doc.createTextNode(new DOMString("Some text ")));
    dom.Element e1 = doc.createElement(new DOMString("b"));
    e1.appendChild(doc.createTextNode(new DOMString("with")));
    e0.appendChild(e1);
    e0.appendChild(doc.createTextNode(new DOMString(" markup.")));
    
    wrt.writeDOM(doc);

    assert(wrt.output == "<?xml version='1.0' standalone='no'?><doc><text something='other thing'>Some text <b>with</b> markup.</text></doc>", wrt.output);
}

import std.typecons : Flag, No, Yes;

/++
+   Writes the contents of a cursor to a writer.
+
+   This method advances the cursor till the end of the document, outputting all
+   nodes using the given writer. The actual work is done inside a fiber, which is
+   then returned. This means that if the methods of the cursor call `Fiber.yield`,
+   this method will not complete its work, but will return a fiber in `HOLD` status,
+   which the user can `call` to advance the work. This is useful if the cursor
+   has to wait for other nodes to be ready (e.g. if the cursor input is generated
+   programmatically).
+/
auto writeCursor(Flag!"useFiber" useFiber = No.useFiber, WriterType, CursorType)
                (auto ref WriterType writer, auto ref CursorType cursor)
{
    alias StringType = WriterType.StringType;
    void inspectOneLevel() @safe
    {
        do
        {
            switch (cursor.kind) with (XMLKind)
            {
                case document:
                    StringType version_, encoding, standalone;
                    foreach (attr; cursor.attributes)
                        if (attr.name == "version")
                            version_ = attr.value;
                        else if (attr.name == "encoding")
                            encoding = attr.value;
                        else if (attr.name == "standalone")
                            standalone = attr.value;
                    writer.writeXMLDeclaration(version_, encoding, standalone);
                    if (cursor.enter)
                    {
                        inspectOneLevel();
                        cursor.exit;
                    }
                    break;
                case dtdEmpty:
                case dtdStart:
                    writer.startDoctype(cursor.wholeContent);
                    if (cursor.enter)
                    {
                        inspectOneLevel();
                        cursor.exit;
                    }
                    writer.closeDoctype();
                    break;
                case attlistDecl:
                    writer.writeDeclaration("ATTLIST", cursor.wholeContent);
                    break;
                case elementDecl:
                    writer.writeDeclaration("ELEMENT", cursor.wholeContent);
                    break;
                case entityDecl:
                    writer.writeDeclaration("ENTITY", cursor.wholeContent);
                    break;
                case notationDecl:
                    writer.writeDeclaration("NOTATION", cursor.wholeContent);
                    break;
                case declaration:
                    writer.writeDeclaration(cursor.name, cursor.content);
                    break;
                case text:
                    writer.writeText(cursor.content);
                    break;
                case cdata:
                    writer.writeCDATA(cursor.content);
                    break;
                case comment:
                    writer.writeComment(cursor.content);
                    break;
                case processingInstruction:
                    writer.writeProcessingInstruction(cursor.name, cursor.content);
                    break;
                case elementStart:
                case elementEmpty:
                    writer.startElement(cursor.name);
                    for (auto attrs = cursor.attributes; !attrs.empty; attrs.popFront)
                    {
                        auto attr = attrs.front;
                        writer.writeAttribute(attr.name, attr.value);
                    }
                    if (cursor.enter)
                    {
                        inspectOneLevel();
                        cursor.exit;
                    }
                    writer.closeElement(cursor.name);
                    break;
                default:
                    break;
                    //assert(0);
            }
        }
        while (cursor.next);
    }

    static if (useFiber)
    {
        import core.thread: Fiber;
        auto fiber = new Fiber(&inspectOneLevel);
        fiber.call;
        return fiber;
    }
    else
        inspectOneLevel();
}

unittest
{
    import std.array : Appender;
    import newxml.parser;
    import newxml.cursor;
    import newxml.lexers;
    import std.typecons : refCounted;

    string xml =
    "<?xml?>\n" ~
    "<!DOCTYPE ciaone [\n" ~
    "\t<!ELEMENT anything here>\n" ~
    "\t<!ATTLIST no check at all...>\n" ~
    "\t<!NOTATION dunno what to write>\n" ~
    "\t<!ENTITY .....>\n" ~
    "\t<!I_SAID_NO_CHECKS_AT_ALL_BY_DEFAULT>\n" ~
    "]>\n";

    auto cursor = xml.lexer.parser.cursor;
    cursor.setSource(xml);

    auto writer = Writer!(string, PrettyPrinters.Indenter)();

    writer.writeCursor(cursor);

    assert(writer.output == xml);
}

/++
+   A wrapper around a writer that, before forwarding every write operation, validates
+   the input given by the user using a chain of validating cursors.
+
+   This type should not be instantiated directly, but with the helper function
+   `withValidation`.
+/
struct CheckedWriter(WriterType, CursorType = void)
    if (isWriter!(WriterType) && (is(CursorType == void) ||
       (isCursor!CursorType && is(WriterType.StringType == CursorType.StringType))))
{
    import core.thread : Fiber;
    private Fiber fiber;
    private bool startingTag = false;

    WriterType writer;
    alias writer this;

    alias StringType = WriterType.StringType;

    static if (is(CursorType == void))
    {
        struct Cursor
        {
            import newxml.cursor: Attribute;
            import std.container.array;

            alias StringType = WriterType.StringType;

            private StringType _name, _content;
            private Array!(Attribute!StringType) attrs;
            private XMLKind _kind;
            private size_t colon;
            private bool initialized;

            void _setName(StringType name)
            {
                import newxml.faststrings;
                _name = name;
                auto i = name.indexOf(':');
                if (i > 0)
                    colon = i;
                else
                    colon = 0;
            }
            void _addAttribute(StringType name, StringType value)
            {
                attrs.insertBack(Attribute!StringType(name, value));
            }
            void _setKind(XMLKind kind)
            {
                _kind = kind;
                initialized = true;
                attrs.clear;
            }
            void _setContent(StringType content) { _content = content; }

            auto kind()
            {
                if (!initialized)
                    Fiber.yield;

                return _kind;
            }
            auto name() { return _name; }
            auto prefix() { return _name[0..colon]; }
            auto content() { return _content; }
            auto attributes() { return attrs[]; }
            StringType localName()
            {
                if (colon)
                    return _name[colon+1..$];
                else
                    return [];
            }

            bool enter()
            {
                if (_kind == XMLKind.document)
                {
                    Fiber.yield;
                    return true;
                }
                if (_kind != XMLKind.elementStart)
                    return false;

                Fiber.yield;
                return _kind != XMLKind.elementEnd;
            }
            bool next()
            {
                Fiber.yield;
                return _kind != XMLKind.elementEnd;
            }
            void exit() {}
            bool atBeginning()
            {
                return !initialized || _kind == XMLKind.document;
            }
            bool documentEnd() { return false; }

            alias InputType = void*;
            StringType wholeContent()
            {
                assert(0, "Cannot call wholeContent on this type of cursor");
            }
            void setSource(InputType)
            {
                assert(0, "Cannot set the source of this type of cursor");
            }
        }
        Cursor cursor;
    }
    else
    {
        CursorType cursor;
    }

    void writeXMLDeclaration(Args...)(Args args)
    {
        auto attrs = xmlDeclarationAttributes!StringType(args);
        cursor._setKind(XMLKind.document);
        if (attrs[0])
            cursor._addAttribute("version", attrs[0]);
        if (attrs[1])
            cursor._addAttribute("encoding", attrs[1]);
        if (attrs[2])
            cursor._addAttribute("standalone", attrs[2]);
        fiber.call;
    }
    void writeXMLDeclaration(StringType version_, StringType encoding, StringType standalone)
    {
        cursor._setKind(XMLKind.document);
        if (version_)
            cursor._addAttribute("version", version_);
        if (encoding)
            cursor._addAttribute("encoding", encoding);
        if (standalone)
            cursor._addAttribute("standalone", standalone);
        fiber.call;
    }
    void writeComment(StringType text)
    {
        if (startingTag)
        {
            fiber.call;
            startingTag = false;
        }
        cursor._setKind(XMLKind.comment);
        cursor._setContent(text);
        fiber.call;
    }
    void writeText(StringType text)
    {
        if (startingTag)
        {
            fiber.call;
            startingTag = false;
        }
        cursor._setKind(XMLKind.text);
        cursor._setContent(text);
        fiber.call;
    }
    void writeCDATA(StringType text)
    {
        if (startingTag)
        {
            fiber.call;
            startingTag = false;
        }
        cursor._setKind(XMLKind.cdata);
        cursor._setContent(text);
        fiber.call;
    }
    void writeProcessingInstruction(StringType target, StringType data)
    {
        if (startingTag)
        {
            fiber.call;
            startingTag = false;
        }
        cursor._setKind(XMLKind.comment);
        cursor._setName(target);
        cursor._setContent(data);
        fiber.call;
    }
    void startElement(StringType tag)
    {
        if (startingTag)
            fiber.call;

        startingTag = true;
        cursor._setKind(XMLKind.elementStart);
        cursor._setName(tag);
    }
    void closeElement(StringType tag)
    {
        if (startingTag)
        {
            fiber.call;
            startingTag = false;
        }
        cursor._setKind(XMLKind.elementEnd);
        cursor._setName(tag);
        fiber.call;
    }
    void writeAttribute(StringType name, StringType value)
    {
        assert(startingTag);
        cursor._addAttribute(name, value);
    }
}

/+unittest
{
    import newxml.validation;
    import std.typecons : refCounted;

    string app;

    auto writer =
         Writer!(string, PrettyPrinters.Indenter)();
    writer.setSink(app);

    writer.writeXMLDeclaration(10, "utf-8", false);
    assert(app.data == "<?xml version='1.0' encoding='utf-8' standalone='no'?>\n");

    writer.writeComment("a nice comment");
    writer.startElement("aa;bb");
    writer.writeAttribute(";eh", "foo");
    writer.writeText("a nice text");
    writer.writeCDATA("a nice cdata");
    writer.closeElement("aabb");
}+/

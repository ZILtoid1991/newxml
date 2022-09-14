/*
*             Copyright László Szerémi 2022 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements a simple SAX parser.
+
+   Authors:
+   Lodovico Giaretta
+   László Szerémi
+
+   License:
+   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
+
+   Copyright:
+   Copyright Lodovico Giaretta 2016, László Szerémi 2022 --
+/

module newxml.sax;

import newxml.interfaces;
import newxml.cursor;
import newxml.faststrings;
@safe:
/++
+   A SAX parser built on top of a cursor.
+
+   Delegates are called when certain events are encountered, then it passes the necessary data to process the
+   element.
+/
struct SAXParser(T)
    if (isCursor!T)
{
    public T cursor;
    alias StringType = T.StringType;
    alias AttrRange = T.AttributesRange;
    ///Called when a Document declaration is reached.
    public void delegate(StringType[StringType] attributes) onDocument;
    ///Called on a non-empty element start. Provides access to the attributes.
    public void delegate(StringType name, StringType[StringType] attributes) onElementStart;
    ///Called on an empty element. Provides access to the attributes.
    public void delegate(StringType name, StringType[StringType] attributes) onElementEmpty;
    ///Called on a non-empty element ending.
    public void delegate(StringType name) onElementEnd;
    ///Called when a text chunk is encountered.
    public void delegate(StringType content) onText;
    ///Called when a comment is encountered.
    public void delegate(StringType content) onComment;
    ///Called when a processing instruction is encountered.
    public void delegate(StringType name, StringType content) onProcessingInstruction;
    ///Called when a CDataSection node is encountered.
    public void delegate(StringType content) onCDataSection;
    ///Called when a Document Type Declaration is encountered.
    public void delegate(StringType type, bool empty) onDocTypeDecl;

    /++
    +   Initializes this parser (and the underlying low level one) with the given input.
    +/
    void setSource(T.InputType input)
    {
        cursor.setSource(input);
    }

    static if (isSaveableCursor!T)
    {
        auto save()
        {
            auto result = this;
            result.cursor = cursor.save;
            return result;
        }
    }

    /++
    +   Processes the entire document; every time a node of
    +   `XMLKind` XXX is found, the corresponding method `onXXX(underlyingCursor)`
    +   of the handler is called, if it exists.
    +/
    void processDocument()
    {
        import std.traits : hasMember;
        while (!cursor.documentEnd)
        {
            switch (cursor.kind)
            {
                case XMLKind.document:
                    if (onDocument !is null)
                        onDocument(createAArray(cursor.attributes));
                    break;
                case XMLKind.dtdStart:
                    if (onDocTypeDecl !is null)
                        onDocTypeDecl(cursor.content, false);
                    break;
                case XMLKind.entityDecl:
                    if (checkStringBeforeChr(cursor.wholeContent, "SYSTEM", '"') || 
                            checkStringBeforeChr(cursor.wholeContent, "SYSTEM", '\''))
                    {
                        if (cursor.sysEntityLoader !is null)
                        {
                            cursor.parser.chrEntities[cursor.name] = cursor.sysEntityLoader(cursor.content);
                        }
                    } 
                    else 
                    {
                        cursor.parser.chrEntities[cursor.name] = cursor.content;
                    }
                    break;
                /* case XMLKind.dtdEnd:
                    break; */
                case XMLKind.dtdEmpty:
                    if (onDocTypeDecl !is null)
                        onDocTypeDecl(cursor.content, true);
                    break;
                case XMLKind.elementStart:
                    if (onElementStart !is null)
                        onElementStart(cursor.name, createAArray(cursor.attributes));
                    break;
                case XMLKind.elementEnd:
                    if (onElementEnd !is null)
                        onElementEnd(cursor.name);
                    break;
                case XMLKind.elementEmpty:
                    if (onElementEmpty !is null)
                        onElementEmpty(cursor.name, createAArray(cursor.attributes));
                    break;
                case XMLKind.text:
                    if (onText !is null)
                        onText(cursor.content);
                    break;
                case XMLKind.comment:
                    if (onComment !is null)
                        onComment(cursor.content);
                    break;
                case XMLKind.processingInstruction:
                    if (onProcessingInstruction !is null)
                        onProcessingInstruction(cursor.name, cursor.content);
                    break;
                case XMLKind.cdata:
                    if (onCDataSection !is null)
                        onCDataSection(cursor.content);
                    break;

                default: break;
            }

            if (cursor.enter)
            {
            }
            else if (!cursor.next)
            {
                cursor.exit;
            }
        }
    }
    protected StringType[StringType] createAArray(AttrRange source) {
        StringType[StringType] result;
        foreach (key; source)
        {
            result[key.name] = key.value;
        }
        return result;
    }
}

/++
+   Instantiates a suitable SAX parser from the given `cursor` and `handler`.
+/
auto saxParser(CursorType)(auto ref CursorType cursor)
    if (isCursor!CursorType)
{
    auto res = SAXParser!(CursorType)();
    res.cursor = cursor;
    return res;
}

unittest
{
    import newxml.parser;
    import newxml.lexers;
    import std.conv : to;

    dstring xml = q{
    <?xml encoding = "utf-8" ?>
    <!DOCTYPE somekindofdoc   >
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

    struct MyHandler
    {
        int max_nesting;
        int current_nesting;
        int total_invocations;

        void onElementStart(dstring name, dstring[dstring] attributes)
        {
            total_invocations++;
            current_nesting++;
            if (current_nesting > max_nesting)
            {
                max_nesting = current_nesting;
            }
        }
        void onElementEnd(dstring name)
        {
            total_invocations++;
            current_nesting--;
        }
        void onElementEmpty(dstring name, dstring[dstring] attributes) { total_invocations++; }
        void onProcessingInstruction(dstring name, dstring content) { total_invocations++; }
        void onText(dstring content) { total_invocations++; }
        void onDocument(dstring[dstring] attribute)
        {
            assert(attribute["encoding"] == "utf-8");
            total_invocations++;
        }
        void onComment(dstring content)
        {
            assert(content == " lol ");
            total_invocations++;
        }
        void onDocTypeDecl(dstring type, bool empty) {
            assert(type == "somekindofdoc", type.to!string);
            assert(empty);
        }
    }


    MyHandler handler;
    auto parser =
         xml
        .lexer
        .parser
        .cursor
        .saxParser;

    parser.setSource(xml);
    parser.onDocument = &handler.onDocument;
    parser.onElementStart = &handler.onElementStart;
    parser.onElementEnd = &handler.onElementEnd;
    parser.onElementEmpty = &handler.onElementEmpty;
    parser.onText = &handler.onText;
    parser.onComment = &handler.onComment;
    parser.onProcessingInstruction = &handler.onProcessingInstruction;
    parser.onDocTypeDecl = &handler.onDocTypeDecl;
    parser.processDocument();

    assert(handler.max_nesting == 2, to!string(handler.max_nesting));
    assert(handler.current_nesting == 0, to!string(handler.current_nesting));
    assert(handler.total_invocations == 9, to!string(handler.total_invocations));
}

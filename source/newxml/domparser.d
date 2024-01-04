/*
*             Copyright László Szerémi 2022 - .
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
+   Copyright László Szerémi 2022 --
+/

module newxml.domparser;

import newxml.interfaces;
import newxml.cursor;

import dom = newxml.dom;
import newxml.domimpl;

/++
+   Built on top of Cursor, the DOM builder adds to it the ability to
+   build the DOM tree of the document; as the cursor advances, nodes can be
+   selectively added to the tree, allowing to built a small representation
+   containing only the needed parts of the document.
+
+   This type should not be instantiated directly. Instead, the helper function
+   `domBuilder` should be used.
+/
struct DOMBuilder(T) if (isCursor!T)
{
    import std.traits : ReturnType;

    /++
    +   The underlying Cursor methods are exposed, so that one can, query the properties
    +   of the current node before deciding if building it or not.
    +/
    T cursor;
    alias cursor this;

    alias StringType = T.StringType;

    alias DocType = ReturnType!(DOMImplementation.createDocument);
    alias NodeType = typeof(DocType.firstChild);

    private NodeType currentNode;
    private DOMImplementation.Document document;
    private DOMImplementation.DocumentType docType;
    private DOMImplementation domImpl;
    private bool already_built;

    this(Args...)(DOMImplementation impl, auto ref Args args)
    {
        cursor = typeof(cursor)(args);
        domImpl = impl;
    }

    private void initialize()
    {
        document = domImpl.createDocument(null, null, null);

        if (cursor.kind == XMLKind.document)
        {
            foreach (attr; cursor.attributes)
            {
                switch (attr.name)
                {
                case "version":
                    document.xmlVersion = attr.value;
                    switch (attr.value)
                    {
                    case "1.1":
                        cursor.xmlVersion = XMLVersion.XML1_1;
                        break;
                    default:
                        cursor.xmlVersion = XMLVersion.XML1_0;
                        break;
                    }
                    break;
                case "standalone":
                    document.xmlStandalone = attr.value == "yes";
                    break;
                default:
                    break;
                }
            }
        }

        currentNode = document;
    }

    /++
    +   Initializes this builder and the underlying components.
    +/
    void setSource(T.InputType input)
    {
        cursor.setSource(input);
        initialize();
    }

    /++
    +   Same as `cursor.enter`. When entering a node, that node is automatically
    +   built into the DOM, so that its children can then be safely built if needed.
    +/
    bool enter()
    {
        if (cursor.atBeginning)
        {
            return cursor.enter;
        }

        if (cursor.kind != XMLKind.elementStart)
        {
            return false;
        }

        if (!already_built)
        {
            auto elem = createCurrent;

            if (cursor.enter)
            {
                currentNode.appendChild(elem);
                currentNode = elem;
                return true;
            }
        }
        else if (cursor.enter)
        {
            already_built = false;
            currentNode = currentNode.lastChild;
            return true;
        }

        return false;
    }

    /++
    +   Same as `cursor.exit`
    +/
    void exit()
    {
        if (currentNode)
        {
            currentNode = currentNode.parentNode;
        }

        already_built = false;
        cursor.exit;
    }

    /++
    +   Same as `cursor.next`.
    +/
    bool next()
    {
        already_built = false;
        return cursor.next;
    }

    /++
    +   Adds the current node to the DOM. This operation does not advance the input.
    +   Calling it more than once does not change the result.
    +/
    void build()
    {
        if (already_built || cursor.atBeginning)
        {
            return;
        }

        auto cur = createCurrent;
        if (cur)
        {
            currentNode.appendChild(createCurrent);
        }

        already_built = true;
    }

    /++
    +   Recursively adds the current node and all its children to the DOM tree.
    +   Behaves as `cursor.next`: it advances the input to the next sibling, returning
    +   `true` if and only if there exists such next sibling.
    +/
    bool buildRecursive()
    {
        if (enter())
        {
            while (buildRecursive())
            {
            }
            exit();
        }
        else
        {
            build();
        }

        return next();
    }

    private NodeType createCurrent() // TODO: handling of system (external) entities
    {
        switch (cursor.kind)
        {

            // XMLKind.elementEnd is needed for empty tags: <tag></tag>
        case XMLKind.elementEnd:
        case XMLKind.elementStart:
        case XMLKind.elementEmpty:
            /* DOMImplementation.Element elem = cursor.prefix.length ?
                        document.createElementNS(cursor.prefix, cursor.localName) :
                        document.createElement(cursor.name); */
            DOMImplementation.Element elem = document.createElement(cursor.name);
            foreach (attr; cursor.attributes)
            {
                /*if (attr.prefix.length)
                    {
                        elem.setAttributeNS(attr.prefix, attr.localName,
                                attr.value);
                    }
                    else
                    {*/
                elem.setAttribute(attr.name, attr.value);
                //}
            }
            return elem;
        case XMLKind.text:
            return document.createTextNode(cursor.content);
        case XMLKind.cdata:
            return document.createCDATASection(cursor.content);
        case XMLKind.processingInstruction:
            return document.createProcessingInstruction(cursor.name,
                    cursor.content);
        case XMLKind.comment:
            return document.createComment(cursor.content);
        case XMLKind.dtdStart, XMLKind.dtdEmpty:
            docType = domImpl.createDocumentType(cursor.name, "", "");
            document.doctype = docType;
            return null;
        case XMLKind.entityDecl:
            docType.createEntity(cursor.name, cursor.content);
            cursor.chrEntities[cursor.name] = cursor.content;
            return null;
        default:
            return null;
        }
    }

    /++
    +   Returns the Document being built by this builder.
    +/
    auto getDocument()
    {
        return document;
    }
}

/++
+   Instantiates a suitable `DOMBuilder` on top of the given `cursor` and `DOMImplementation`.
+/
auto domBuilder(CursorType)(auto ref CursorType cursor, DOMImplementation domimpl)
        if (isCursor!CursorType)
{
    auto res = DOMBuilder!(CursorType)(domimpl);
    res.cursor = cursor;
    //res.domImpl = impl;
    res.initialize;
    return res;
}

unittest
{
    import std.stdio;

    import newxml.lexers;
    import newxml.parser;
    import newxml.cursor;
    import domimpl = newxml.domimpl;

    alias DOMImpl = domimpl.DOMImplementation;

    string xml = q{
    <?xml encoding = "utf-8" ?>
    <aaa myattr="something" xmlns:myns="something">
        <myns:bbb myns:att='>'>
            <!-- lol -->
            Lots of Text!
            On multiple lines!
        </myns:bbb>
        <![CDATA[ Ciaone! ]]>
        <ccc/>
    </aaa>
    };

    auto builder = xml.lexer.parser.cursor.domBuilder(new DOMImpl());

    builder.setSource(xml);
    builder.buildRecursive;
    dom.Document doc = builder.getDocument;

    assert(doc.getElementsByTagName("ccc").length == 1);
    assert(doc.documentElement.getAttribute("myattr"));
    assert(doc.documentElement.getAttribute("myattr") == "something");
    assert(doc.documentElement.getAttribute("xmlns:myns"));
    assert(doc.documentElement.getAttribute("xmlns:myns") == "something");
    dom.Element e1 = cast(dom.Element) doc.firstChild;
    assert(e1.nodeName == "aaa");
    dom.Element e2 = cast(dom.Element) e1.firstChild();
    assert(e2.nodeName == "myns:bbb");
    dom.Comment c1 = cast(dom.Comment) e2.firstChild;
    assert(c1.data == " lol ");
    dom.Text t1 = cast(dom.Text) e2.lastChild;
    //Issue: Extra whitespace isn't dropped between and after words when dropWhiteSpace is enabled in
    //assert(t1.data == "Lots of Text! On multiple lines!", t1.data.transcodeToUTF8);

}

unittest
{
    import newxml.lexers;
    import newxml.parser;
    import newxml.cursor;
    import domimpl = newxml.domimpl;

    alias DOMImplType = domimpl.DOMImplementation;

    auto xml = `<?xml version="1.0" encoding="UTF-8"?><tag></tag>`;
    auto builder = xml.lexer.parser.cursor.copyingCursor.domBuilder(new DOMImplType());

    builder.setSource(xml);
    builder.buildRecursive;
    auto doc = builder.getDocument;

    assert(doc.childNodes.length == 1);
}

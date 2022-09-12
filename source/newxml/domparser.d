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
import newxml.domstring;

/++
+   Built on top of Cursor, the DOM builder adds to it the ability to
+   build the DOM tree of the document; as the cursor advances, nodes can be
+   selectively added to the tree, allowing to built a small representation
+   containing only the needed parts of the document.
+
+   This type should not be instantiated directly. Instead, the helper function
+   `domBuilder` should be used.
+/
struct DOMBuilder(T)
    if (isCursor!T)
{
    import std.traits : ReturnType;

    /++
    +   The underlying Cursor methods are exposed, so that one can, query the properties
    +   of the current node before deciding if building it or not.
    +/
    T cursor;
    alias cursor this;

    alias StringType = T.StringType;

    alias DocumentType = ReturnType!(DOMImplementation.createDocument);
    alias NodeType = typeof(DocumentType.firstChild);

    private NodeType currentNode;
    private DocumentType document;
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
                        document.xmlVersion = new DOMString(attr.value);
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
            currentNode.appendChild(createCurrent);

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

    private NodeType createCurrent()
    // TODO: namespace handling
    {
        switch (cursor.kind)
        {
            // XMLKind.elementEnd is needed for empty tags: <tag></tag>
            case XMLKind.elementEnd:
            case XMLKind.elementStart:
            case XMLKind.elementEmpty:
                auto elem = document.createElement(new DOMString(cursor.name));
                foreach (attr; cursor.attributes)
                {
                    elem.setAttribute(new DOMString(attr.name), new DOMString(attr.value));
                }
                return elem;
            case XMLKind.text:
                return document.createTextNode(new DOMString(cursor.content));
            case XMLKind.cdata:
                return document.createCDATASection(new DOMString(cursor.content));
            case XMLKind.processingInstruction:
                return document.createProcessingInstruction(new DOMString(cursor.name), new DOMString(cursor.content));
            case XMLKind.comment:
                return document.createComment(new DOMString(cursor.content));
            default:
                return null;
        }
    }

    /++
    +   Returns the Document being built by this builder.
    +/
    auto getDocument() { return document; }
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

    alias DOMImplType = domimpl.DOMImplementation;

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

    auto builder =
         xml
        .lexer
        .parser
        .cursor
        .domBuilder(new DOMImplType());

    builder.setSource(xml);
    builder.buildRecursive;
    auto doc = builder.getDocument;

    assert(doc.getElementsByTagName(new DOMString("ccc")).length == 1);
    assert(doc.documentElement.getAttribute(new DOMString("xmlns:myns")) == "something");
}

unittest
{
    import newxml.lexers;
    import newxml.parser;
    import newxml.cursor;
    import domimpl = newxml.domimpl;

    alias DOMImplType = domimpl.DOMImplementation;

    auto xml = `<?xml version="1.0" encoding="UTF-8"?><tag></tag>`;
    auto builder =
         xml
        .lexer
        .parser
        .cursor
        .copyingCursor
        .domBuilder(new DOMImplType());

    builder.setSource(xml);
    builder.buildRecursive;
    auto doc = builder.getDocument;

    assert(doc.childNodes.length == 1);
}

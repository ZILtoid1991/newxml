/*
*             Copyright László Szerémi 2022 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   Provides an implementation of the DOM Level 3 specification.
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

module newxml.domimpl;

import newxml.interfaces;
import newxml.domstring;

import dom = newxml.dom;
import std.typecons : rebindable, Flag, BitFlags;
//import std.experimental.allocator;//import stdx.allocator;
//import std.experimental.allocator.gc_allocator;//import stdx.allocator.gc_allocator;
import std.range.primitives;
import std.string;

/* // this is needed because compilers up to at least DMD 2.071.1 suffer from issue 16319
private auto multiVersionMake(Type, Args...)(auto ref Args args)
{
    static if (Args.length == 0  && __traits(compiles, allocator.make!Type(args)))
        return allocator.make!Type(args);
    else static if (Args.length > 0 && __traits(compiles, allocator.make!Type(args[0 .. $])))
    {
        auto res = allocator.make!Type(args[0 .. $]);
        return res;
    }
    else
        static assert(0, "multiVersionMake failed...");
} */

/++
+   An implementation of $(LINK2 ../dom/DOMImplementation, `std.experimental.xml.dom.DOMImplementation`).
+
+   It allows to specify a custom allocator to be used when creating instances of the DOM classes.
+   As keeping track of the lifetime of every node would be very complex, this implementation
+   does not try to do so. Instead, no object is ever deallocated; it is the users responsibility
+   to directly free the allocator memory when all objects are no longer reachable.
+/
class DOMImplementation : dom.DOMImplementation
{
@safe:
    //mixin UsesAllocator!(Alloc, true);
    this() @nogc @safe pure nothrow {
        
    }

	void enforce(Ex,T)(T cond, dom.ExceptionCode ec) {
		if(!cond)
		{
			throw new Ex(ec);
		}
	}
		
    override
    {
        /++
        +   Implementation of $(LINK2 ../dom/DOMImplementation.createDocumentType,
        +   `std.experimental.xml.dom.DOMImplementation.createDocumentType`).
        +/
        DocumentType createDocumentType(DOMString qualifiedName, DOMString publicId, DOMString systemId)
        {
            DocumentType res = new DocumentType();//allocator.multiVersionMake!DocumentType(this);
            res._name = qualifiedName;
            res._publicId = publicId;
            res._systemId = systemId;
            return res;
        }
        /++
        +   Implementation of $(LINK2 ../dom/DOMImplementation.createDocument,
        +   `std.experimental.xml.dom.DOMImplementation.createDocument`).
        +/
        Document createDocument(DOMString namespaceURI, DOMString qualifiedName, dom.DocumentType _doctype)
        {
            DocumentType doctype = cast(DocumentType)_doctype;
            enforce!DOMException(!(_doctype && !doctype),
                    dom.ExceptionCode.wrongDocument);

            Document doc = new Document();//allocator.multiVersionMake!Document(this);
            doc._ownerDocument = doc;
            doc._doctype = doctype;
            doc._config = new DOMConfiguration();//allocator.multiVersionMake!DOMConfiguration(this);

            if (namespaceURI)
            {
                enforce!DOMException(qualifiedName, dom.ExceptionCode.namespace);
                doc.appendChild(doc.createElementNS(namespaceURI, qualifiedName));
            }
            else if (qualifiedName)
                doc.appendChild(doc.createElement(qualifiedName));

            return doc;
        }
        /++
        +   Implementation of $(LINK2 ../dom/DOMImplementation.hasFeature,
        +   `std.experimental.xml.dom.DOMImplementation.hasFeature`).
        +
        +   Only recognizes features `"Core"`and `"XML"` with versions `"1.0"`,
        +   `"2.0"` or `"3.0"`.
        +/
        bool hasFeature(string feature, string version_)
        {
            import std.uni: sicmp;
            return (!sicmp(feature, "Core") || !sicmp(feature, "XML"))
                && (version_ == "1.0" || version_ == "2.0" || version_ == "3.0");
        }
        /++
        +   Implementation of $(LINK2 ../dom/DOMImplementation.hasFeature,
        +   `std.experimental.xml.dom.DOMImplementation.hasFeature`).
        +
        +   Only recognizes features `"Core"`and `"XML"` with versions `"1.0"`,
        +   `"2.0"` or `"3.0"`. Always returns `this`.
        +/
        DOMImplementation getFeature(string feature, string version_)
        {
            if (hasFeature(feature, version_))
                return this;
            else
                return null;
        }
    }
    
    /++
    +   The implementation of $(LINK2 ../dom/DOMException, `std.experimental.xml.dom.DOMException`)
    +   thrown by this DOM implementation.
    +/
    class DOMException: dom.DOMException
    {
        /// Constructs a `DOMException` with a specific `dom.ExceptionCode`.
        pure nothrow @nogc @safe this(dom.ExceptionCode code, string file = __FILE__, size_t line = __LINE__, 
            Throwable nextInChain = null)
        {
            _code = code;
            super("", file, line);
        }
        @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
        {
        super(msg, file, line, nextInChain);
        }
        /// Implementation of $(LINK2 ../dom/DOMException.code, `std.experimental.xml.dom.DOMException.code`).
        override @property dom.ExceptionCode code()
        {
            return _code;
        }
        private dom.ExceptionCode _code;
    }
    /// Implementation of $(LINK2 ../dom/Node, `std.experimental.xml.dom.Node`)
    abstract class Node : dom.Node
    {
        package this() {

        }
        override
        {
            /// Implementation of $(LINK2 ../dom/Node.ownerDocument, `std.experimental.xml.dom.Node.ownerDocument`).
            @property Document ownerDocument() { return _ownerDocument; }

            /// Implementation of $(LINK2 ../dom/Node.parentNode, `std.experimental.xml.dom.Node.parentNode`).
            @property Node parentNode() { return _parentNode; }
            /++
            +   Implementation of $(LINK2 ../dom/Node.previousSibling,
            +   `std.experimental.xml.dom.Node.previousSibling`).
            +/
            @property Node previousSibling() { return _previousSibling; }
            /// Implementation of $(LINK2 ../dom/Node.nextSibling, `std.experimental.xml.dom.Node.nextSibling`).
            @property Node nextSibling() { return _nextSibling; }

            /++
            +   Implementation of $(LINK2 ../dom/Node.isSameNode, `std.experimental.xml.dom.Node.isSameNode`).
            +
            +   Equivalent to a call to `this is other`.
            +/
            bool isSameNode(dom.Node other)
            {
                return this is other;
            }
            /// Implementation of $(LINK2 ../dom/Node.isEqualNode, `std.experimental.xml.dom.Node.isEqualNode`).
            bool isEqualNode(dom.Node other)
            {
                import std.meta: AliasSeq;

                if (!other || nodeType != other.nodeType)
                    return false;

                foreach (field; AliasSeq!("nodeName", "localName", "namespaceURI", "prefix", "nodeValue"))
                {
                    mixin("auto a = " ~ field ~ ";\n");
                    mixin("auto b = other." ~ field ~ ";\n");
                    if ((a is null && b !is null) || (b is null && a !is null) || (a !is null && b !is null && a != b))
                        return false;
                }

                auto thisWithChildren = cast(NodeWithChildren)this;
                if (thisWithChildren)
                {
                    auto otherChild = other.firstChild;
                    foreach (child; thisWithChildren.childNodes)
                    {
                        if (!child.isEqualNode(otherChild))
                            return false;
                        otherChild = otherChild.nextSibling;
                    }
                    if (otherChild !is null)
                        return false;
                }

                return true;
            }

            /// Implementation of $(LINK2 ../dom/Node.setUserData, `std.experimental.xml.dom.Node.setUserData`).
            dom.UserData setUserData(string key, dom.UserData data, dom.UserDataHandler handler) @trusted
            {
                userData[key] = data;
                if (handler)
                    userDataHandlers[key] = handler;
                return data;
            }
            /// Implementation of $(LINK2 ../dom/Node.getUserData, `std.experimental.xml.dom.Node.getUserData`).
            dom.UserData getUserData(string key) const @trusted
            {
                if (key in userData)
                    return userData[key];
                return dom.UserData(null);
            }

            /++
            +   Implementation of $(LINK2 ../dom/Node.isSupported, `std.experimental.xml.dom.Node.isSupported`).
            +
            +   Only recognizes features `"Core"`and `"XML"` with versions `"1.0"`,
            +   `"2.0"` or `"3.0"`.
            +/
            bool isSupported(string feature, string version_)
            {
                return (feature == "Core" || feature == "XML")
                    && (version_ == "1.0" || version_ == "2.0" || version_ == "3.0");
            }
            /++
            +   Implementation of $(LINK2 ../dom/Node.getFeature, `std.experimental.xml.dom.Node.getFeature`).
            +
            +   Only recognizes features `"Core"`and `"XML"` with versions `"1.0"`,
            +   `"2.0"` or `"3.0"`. Always returns this.
            +/
            Node getFeature(string feature, string version_)
            {
                if (isSupported(feature, version_))
                    return this;
                else
                    return null;
            }

            /++
            +   Implementation of $(LINK2 ../dom/Node.compareDocumentPosition,
            +   `std.experimental.xml.dom.Node.compareDocumentPosition`).
            +/
            BitFlags!(dom.DocumentPosition) compareDocumentPosition(dom.Node _other) @trusted
            {
                enum Ret(dom.DocumentPosition flag) = cast(BitFlags!(dom.DocumentPosition)) flag;

                Node other = cast(Node)_other;
                if (!other)
                    return Ret!(dom.DocumentPosition.disconnected);

                if (this is other)
                    return Ret!(dom.DocumentPosition.none);

                Node node1 = other;
                Node node2 = this;
                Attr attr1 = cast(Attr)node1;
                Attr attr2 = cast(Attr)node2;

                if (attr1 && attr1.ownerElement)
                    node1 = attr1.ownerElement;
                if (attr2 && attr2.ownerElement)
                {
                    node2 = attr2.ownerElement;
                    if (attr1 && node2 is node1)
                    {
                        foreach (attr; (cast(Element)node2).attributes) with (dom.DocumentPosition)
                        {
                            if (attr is attr1)
                                return Ret!implementationSpecific | Ret!preceding;
                            else if (attr is attr2) {
                                return Ret!implementationSpecific | Ret!following;
                            }
                        }
                    }
                }
                void rootAndDepth(ref Node node, out int depth)
                {
                    while (node.parentNode)
                    {
                        node = node.parentNode;
                        depth++;
                    }
                }
                Node root1 = node1, root2 = node2;
                int depth1, depth2;
                rootAndDepth(root1, depth1);
                rootAndDepth(root2, depth2);

                if (root1 !is root2) with (dom.DocumentPosition)
                {
                    if (cast(void*)root1 < cast(void*)root2)
                        return Ret!disconnected | Ret!implementationSpecific | Ret!preceding;
                    else
                        return Ret!disconnected | Ret!implementationSpecific | Ret!following;
                }

                bool swapped = depth1 < depth2;
                if (swapped)
                {
                    import std.algorithm: swap;
                    swap(depth1, depth2);
                    swap(node1, node2);
                    swapped = true;
                }
                while (depth1-- > depth2)
                {
                    node1 = node1.parentNode;
                }
                if (node1 is node2) with (dom.DocumentPosition)
                {
                    if (swapped)
                        return Ret!contains | Ret!preceding;
                    else
                        return Ret!containedBy | Ret!following;
                }
                while(true)
                {
                    if (node1.parentNode is node2.parentNode)
                    {
                        while (node1.nextSibling)
                        {
                            node1 = node1.nextSibling;
                            if (node1 is node2)
                                return Ret!(dom.DocumentPosition.preceding);
                        }
                        return Ret!(dom.DocumentPosition.following);
                    }
                    node1 = node1.parentNode;
                    node2 = node2.parentNode;
                }
                assert(0, "Control flow should never reach this...\nPlease file an issue");
            }
        }
        private
        {
            dom.UserData[string] userData;
            dom.UserDataHandler[string] userDataHandlers;
            Node _previousSibling, _nextSibling, _parentNode;
            Document _ownerDocument;
            bool _readonly = false;

            // internal methods
            Element parentElement()
            {
                auto parent = parentNode;
                while (parent && parent.nodeType != dom.NodeType.element)
                    parent = parent.parentNode;
                return cast(Element)parent;
            }
            void performClone(Node dest, bool deep) @trusted
            {
                foreach (data; userDataHandlers.byKeyValue)
                {
                    auto value = data.value;
                    // putting data.value directly in the following line causes an error; should investigate further
                    value(dom.UserDataOperation.nodeCloned, new DOMString(data.key), userData[data.key], this, dest);
                }
            }
        }
        // method that must be overridden
        // just because otherwise it doesn't work [bugzilla 16318]
        abstract override DOMString nodeName();
        // methods specialized in NodeWithChildren
        override
        {
            @property ChildList childNodes()
            {
                static ChildList emptyList;
                if (!emptyList)
                {
                    emptyList = new ChildList();//allocator.multiVersionMake!ChildList(this);
                    emptyList.currentChild = firstChild;
                }
                return emptyList;
            }
            @property Node firstChild() { return null; }
            @property Node lastChild() { return null; }
           
            Node insertBefore(dom.Node _newChild, dom.Node _refChild)
            {
                throw new DOMException(dom.ExceptionCode.hierarchyRequest);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.hierarchyRequest);
            }
            
            Node replaceChild(dom.Node newChild, dom.Node oldChild)
            {
                throw new DOMException(dom.ExceptionCode.hierarchyRequest);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.hierarchyRequest);
            }
            
            Node removeChild(dom.Node oldChild)
            {
                throw new DOMException(dom.ExceptionCode.notFound);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.notFound);
            }
            
            Node appendChild(dom.Node newChild)
            {
                throw new DOMException(dom.ExceptionCode.hierarchyRequest);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.hierarchyRequest);
            }
            
            bool hasChildNodes() const { return false; }
        }
        // methods specialized in Element
        override
        {
            @property Element.Map attributes() { return null; }
            bool hasAttributes() { return false; }
        }
        // methods specialized in various subclasses
        override
        {
            @property DOMString nodeValue() { return null; }
            @property void nodeValue(DOMString) {}
            @property DOMString textContent() { return null; }
            @property void textContent(DOMString) {}
            @property DOMString baseURI()
            {
                if (parentNode)
                    return parentNode.baseURI;
                return null;
            }

            Node cloneNode(bool deep) { return null; }
        }
        // methods specialized in Element and Attribute
        override
        {
            @property DOMString localName() { return null; }
            @property DOMString prefix() { return null; }
            @property void prefix(DOMString) { }
            @property DOMString namespaceURI() { return null; }
        }
        // methods specialized in Document, Element and Attribute
        override
        {
            DOMString lookupPrefix(DOMString namespaceURI)
            {
                if (!namespaceURI)
                    return null;

                switch (nodeType) with (dom.NodeType)
                {
                    case entity:
                    case notation:
                    case documentFragment:
                    case documentType:
                        return null;
                    case attribute:
                        Attr attr = cast(Attr)this;
                        if (attr.ownerElement)
                            return attr.ownerElement.lookupNamespacePrefix(namespaceURI, attr.ownerElement);
                        return null;
                    default:
                        auto parentElement = parentElement();
                        if (parentElement)
                            return parentElement.lookupNamespacePrefix(namespaceURI, parentElement);
                        return null;
                }
            }
            DOMString lookupNamespaceURI(DOMString prefix)
            {
                switch (nodeType) with (dom.NodeType)
                {
                    case entity:
                    case notation:
                    case documentType:
                    case documentFragment:
                        return null;
                    case attribute:
                        auto attr = cast(Attr)this;
                        if (attr.ownerElement)
                            return attr.ownerElement.lookupNamespaceURI(prefix);
                        return null;
                    default:
                        auto parentElement = parentElement();
                        if (parentElement)
                            return parentElement.lookupNamespaceURI(prefix);

                        return null;
                }
            }
            bool isDefaultNamespace(DOMString namespaceURI)
            {
                switch (nodeType) with (dom.NodeType)
                {
                    case entity:
                    case notation:
                    case documentType:
                    case documentFragment:
                        return false;
                    case attribute:
                        auto attr = cast(Attr)this;
                        if (attr.ownerElement)
                            return attr.ownerElement.isDefaultNamespace(namespaceURI);
                        return false;
                    default:
                        auto parentElement = parentElement();
                        if (parentElement)
                            return parentElement.isDefaultNamespace(namespaceURI);
                        return false;
                }
            }
        }
        // TODO methods
        override
        {
            void normalize() {}
        }
        // inner class for use in NodeWithChildren
        class ChildList : dom.NodeList
        {
            private Node currentChild;
            package this() {

            }
            // methods specific to NodeList
            override
            {
                Node item(size_t index)
                {
                    auto result = rebindable(this.outer.firstChild);
                    for (size_t i = 0; i < index && result !is null; i++)
                    {
                        result = result.nextSibling;
                    }
                    return result;
                }
                @property size_t length()
                {
                    auto child = rebindable(this.outer.firstChild);
                    size_t result = 0;
                    while (child)
                    {
                        result++;
                        child = child.nextSibling;
                    }
                    return result;
                }
            }
            // more idiomatic methods
            auto opIndex(size_t i)
            {
                return item(i);
            }
            // range interface
            auto front() { return currentChild; }
            void popFront() { currentChild = currentChild.nextSibling; }
            bool empty() { return currentChild is null; }
        }
        // method not required by the spec, specialized in NodeWithChildren
        bool isAncestor(Node other) { return false; }
        /++
        +   `true` if and only if this node is _readonly.
        +
        +   The DOM specification defines a _readonly node as "a node that is immutable.
        +   This means its list of children, its content, and its attributes, when it is
        +   an element, cannot be changed in any way. However, a read only node can
        +   possibly be moved, when it is not itself contained in a read only node."
        +
        +   For example, `Notation`s, `EntityReference`s and all of theirs descendants
        +   are always readonly.
        +/
        // method not required by the spec, specialized in varous subclasses
        @property bool readonly() { return _readonly; }
    }
    private abstract class NodeWithChildren : Node
    {
        package this() {

        }
        override
        {
            @property ChildList childNodes()
            {
                ChildList res = new ChildList();//allocator.multiVersionMake!ChildList(this);
                res.currentChild = firstChild;
                return res;
            }
            @property Node firstChild()
            {
                return _firstChild;
            }
            @property Node lastChild()
            {
                return _lastChild;
            }

            Node insertBefore(dom.Node _newChild, dom.Node _refChild)
            {
                enforce!DOMException(!readonly, dom.ExceptionCode.noModificationAllowed);
                if (!_refChild)
                    return appendChild(_newChild);

                Node newChild = cast(Node)_newChild;
                Node refChild = cast(Node)_refChild;

                enforce!DOMException(!(!newChild || !refChild 
							|| newChild.ownerDocument !is ownerDocument)
                    , dom.ExceptionCode.wrongDocument); 
                enforce!DOMException(!(this is newChild || newChild.isAncestor(this) 
                            || newChild is refChild)
                    , dom.ExceptionCode.hierarchyRequest); 
                enforce!DOMException(!(refChild.parentNode !is this)
                    , dom.ExceptionCode.notFound); 
                enforce!DOMException(!(this is newChild || newChild.isAncestor(this) || newChild is refChild)
                    , dom.ExceptionCode.hierarchyRequest); 
                enforce!DOMException(!(refChild.parentNode !is this)
                    , dom.ExceptionCode.notFound); 

                if (newChild.nodeType == dom.NodeType.documentFragment)
                {
                    for (auto child = rebindable(newChild); child !is null; child = child.nextSibling)
                        insertBefore(child, refChild);
                    return newChild;
                }

                if (newChild.parentNode)
                    newChild.parentNode.removeChild(newChild);
                newChild._parentNode = this;
                if (refChild.previousSibling)
                {
                    refChild.previousSibling._nextSibling = newChild;
                    newChild._previousSibling = refChild.previousSibling;
                }
                refChild._previousSibling = newChild;
                newChild._nextSibling = refChild;
                if (firstChild is refChild)
                    _firstChild = newChild;
                return newChild;
            }
            Node replaceChild(dom.Node newChild, dom.Node oldChild)
            {
                insertBefore(newChild, oldChild);
                return removeChild(oldChild);
            }
            Node removeChild(dom.Node _oldChild)
            {
				enforce!DOMException(!readonly, dom.ExceptionCode.noModificationAllowed);
                Node oldChild = cast(Node)_oldChild;
                if (!oldChild || oldChild.parentNode !is this)
					enforce!DOMException(!(!oldChild 
								|| oldChild.parentNode !is this)
							, dom.ExceptionCode.noModificationAllowed);

                if (oldChild is firstChild)
                    _firstChild = oldChild.nextSibling;
                else
                    oldChild.previousSibling._nextSibling = oldChild.nextSibling;

                if (oldChild is lastChild)
                    _lastChild = oldChild.previousSibling;
                else
                    oldChild.nextSibling._previousSibling = oldChild.previousSibling;

                oldChild._parentNode = null;
                oldChild._previousSibling = null;
                oldChild._nextSibling = null;
                return oldChild;
            }
            Node appendChild(dom.Node _newChild)
            {
				enforce!DOMException(!readonly, dom.ExceptionCode.noModificationAllowed);
                Node newChild = cast(Node)_newChild;
				enforce!DOMException(!(!newChild || newChild.ownerDocument !is ownerDocument)
						, dom.ExceptionCode.wrongDocument);
				enforce!DOMException(!(this is newChild || newChild.isAncestor(this))
						, dom.ExceptionCode.hierarchyRequest);
                if (newChild.parentNode !is null)
                    newChild.parentNode.removeChild(newChild);

                if (newChild.nodeType == dom.NodeType.documentFragment)
                {
                    for (auto node = rebindable(newChild.firstChild); node !is null; node = node.nextSibling)
                        appendChild(node);
                    return newChild;
                }

                newChild._parentNode = this;
                if (lastChild)
                {
                    newChild._previousSibling = lastChild;
                    lastChild._nextSibling = newChild;
                }
                else
                    _firstChild = newChild;
                _lastChild = newChild;
                return newChild;
            }
            bool hasChildNodes() const
            {
                return _firstChild !is null;
            }
            bool isAncestor(Node other)
            {
                for (auto child = rebindable(firstChild); child !is null; child = child.nextSibling)
                {
                    if (child is other)
                        return true;
                    if (child.isAncestor(other))
                        return true;
                }
                return false;
            }

            @property DOMString textContent()
            {
                //import std.experimental.xml.appender;
                DOMString result;
                //auto result = Appender!(typeof(this.textContent()[0]), typeof(*allocator))(allocator);
                for (auto child = rebindable(firstChild); child !is null; child = child.nextSibling)
                {
                    if (child.nodeType != dom.NodeType.comment &&
                        child.nodeType != dom.NodeType.processingInstruction)
                    {
                        result ~= child.textContent();//result.put(child.textContent);
                    }
                }
                return result;
            }
            @property void textContent(DOMString newVal)
            {
				enforce!DOMException(readonly
						, dom.ExceptionCode.noModificationAllowed);

                while (firstChild)
                    removeChild(firstChild);

                _firstChild = _lastChild = ownerDocument.createTextNode(newVal);
            }
        }
        private
        {
            Node _firstChild, _lastChild;

            void performClone(NodeWithChildren dest, bool deep)
            {
                super.performClone(dest, deep);
                if (deep)
                    foreach (child; childNodes)
                    {
                        auto childClone = child.cloneNode(true);
                        dest.appendChild(childClone);
                    }
            }
        }
    }
    /// Implementation of $(LINK2 ../dom/DocumentFragment, `std.experimental.xml.dom.DocumentFragment`)
    class DocumentFragment : NodeWithChildren, dom.DocumentFragment 
    {
        package this() {

        }
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.documentFragment; }
            @property DOMString nodeName() { return new DOMString("#document-fragment"w); }
        }
    }
    /// Implementation of $(LINK2 ../dom/Document, `std.experimental.xml.dom.Document`)
    class Document : NodeWithChildren, dom.Document
    {
        package this() {

        }
        // specific to Document
        override
        {
            @property DocumentType doctype() { return _doctype; }
            @property DOMImplementation implementation() { return this.outer; }
            @property Element documentElement() { return _root; }

            Element createElement(DOMString tagName)
            {
                Element res = new Element(); //allocator.multiVersionMake!Element(this.outer);
                res._name = tagName;
                res._ownerDocument = this;
                res._attrs = res.createMap();//new Element.Map(); //allocator.multiVersionMake!(Element.Map)(res);
                return res;
            }
            Element createElementNS(DOMString namespaceURI, DOMString qualifiedName)
            {
                Element res = new Element();//allocator.multiVersionMake!Element(this.outer);
                res.setQualifiedName(qualifiedName);
                res._namespaceURI = namespaceURI;
                res._ownerDocument = this;
                res._attrs = res.createMap();//res._attrs = new Element.Map();//allocator.multiVersionMake!(Element.Map)(res);
                return res;
            }
            DocumentFragment createDocumentFragment()
            {
                DocumentFragment res = new DocumentFragment();//allocator.multiVersionMake!DocumentFragment(this.outer);
                res._ownerDocument = this;
                return res;
            }
            Text createTextNode(DOMString data)
            {
                Text res = new Text();//allocator.multiVersionMake!Text(this.outer);
                res._data = data;
                res._ownerDocument = this;
                return res;
            }
            Comment createComment(DOMString data)
            {
                Comment res = new Comment();//allocator.multiVersionMake!Comment(this.outer);
                res._data = data;
                res._ownerDocument = this;
                return res;
            }
            CDATASection createCDATASection(DOMString data)
            {
                CDATASection res = new CDATASection();//allocator.multiVersionMake!CDATASection(this.outer);
                res._data = data;
                res._ownerDocument = this;
                return res;
            }
            ProcessingInstruction createProcessingInstruction(DOMString target, DOMString data)
            {
                ProcessingInstruction res = new ProcessingInstruction();//allocator.multiVersionMake!ProcessingInstruction(this.outer);
                res._target = target;
                res._data = data;
                res._ownerDocument = this;
                return res;
            }
            Attr createAttribute(DOMString name)
            {
                Attr res = new Attr();//allocator.multiVersionMake!Attr(this.outer);
                res._name = name;
                res._ownerDocument = this;
                return res;
            }
            Attr createAttributeNS(DOMString namespaceURI, DOMString qualifiedName)
            {
                Attr res = new Attr();//allocator.multiVersionMake!Attr(this.outer);
                res.setQualifiedName(qualifiedName);
                res._namespaceURI = namespaceURI;
                res._ownerDocument = this;
                return res;
            }
            EntityReference createEntityReference(DOMString name) { return null; }

            ElementsByTagName getElementsByTagName(DOMString tagname)
            {
                ElementsByTagName res = new ElementsByTagName();//allocator.multiVersionMake!ElementsByTagName;
                res.root = this;
                res.tagname = tagname;
                res.current = res.item(0);
                return res;
            }
            ElementsByTagNameNS getElementsByTagNameNS(DOMString namespaceURI, DOMString localName)
            {
                ElementsByTagNameNS res = new ElementsByTagNameNS();//allocator.multiVersionMake!ElementsByTagNameNS;
                res.root = this;
                res.namespaceURI = namespaceURI;
                res.localName = localName;
                res.current = res.item(0);
                return res;
            }
            Element getElementById(DOMString elementId)
            {
                Element find(dom.Node node) @safe
                {
                    if (node.nodeType == dom.NodeType.element && node.hasAttributes)
                        foreach (attr; node.attributes)
                        {
                            if ((cast(Attr)attr).isId && attr.nodeValue == elementId)
                                return cast(Element)node;
                        }
                    foreach (child; node.childNodes)
                    {
                        auto res = find(child);
                        if (res)
                            return res;
                    }
                    return null;
                }
                return find(_root);
            }

            Node importNode(dom.Node node, bool deep)
            {
                switch (node.nodeType) with (dom.NodeType)
                {
                    case attribute:
                        Attr result;
                        if (node.prefix)
                            result = createAttributeNS(node.namespaceURI, node.nodeName);
                        else
                            result = createAttribute(node.nodeName);
                        auto children = node.childNodes;
                        foreach (i; 0..children.length)
                            result.appendChild(importNode(children.item(i), true));
                        return result;
                    case documentFragment:
                        auto result = createDocumentFragment();
                        if (deep)
                        {
                            auto children = node.childNodes;
                            foreach (i; 0..children.length)
                                result.appendChild(importNode(children.item(i), deep));
                        }
                        return result;
                    case element:
                        Element result;
                        if (node.prefix)
                            result = createElementNS(node.namespaceURI, node.nodeName);
                        else
                            result = createElement(node.nodeName);
                        if (node.hasAttributes)
                        {
                            auto attributes = node.attributes;
                            foreach (i; 0..attributes.length)
                            {
                                auto attr = cast(Attr)(importNode(attributes.item(i), deep));
                                assert(attr);
                                result.setAttributeNode(attr);
                            }
                        }
                        if (deep)
                        {
                            auto children = node.childNodes;
                            foreach (i; 0..children.length)
                                result.appendChild(importNode(children.item(i), true));
                        }
                        return result;
                    case processingInstruction:
                        return createProcessingInstruction(node.nodeName, node.nodeValue);
                    default:
                        throw new DOMException(dom.ExceptionCode.notSupported);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.notSupported);
                }
            }
            Node adoptNode(dom.Node source) { return null; }

            @property DOMString inputEncoding() { return null; }
            @property DOMString xmlEncoding() { return null; }

            @property bool xmlStandalone() { return _standalone; }
            @property void xmlStandalone(bool b) { _standalone = b; }

            @property DOMString xmlVersion() { return _xmlVersion; }
            @property void xmlVersion(DOMString ver)
            {
                if (ver == "1.0" || ver == "1.1")
                    _xmlVersion = ver;
                else
                    throw new DOMException(dom.ExceptionCode.notSupported);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.notSupported);
            }

            @property bool strictErrorChecking() { return _strictErrorChecking; }
            @property void strictErrorChecking(bool b) { _strictErrorChecking = b; }

            @property DOMString documentURI() { return _documentURI; }
            @property void documentURI(DOMString uri) { _documentURI = uri; }

            @property DOMConfiguration domConfig() { return _config; }
            void normalizeDocument() { }
            Node renameNode(dom.Node n, DOMString namespaceURI, DOMString qualifiedName)
            {
                auto node = cast(Node)n;
				enforce!DOMException(!(!node || node.ownerDocument !is this)
							, dom.ExceptionCode.wrongDocument);

                auto type = node.nodeType;
				enforce!DOMException(!(type != dom.NodeType.element 
							&& type != dom.NodeType.attribute)
						, dom.ExceptionCode.notSupported);

                auto withNs = (cast(NodeWithNamespace)node);
                withNs.setQualifiedName(qualifiedName);
                withNs._namespaceURI = namespaceURI;
                return node;
            }
        }
        private
        {
            DOMString _documentURI, _xmlVersion = new DOMString("1.0"w);
            DocumentType _doctype;
            Element _root;
            DOMConfiguration _config;
            bool _strictErrorChecking = true, _standalone = false;
        }
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.document; }
            @property DOMString nodeName() { return new DOMString("#document"w); }

            DOMString lookupPrefix(DOMString namespaceURI)
            {
                return documentElement.lookupPrefix(namespaceURI);
            }
            DOMString lookupNamespaceURI(DOMString prefix)
            {
                return documentElement.lookupNamespaceURI(prefix);
            }
            bool isDefaultNamespace(DOMString namespaceURI)
            {
                return documentElement.isDefaultNamespace(namespaceURI);
            }
        }
        // inherited from NodeWithChildren
        override
        {
            Node insertBefore(dom.Node newChild, dom.Node refChild)
            {
                if (newChild.nodeType == dom.NodeType.element)
                {
                    enforce!DOMException(!_root
							, dom.ExceptionCode.hierarchyRequest);

                    auto res = super.insertBefore(newChild, refChild);
                    _root = cast(Element)newChild;
                    return res;
                }
                else if (newChild.nodeType == dom.NodeType.documentType)
                {
                    enforce!DOMException(!_doctype
							, dom.ExceptionCode.hierarchyRequest);

                    auto res = super.insertBefore(newChild, refChild);
                    _doctype = cast(DocumentType)newChild;
                    return res;
                }
                else if (newChild.nodeType != dom.NodeType.comment &&
                         newChild.nodeType != dom.NodeType.processingInstruction)
                    throw new DOMException(dom.ExceptionCode.hierarchyRequest);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.hierarchyRequest);
                else
                    return super.insertBefore(newChild, refChild);
            }
            Node replaceChild(dom.Node newChild, dom.Node oldChild)
            {
                if (newChild.nodeType == dom.NodeType.element)
                {
                    enforce!DOMException(!(oldChild !is _root)
                        , dom.ExceptionCode.hierarchyRequest);

                    auto res = super.replaceChild(newChild, oldChild);
                    _root = cast(Element)newChild;
                    return res;
                }
                else if (newChild.nodeType == dom.NodeType.documentType)
                {
                    enforce!DOMException(!(oldChild !is _doctype)
                        , dom.ExceptionCode.hierarchyRequest);

                    auto res = super.replaceChild(newChild, oldChild);
                    _doctype = cast(DocumentType)newChild;
                    return res;
                }
                else if (newChild.nodeType != dom.NodeType.comment &&
                         newChild.nodeType != dom.NodeType.processingInstruction)
                    throw new DOMException(dom.ExceptionCode.hierarchyRequest);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.hierarchyRequest);
                else
                    return super.replaceChild(newChild, oldChild);
            }
            Node removeChild(dom.Node oldChild)
            {
                if (oldChild.nodeType == dom.NodeType.element)
                {
                    auto res = super.removeChild(oldChild);
                    _root = null;
                    return res;
                }
                else if (oldChild.nodeType == dom.NodeType.documentType)
                {
                    auto res = super.removeChild(oldChild);
                    _doctype = null;
                    return res;
                }
                else
                    return super.removeChild(oldChild);
            }
            Node appendChild(dom.Node newChild)
            {
                if (newChild.nodeType == dom.NodeType.element)
                {
                    enforce!DOMException(!(_root)
                        , dom.ExceptionCode.hierarchyRequest);

                    auto res = super.appendChild(newChild);
                    _root = cast(Element)newChild;
                    return res;
                }
                else if (newChild.nodeType == dom.NodeType.documentType)
                {
                    enforce!DOMException(!(_doctype)
                        , dom.ExceptionCode.hierarchyRequest);

                    auto res = super.appendChild(newChild);
                    _doctype = cast(DocumentType)newChild;
                    return res;
                }
                else
                    return super.appendChild(newChild);
            }
        }
    }
    alias ElementsByTagName = ElementsByTagNameImpl!false;
    alias ElementsByTagNameNS = ElementsByTagNameImpl!true;
    static class ElementsByTagNameImpl(bool ns) : dom.NodeList
    {
        package this() {

        }
        private Node root;
        private Element current;
        static if (ns)
            private DOMString namespaceURI, localName;
        else
            private DOMString tagname;

        private bool check(Node node)
        {
            static if (ns)
            {
                if (node.nodeType == dom.NodeType.element)
                {
                    Element elem = cast(Element)node;
                    return elem.namespaceURI == namespaceURI && elem.localName == localName;
                }
                else
                    return false;
            }
            else
                return node.nodeType == dom.NodeType.element && node.nodeName == tagname;
        }

        private Element findNext(Node node)
        {
            if (node.firstChild)
            {
                auto item = node.firstChild;
                if (check(item))
                    return cast(Element)item;
                else
                    return findNext(item);
            }
            else
                return findNextBack(node);
        }
        private Element findNextBack(Node node)
        {
            if (node.nextSibling)
            {
                auto item = node.nextSibling;

                if (check(item))
                    return cast(Element)item;
                else
                    return findNext(item);
            }
            else if (node.parentNode && node.parentNode !is node.ownerDocument)
                return findNextBack(node.parentNode);
            else
                return null;
        }

        // methods specific to NodeList
        override
        {
            @property size_t length()
            {
                size_t res = 0;
                auto node = findNext(root);
                while (node !is null)
                {
                    //writeln("Found node ", node.nodeName);
                    res++;
                    node = findNext(node);
                }
                return res;
            }
            Element item(size_t i)
            {
                auto res = findNext(root);
                while (res && i > 0)
                {
                    res = findNext(res);
                    i--;
                }
                return res;
            }
        }
        // more idiomatic methods
        auto opIndex(size_t i) { return item(i); }

        // range interface
        bool empty() { return current is null; }
        void popFront() { current = findNext(current); }
        auto front() { return current; }
    }
    /// Implementation of $(LINK2 ../dom/CharacterData, `std.experimental.xml.dom.CharacterData`)
    abstract class CharacterData : Node, dom.CharacterData
    {
        // specific to CharacterData
        override
        {
            @property DOMString data() { return _data; }
            @property void data(DOMString newVal) { _data = newVal; }
            @property size_t length() { return _data.length; }

            DOMString substringData(size_t offset, size_t count)
            {
                enforce!DOMException(!(offset > length)
                    , dom.ExceptionCode.indexSize);

                import std.algorithm : min;
                return _data[offset..min(offset + count, length)];
            }
            void appendData(DOMString arg)
            {
                import std.traits : Unqual;

                //auto newData = allocator.makeArray!(Unqual!(typeof(_data[0])))(_data.length + arg.length);

                _data ~= arg;
            }
            void insertData(size_t offset, DOMString arg)
            {
                import std.traits : Unqual;

                enforce!DOMException(!(offset > length)
                    , dom.ExceptionCode.indexSize);

                //auto newData = allocator.makeArray!(Unqual!(typeof(_data[0])))(_data.length + arg.length);
                /+CharType[] newData;
                newData.reserve = _data.length + arg.length;
                newData = _data[0 .. offset];
                newData[offset .. (offset + arg.length)] = arg;
                newData[(offset + arg.length) .. $] = _data[offset .. $];

                _data = cast(typeof(_data))newData;+/
                _data.insertData(offset, arg);
            }
            void deleteData(size_t offset, size_t count)
            {
                _data.deleteData(offset, count);
            }
            void replaceData(size_t offset, size_t count, DOMString arg)
            {
                _data.deleteData(offset, count);
                _data.insertData(offset, arg);
            }
        }
        // inherited from Node
        override
        {
            @property DOMString nodeValue() { return data; }
            @property void nodeValue(DOMString newVal)
            {
                enforce!DOMException(!(readonly)
                    , dom.ExceptionCode.noModificationAllowed);
                data = newVal;
            }
            @property DOMString textContent() { return data; }
            @property void textContent(DOMString newVal)
            {
                enforce!DOMException(!(readonly)
                    , dom.ExceptionCode.noModificationAllowed);
                data = newVal;
            }
        }
        private
        {
            DOMString _data;

            // internal method
            void performClone(CharacterData dest, bool deep)
            {
                super.performClone(dest, deep);
                dest._data = _data;
            }
        }
    }
    private abstract class NodeWithNamespace : NodeWithChildren
    {
        private
        {
            DOMString _name, _namespaceURI;
            size_t _colon;

            void setQualifiedName(DOMString name)
            {
                _name = name;
                ptrdiff_t i = name.getDString.indexOf(':');
                if (i > 0)
                    _colon = i;
            }
            void performClone(NodeWithNamespace dest, bool deep)
            {
                super.performClone(dest, deep);
                dest._name = _name;
                dest._namespaceURI = namespaceURI;
                dest._colon = _colon;
            }
        }
        // inherited from Node
        override
        {
            @property DOMString nodeName() { return _name; }

            @property DOMString localName()
            {
                if (!_colon)
                    return null;
                return _name[(_colon+1)..$];
            }
            @property DOMString prefix()
            {
                return _name[0.._colon];
            }
            @property void prefix(DOMString pre)
            {
                enforce!DOMException(!(readonly)
                    , dom.ExceptionCode.noModificationAllowed);

                import std.traits : Unqual;

                /+auto newName = allocator.makeArray!(Unqual!(typeof(_name[0])))(pre.length + localName.length + 1);
                newName[0 .. pre.length] = pre[];
                newName[pre.length] = ':';
                newName[(pre.length + 1) .. $] = localName[];+/

                //_name = pre ~ ":" ~ localName;
                _name ~= pre;
                _name ~= "w";
                _name ~= localName;
                _colon = pre.length;
            }
            @property DOMString namespaceURI() { return _namespaceURI; }
        }
    }
    /// Implementation of $(LINK2 ../dom/Attr, `std.experimental.xml.dom.Attr`)
    class Attr : NodeWithNamespace, dom.Attr
    {
        package this() {

        }
        // specific to Attr
        override
        {
            /// Implementation of $(LINK2 ../dom/Attr.name, `std.experimental.xml.dom.Attr.name`).
            @property DOMString name() { return _name; }
            /// Implementation of $(LINK2 ../dom/Attr.specified, `std.experimental.xml.dom.Attr.specified`).
            @property bool specified() { return _specified; }
            /// Implementation of $(LINK2 ../dom/Attr.value, `std.experimental.xml.dom.Attr.value`).
            @property DOMString value()
            {

                //auto result = Appender!(typeof(_name[0]), typeof(*allocator))(allocator);
                DOMString result = new DOMString();
                auto child = rebindable(firstChild);
                while (child)
                {
                    result ~= child.textContent;//result.put(child.textContent);
                    child = child.nextSibling;
                }
                return result;
            }
            /// ditto
            @property void value(DOMString newVal)
            {
                while (firstChild)
                    removeChild(firstChild);
                appendChild(ownerDocument.createTextNode(newVal));
            }

            /// Implementation of $(LINK2 ../dom/Attr.ownerElement, `std.experimental.xml.dom.Attr.ownerElement`).
            @property Element ownerElement() { return _ownerElement; }
            /// Implementation of $(LINK2 ../dom/Attr.schemaTypeInfo, `std.experimental.xml.dom.Attr.schemaTypeInfo`).
            @property dom.XMLTypeInfo schemaTypeInfo() { return null; }
            /// Implementation of $(LINK2 ../dom/Attr.isId, `std.experimental.xml.dom.Attr.isId`).
            @property bool isId() { return _isId; }
        }
        private
        {
            Element _ownerElement;
            bool _specified = true, _isId = false;
            @property Attr _nextAttr() { return cast(Attr)_nextSibling; }
            @property Attr _previousAttr() { return cast(Attr)_previousSibling; }
        }
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.attribute; }

            @property DOMString nodeValue() { return value; }
            @property void nodeValue(DOMString newVal)
            {
                enforce!DOMException(!(readonly)
                    , dom.ExceptionCode.noModificationAllowed);
                value = newVal;
            }

            // overridden because we reuse _nextSibling and _previousSibling with another meaning
            @property Attr nextSibling() { return null; }
            @property Attr previousSibling() { return null; }

            Attr cloneNode(bool deep)
            {
                Attr cloned = new Attr();//allocator.multiVersionMake!Attr(this.outer);
                cloned._ownerDocument = _ownerDocument;
                super.performClone(cloned, true);
                cloned._specified = true;
                return cloned;
            }

            DOMString lookupPrefix(DOMString namespaceURI)
            {
                if (ownerElement)
                    return ownerElement.lookupPrefix(namespaceURI);
                return null;
            }
            DOMString lookupNamespaceURI(DOMString prefix)
            {
                if (ownerElement)
                    return ownerElement.lookupNamespaceURI(prefix);
                return null;
            }
            bool isDefaultNamespace(DOMString namespaceURI)
            {
                if (ownerElement)
                    return ownerElement.isDefaultNamespace(namespaceURI);
                return false;
            }
        }
    }
    /// Implementation of $(LINK2 ../dom/Element, `std.experimental.xml.dom.Element`)
    class Element : NodeWithNamespace, dom.Element
    {
        package this() {

        }
        ///Created as a workaround to a common D compiler bug/artifact.
        package Map createMap() {
            return new Map();
        }
        // specific to Element
        override
        {
            /// Implementation of $(LINK2 ../dom/Element.tagName, `std.experimental.xml.dom.Element.tagName`).
            @property DOMString tagName() { return _name; }

            /++
            +   Implementation of $(LINK2 ../dom/Element.getAttribute,
            +   `std.experimental.xml.dom.Element.getAttribute`).
            +/
            DOMString getAttribute(DOMString name)
            {
                return _attrs.getNamedItem(name).value;
            }
            /++
            +   Implementation of $(LINK2 ../dom/Element.setAttribute,
            +   `std.experimental.xml.dom.Element.setAttribute`).
            +/
            void setAttribute(DOMString name, DOMString value)
            {
                auto attr = ownerDocument.createAttribute(name);
                attr.nodeValue = value;
                attr._ownerElement = this;
                _attrs.setNamedItem(attr);
            }
            /++
            +   Implementation of $(LINK2 ../dom/Element.removeAttribute,
            +   `std.experimental.xml.dom.Element.removeAttribute`).
            +/
            void removeAttribute(DOMString name)
            {
                _attrs.removeNamedItem(name);
            }

            /++
            +   Implementation of $(LINK2 ../dom/Element.getAttributeNode,
            +   `std.experimental.xml.dom.Element.getAttributeNode`).
            +/
            Attr getAttributeNode(DOMString name)
            {
                return _attrs.getNamedItem(name);
            }
            /++
            +   Implementation of $(LINK2 ../dom/Element.setAttributeNode,
            +   `std.experimental.xml.dom.Element.setAttributeNode`).
            +/
            Attr setAttributeNode(dom.Attr newAttr)
            {
                return _attrs.setNamedItem(newAttr);
            }
            /++
            +   Implementation of $(LINK2 ../dom/Element.removeAttributeNode,
            +   `std.experimental.xml.dom.Element.removeAttributeNode`).
            +/
            Attr removeAttributeNode(dom.Attr oldAttr)
            {
                if (_attrs.getNamedItemNS(oldAttr.namespaceURI, oldAttr.name) is oldAttr)
                    return _attrs.removeNamedItemNS(oldAttr.namespaceURI, oldAttr.name);
                else if (_attrs.getNamedItem(oldAttr.name) is oldAttr)
                    return _attrs.removeNamedItem(oldAttr.name);

                throw new DOMException(dom.ExceptionCode.notFound);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.notFound);
            }

            /++
            +   Implementation of $(LINK2 ../dom/Element.getAttributeNS,
            +   `std.experimental.xml.dom.Element.getAttributeNS`).
            +/
            DOMString getAttributeNS(DOMString namespaceURI, DOMString localName)
            {
                return _attrs.getNamedItemNS(namespaceURI, localName).value;
            }
            /++
            +   Implementation of $(LINK2 ../dom/Element.setAttributeNS,
            +   `std.experimental.xml.dom.Element.setAttributeNS`).
            +/
            void setAttributeNS(DOMString namespaceURI, DOMString qualifiedName, DOMString value)
            {
                auto attr = ownerDocument.createAttributeNS(namespaceURI, qualifiedName);
                attr.nodeValue = value;
                attr._ownerElement = this;
                _attrs.setNamedItem(attr);
            }
            /++
            +   Implementation of $(LINK2 ../dom/Element.removeAttributeNS,
            +   `std.experimental.xml.dom.Element.removeAttributeNS`).
            +/
            void removeAttributeNS(DOMString namespaceURI, DOMString localName)
            {
                _attrs.removeNamedItemNS(namespaceURI, localName);
            }

            /++
            +   Implementation of $(LINK2 ../dom/Element.getAttributeNodeNS,
            +   `std.experimental.xml.dom.Element.getAttributeNodeNS`).
            +/
            Attr getAttributeNodeNS(DOMString namespaceURI, DOMString localName)
            {
                return _attrs.getNamedItemNS(namespaceURI, localName);
            }
            /++
            +   Implementation of $(LINK2 ../dom/Element.setAttributeNodeNS,
            +   `std.experimental.xml.dom.Element.setAttributeNodeNS`).
            +/
            Attr setAttributeNodeNS(dom.Attr newAttr)
            {
                return _attrs.setNamedItemNS(newAttr);
            }

            /++
            +   Implementation of $(LINK2 ../dom/Element.hasAttribute,
            +   `std.experimental.xml.dom.Element.hasAttribute`).
            +/
            bool hasAttribute(DOMString name)
            {
                return _attrs.getNamedItem(name) !is null;
            }
            /++
            +   Implementation of $(LINK2 ../dom/Element.hasAttributeNS,
            +   `std.experimental.xml.dom.Element.hasAttributeNS`).
            +/
            bool hasAttributeNS(DOMString namespaceURI, DOMString localName)
            {
                return _attrs.getNamedItemNS(namespaceURI, localName) !is null;
            }

            /++
            +   Implementation of $(LINK2 ../dom/Element.setIdAttribute,
            +   `std.experimental.xml.dom.Element.setIdAttribute`).
            +/
            void setIdAttribute(DOMString name, bool isId)
            {
                auto attr = _attrs.getNamedItem(name);
                if (attr)
                    attr._isId = isId;
                else
                    throw new DOMException(dom.ExceptionCode.notFound);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.notFound);
            }
            /++
            +   Implementation of $(LINK2 ../dom/Element.setIdAttributeNS,
            +   `std.experimental.xml.dom.Element.setIdAttributeNS`).
            +/
            void setIdAttributeNS(DOMString namespaceURI, DOMString localName, bool isId)
            {
                auto attr = _attrs.getNamedItemNS(namespaceURI, localName);
                if (attr)
                    attr._isId = isId;
                else
                    throw new DOMException(dom.ExceptionCode.notFound);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.notFound);
            }
            /++
            +   Implementation of $(LINK2 ../dom/Element.getAttribute,
            +   `std.experimental.xml.dom.Element.getAttribute`).
            +/
            void setIdAttributeNode(dom.Attr idAttr, bool isId)
            {
                if (_attrs.getNamedItemNS(idAttr.namespaceURI, idAttr.name) is idAttr)
                    (cast(Attr)idAttr)._isId = isId;
                else if (_attrs.getNamedItem(idAttr.name) is idAttr)
                    (cast(Attr)idAttr)._isId = isId;
                else
                    throw new DOMException(dom.ExceptionCode.notFound);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.notFound);
            }

            /++
            +   Implementation of $(LINK2 ../dom/Element.getElementsByTagName,
            +   `std.experimental.xml.dom.Element.getElementsByTagName`).
            +/
            ElementsByTagName getElementsByTagName(DOMString tagname)
            {
                ElementsByTagName res = new ElementsByTagName();//allocator.multiVersionMake!ElementsByTagName;
                res.root = this;
                res.tagname = tagname;
                res.current = res.item(0);
                return res;
            }
            /++
            +   Implementation of $(LINK2 ../dom/Element.getElementsByTagNameNS,
            +   `std.experimental.xml.dom.Element.getElementsByTagNameNS`).
            +/
            ElementsByTagNameNS getElementsByTagNameNS(DOMString namespaceURI, DOMString localName)
            {
                ElementsByTagNameNS res = new ElementsByTagNameNS();//allocator.multiVersionMake!ElementsByTagNameNS;
                res.root = this;
                res.namespaceURI = namespaceURI;
                res.localName = localName;
                res.current = res.item(0);
                return res;
            }

            /++
            +   Implementation of $(LINK2 ../dom/Element.schemaTypeInfo,
            +   `std.experimental.xml.dom.Element.schemaTypeInfo`).
            +/
            @property dom.XMLTypeInfo schemaTypeInfo() { return null; }
        }
        private
        {
            Map _attrs;

            // internal methods
            DOMString lookupNamespacePrefix(DOMString namespaceURI, Element originalElement)
            {
                if (this.namespaceURI && this.namespaceURI == namespaceURI
                    && this.prefix && originalElement.lookupNamespaceURI(this.prefix) == namespaceURI)
                {
                    return this.prefix;
                }
                if (hasAttributes)
                    foreach (attr; attributes)
                        if (attr.prefix == "xmlns" && attr.nodeValue == namespaceURI &&
                            originalElement.lookupNamespaceURI(attr.localName) == namespaceURI)
                        {
                            return attr.localName;
                        }
                auto parentElement = parentElement();
                if (parentElement)
                    return parentElement.lookupNamespacePrefix(namespaceURI, originalElement);
                return null;
            }
        }
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.element; }

            @property Map attributes() { return _attrs.length > 0 ? _attrs : null; }
            bool hasAttributes() { return _attrs.length > 0; }

            Element cloneNode(bool deep)
            {
                Element cloned = new Element();//allocator.multiVersionMake!Element(this.outer);
                cloned._ownerDocument = ownerDocument;
                cloned._attrs = new Map();//allocator.multiVersionMake!Map(this);
                super.performClone(cloned, deep);
                return cloned;
            }

            DOMString lookupPrefix(DOMString namespaceURI)
            {
                return lookupNamespacePrefix(namespaceURI, this);
            }
            DOMString lookupNamespaceURI(DOMString prefix)
            {
                if (namespaceURI && prefix == prefix)
                    return namespaceURI;

                if (hasAttributes)
                {
                    foreach (attr; attributes)
                        if (attr.prefix == "xmlns" && attr.localName == prefix)
                            return attr.nodeValue;
                        else if (attr.nodeName == "xmlns" && !prefix)
                            return attr.nodeValue;
                }
                auto parentElement = parentElement();
                if (parentElement)
                    return parentElement.lookupNamespaceURI(prefix);
                return null;
            }
            bool isDefaultNamespace(DOMString namespaceURI)
            {
                if (!prefix)
                    return this.namespaceURI == namespaceURI;
                if (hasAttributes)
                {
                    foreach (attr; attributes)
                        if (attr.nodeName == "xmlns")
                            return attr.nodeValue == namespaceURI;
                }
                auto parentElement = parentElement();
                if (parentElement)
                    return parentElement.isDefaultNamespace(namespaceURI);
                return false;
            }
        }

        class Map : dom.NamedNodeMap
        {
            package this() {

            }
            // specific to NamedNodeMap
            public override
            {
                size_t length()
                {
                    size_t res = 0;
                    auto attr = firstAttr;
                    while (attr)
                    {
                        res++;
                        attr = attr._nextAttr;
                    }
                    return res;
                }
                Attr item(size_t index)
                {
                    size_t count = 0;
                    auto res = firstAttr;
                    while (res && count < index)
                    {
                        count++;
                        res = res._nextAttr;
                    }
                    return res;
                }

                Attr getNamedItem(DOMString name)
                {
                    auto res = firstAttr;
                    while (res && res.nodeName != name)
                        res = res._nextAttr;
                    return res;
                }
                Attr setNamedItem(dom.Node arg)
                {
                    enforce!DOMException(!(arg.ownerDocument !is this.outer.ownerDocument)
                        , dom.ExceptionCode.wrongDocument);

                    Attr attr = cast(Attr)arg;
                    enforce!DOMException(!(!attr)
                        , dom.ExceptionCode.hierarchyRequest);

                    if (attr._previousAttr)
                        attr._previousAttr._nextSibling = attr._nextAttr;
                    if (attr._nextAttr)
                        attr._nextAttr._previousSibling = attr._previousAttr;

                    auto res = firstAttr;
                    while (res && res.nodeName != attr.nodeName)
                        res = res._nextAttr;

                    if (res)
                    {
                        attr._previousSibling = res._previousAttr;
                        attr._nextSibling = res._nextAttr;
                        if (res is firstAttr) firstAttr = attr;
                    }
                    else
                    {
                        attr._nextSibling = firstAttr;
                        firstAttr = attr;
                        attr._previousSibling = null;
                        currentAttr = firstAttr;
                    }

                    return res;
                }
                Attr removeNamedItem(DOMString name)
                {
                    auto res = firstAttr;
                    while (res && res.nodeName != name)
                        res = res._nextAttr;

                    if (res)
                    {
                        if (res._previousAttr)
                            res._previousAttr._nextSibling = res._nextAttr;
                        if (res._nextAttr)
                            res._nextAttr._previousSibling = res._previousAttr;
                        return res;
                    }
                    else
                        throw new DOMException(dom.ExceptionCode.notFound);//allocator.multiVersionMake!DOMException(this.outer.outer, dom.ExceptionCode.notFound);
                }

                Attr getNamedItemNS(DOMString namespaceURI, DOMString localName)
                {
                    auto res = firstAttr;
                    while (res && (res.localName != localName || res.namespaceURI != namespaceURI))
                        res = res._nextAttr;
                    return res;
                }
                Attr setNamedItemNS(dom.Node arg)
                {
                    enforce!DOMException(!(arg.ownerDocument !is this.outer.ownerDocument)
                        , dom.ExceptionCode.wrongDocument);

                    Attr attr = cast(Attr)arg;
                    enforce!DOMException(!(!attr)
                        , dom.ExceptionCode.hierarchyRequest);

                    if (attr._previousAttr)
                        attr._previousAttr._nextSibling = attr._nextAttr;
                    if (attr._nextAttr)
                        attr._nextAttr._previousSibling = attr._previousAttr;

                    auto res = firstAttr;
                    while (res && (res.localName != attr.localName || res.namespaceURI != attr.namespaceURI))
                        res = res._nextAttr;

                    if (res)
                    {
                        attr._previousSibling = res._previousAttr;
                        attr._nextSibling = res._nextAttr;
                        if (res is firstAttr) firstAttr = attr;
                    }
                    else
                    {
                        attr._nextSibling = firstAttr;
                        firstAttr = attr;
                        attr._previousSibling = null;
                        currentAttr = firstAttr;
                    }

                    return res;
                }
                Attr removeNamedItemNS(DOMString namespaceURI, DOMString localName)
                {
                    auto res = firstAttr;
                    while (res && (res.localName != localName || res.namespaceURI != namespaceURI))
                        res = res._nextAttr;

                    if (res)
                    {
                        if (res._previousAttr)
                            res._previousAttr._nextSibling = res._nextAttr;
                        if (res._nextAttr)
                            res._nextAttr._previousSibling = res._previousAttr;
                        return res;
                    }
                    else
                        throw new DOMException(dom.ExceptionCode.notFound);//allocator.multiVersionMake!DOMException(this.outer.outer, dom.ExceptionCode.notFound);
                }
            }
            private
            {
                Attr firstAttr;
                Attr currentAttr;
            }
            // better methods
            auto opIndex(size_t i) { return item(i); }

            // range interface
            /+auto opSlice()
            {
                struct Range
                {
                    Attr currentAttr;

                    auto front() { return currentAttr; }
                    void popFront() { currentAttr = currentAttr._nextAttr; }
                    bool empty() { return currentAttr is null; }
                }
                return Range(firstAttr);
            }+/
        }
    }
    /// Implementation of $(LINK2 ../dom/Text, `std.experimental.xml.dom.Text`)
    class Text: CharacterData, dom.Text
    {
        package this() {

        }
        // specific to Text
        override
        {
            /// Implementation of $(LINK2 ../dom/Text.splitText, `std.experimental.xml.dom.Text.splitText`).
            Text splitText(size_t offset)
            {
                enforce!DOMException(!(offset > data.length)
                    , dom.ExceptionCode.indexSize);
                auto second = ownerDocument.createTextNode(data[offset..$]);
                data = data[0..offset];
                if (parentNode)
                {
                    if (nextSibling)
                        parentNode.insertBefore(second, nextSibling);
                    else
                        parentNode.appendChild(second);
                }
                return second;
            }
            /++
            +   Implementation of $(LINK2 ../dom/Text.isElementContentWhitespace,
            +   `std.experimental.xml.dom.Text.isElementContentWhitespace`).
            +/
            @property bool isElementContentWhitespace()
            {
                return _data.getDString.indexOfNeither(" \r\n\t") == -1;
            }
            /// Implementation of $(LINK2 ../dom/Text.wholeText, `std.experimental.xml.dom.Text.wholeText`).
            @property DOMString wholeText()
            {
                Text findPreviousText(Text text)
                {
                    Node node = text;
                    do
                    {
                        if (node.previousSibling)
                            switch (node.previousSibling.nodeType) with (dom.NodeType)
                            {
                                case text:
                                case cdataSection:
                                    return cast(Text) node.previousSibling;
                                case entityReference:
                                    if (cast(Text)(node.previousSibling.lastChild))
                                        return cast(Text) node.previousSibling.lastChild;
                                    else
                                        return null;
                                default:
                                    return null;
                            }
                        node = node.parentNode;
                    }
                    while (node && node.nodeType == dom.NodeType.entityReference);
                    return null;
                }
                Text findNextText(Text text)
                {
                    Node node = text;
                    do
                    {
                        if (node.nextSibling)
                            switch (node.nextSibling.nodeType) with (dom.NodeType)
                            {
                                case text:
                                case cdataSection:
                                    return cast(Text) node.nextSibling;
                                case entityReference:
                                    if (cast(Text)(node.nextSibling.firstChild))
                                        return cast(Text) node.nextSibling.firstChild;
                                    else
                                        return null;
                                default:
                                    return null;
                            }
                        node = node.parentNode;
                    }
                    while (node && node.nodeType == dom.NodeType.entityReference);
                    return null;
                }

                //import std.experimental.xml.appender;
                DOMString result;//auto result = Appender!(typeof(_data[0]), typeof(*allocator))(allocator);

                Text node, prev = this;
                do
                {
                    node = prev;
                    prev = findPreviousText(node);
                }
                while (prev);
                while (node)
                {
                    result ~= node.data;
                    node = findNextText(node);
                }
                return result;
            }
            /++
            +   Implementation of $(LINK2 ../dom/Text.replaceWholeText,
            +   `std.experimental.xml.dom.Text.replaceWholeText`).
            +/
            // the W3C DOM spec explains the details of this
            @property Text replaceWholeText(DOMString newText)
            {
                bool hasOnlyText(Node reference) @safe
                {
                    foreach (child; reference.childNodes)
                        switch (child.nodeType) with (dom.NodeType)
                        {
                            case text:
                            case cdataSection:
                                break;
                            case entityReference:
                                if (!hasOnlyText(reference))
                                    return false;
                                break;
                            default:
                                return false;
                        }
                    return false;
                }
                bool startsWithText(Node reference)
                {
                    if (!reference.firstChild) return false;
                    switch (reference.firstChild.nodeType) with (dom.NodeType)
                    {
                        case text:
                        case cdataSection:
                            return true;
                        case entityReference:
                            return startsWithText(reference.firstChild);
                        default:
                            return false;
                    }
                }
                bool endsWithText(Node reference)
                {
                    if (!reference.lastChild) return false;
                    switch (reference.lastChild.nodeType) with (dom.NodeType)
                    {
                        case text:
                        case cdataSection:
                            return true;
                        case entityReference:
                            return endsWithText(reference.lastChild);
                        default:
                            return false;
                    }
                }

                Node current;
                if (parentNode && parentNode.nodeType == dom.NodeType.entityReference)
                {
                    current = parentNode;
                    while (current.parentNode && current.parentNode.nodeType == dom.NodeType.entityReference)
                        current = current.parentNode;

                    enforce!DOMException(!(!hasOnlyText(current))
                        , dom.ExceptionCode.noModificationAllowed);
                }
                else if (readonly)
                    throw new DOMException(dom.ExceptionCode.noModificationAllowed);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.noModificationAllowed);
                else
                    current = this;

                size_t previousToKill, nextToKill;
                auto node = current.previousSibling;
                while (node)
                {
                    if (node.nodeType == dom.NodeType.entityReference)
                    {
                        if (endsWithText(node))
                        {
                            enforce!DOMException(!(!hasOnlyText(node))
                                , dom.ExceptionCode.noModificationAllowed);
                        }
                        else break;
                    }
                    else if (!cast(Text)node)
                        break;

                    previousToKill++;
                    node = node.previousSibling;
                }
                node = current.nextSibling;
                while (node)
                {
                    if (node.nodeType == dom.NodeType.entityReference)
                    {
                        if (startsWithText(node))
                        {
                            enforce!DOMException(!(!hasOnlyText(node))
                                , dom.ExceptionCode.noModificationAllowed);
                        }
                        else break;
                    }
                    else if (!cast(Text)node)
                        break;

                    nextToKill++;
                    node = node.nextSibling;
                }

                foreach (i; 0..previousToKill)
                    current.parentNode.removeChild(current.previousSibling);
                foreach (i; 0..nextToKill)
                    current.parentNode.removeChild(current.nextSibling);

                if (current.nodeType == dom.NodeType.entityReference)
                {
                    if (current.parentNode && newText)
                    {
                        auto result = ownerDocument.createTextNode(newText);
                        current.parentNode.replaceChild(current, result);
                        return result;
                    }

                    if (current.parentNode)
                        current.removeChild(current);

                    if (!newText) return null;

                    return ownerDocument.createTextNode(newText);
                }
                _data = newText;
                return this;
            }
        }
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.text; }
            @property DOMString nodeName() { return new DOMString("#text"); }

            Text cloneNode(bool deep)
            {
                Text cloned = new Text();//allocator.multiVersionMake!Text(this.outer);
                cloned._ownerDocument = _ownerDocument;
                super.performClone(cloned, deep);
                return cloned;
            }
        }
    }
    /// Implementation of $(LINK2 ../dom/Comment, `std.experimental.xml.dom.Comment`)
    class Comment : CharacterData, dom.Comment
    {
        package this() {

        }
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.comment; }
            @property DOMString nodeName() { return new DOMString("#comment"); }

            Comment cloneNode(bool deep)
            {
                Comment cloned = new Comment();//allocator.multiVersionMake!Comment(this.outer);
                cloned._ownerDocument = _ownerDocument;
                super.performClone(cloned, deep);
                return cloned;
            }
        }
    }
    /// Implementation of $(LINK2 ../dom/DocumentType, `std.experimental.xml.dom.DocumentType`)
    class DocumentType : Node, dom.DocumentType
    {
        package this() {

        }
        // specific to DocumentType
        override
        {
            /// Implementation of $(LINK2 ../dom/DocumentType.name, `std.experimental.xml.dom.DocumentType.name`).
            @property DOMString name() { return _name; }
            /++
            +   Implementation of $(LINK2 ../dom/DocumentType.entities,
            +   `std.experimental.xml.dom.DocumentType.entities`).
            +/
            @property dom.NamedNodeMap entities() { return null; }
            /++
            +   Implementation of $(LINK2 ../dom/DocumentType.notations,
            +   `std.experimental.xml.dom.DocumentType.notations`).
            +/
            @property dom.NamedNodeMap notations() { return null; }
            /++
            +   Implementation of $(LINK2 ../dom/DocumentType.publicId,
            +   `std.experimental.xml.dom.DocumentType.publicId`).
            +/
            @property DOMString publicId() { return _publicId; }
            /++
            +   Implementation of $(LINK2 ../dom/DocumentType.systemId,
            +   `std.experimental.xml.dom.DocumentType.systemId`).
            +/
            @property DOMString systemId() { return _systemId; }
            /++
            +   Implementation of $(LINK2 ../dom/DocumentType.internalSubset,
            +   `std.experimental.xml.dom.DocumentType.internalSubset`).
            +/
            @property DOMString internalSubset() { return _internalSubset; }
        }
        private DOMString _name, _publicId, _systemId, _internalSubset;
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.documentType; }
            @property DOMString nodeName() { return _name; }
        }
    }
    /// Implementation of $(LINK2 ../dom/CDATASection, `std.experimental.xml.dom.CDATASection`)
    class CDATASection : Text, dom.CDATASection
    {
        package this() {

        }
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.cdataSection; }
            @property DOMString nodeName() { return new DOMString("#cdata-section"); }

            CDATASection cloneNode(bool deep)
            {
                CDATASection cloned = new CDATASection();//allocator.multiVersionMake!CDATASection(this.outer);
                cloned._ownerDocument = _ownerDocument;
                super.performClone(cloned, deep);
                return cloned;
            }
        }
    }
    /// Implementation of $(LINK2 ../dom/ProcessingInstruction, `std.experimental.xml.dom.ProcessingInstruction`)
    class ProcessingInstruction : Node, dom.ProcessingInstruction
    {
        package this() {

        }
        // specific to ProcessingInstruction
        override
        {
            /++
            +   Implementation of $(LINK2 ../dom/ProcessingInstruction.target,
            +   `std.experimental.xml.dom.ProcessingInstruction.target`).
            +/
            @property DOMString target() { return _target; }
            /++
            +   Implementation of $(LINK2 ../dom/ProcessingInstruction.data,
            +   `std.experimental.xml.dom.ProcessingInstruction.data`).
            +/
            @property DOMString data() { return _data; }
            /// ditto
            @property void data(DOMString newVal) { _data = newVal; }
        }
        private DOMString _target, _data;
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.processingInstruction; }
            @property DOMString nodeName() { return target; }
            @property DOMString nodeValue() { return _data; }
            @property void nodeValue(DOMString newVal)
            {
                enforce!DOMException(!(readonly)
                    , dom.ExceptionCode.noModificationAllowed);
                _data = newVal;
            }

            @property DOMString textContent() { return _data; }
            @property void textContent(DOMString newVal)
            {
                enforce!DOMException(!(readonly)
                    , dom.ExceptionCode.noModificationAllowed);
                _data = newVal;
            }

            ProcessingInstruction cloneNode(bool deep)
            {
                auto cloned = new ProcessingInstruction();//allocator.multiVersionMake!ProcessingInstruction(this.outer);
                cloned._ownerDocument = _ownerDocument;
                super.performClone(cloned, deep);
                cloned._target = _target;
                cloned._data = _data;
                return cloned;
            }
        }
    }
    /// Implementation of $(LINK2 ../dom/EntityReference, `std.experimental.xml.dom.EntityReference`)
    class EntityReference : NodeWithChildren, dom.EntityReference
    {
        package this() {

        }
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.entityReference; }
            @property DOMString nodeName() { return _ent_name; }
            @property bool readonly() { return true; }
        }
        private DOMString _ent_name;
    }
    /// Implementation of $(LINK2 ../dom/DOMConfiguration, `std.experimental.xml.dom.DOMConfiguration`)
    class DOMConfiguration : dom.DOMConfiguration
    {
        import std.meta;
        import std.traits;
        package this() {

        }
        private
        {
            enum string always = "((x) => true)";

            static struct Config
            {
                string name;
                string type;
                string settable;
            }

            struct Params
            {
                @Config("cdata-sections", "bool", always) bool cdata_sections;
                @Config("comments", "bool", always) bool comments;
                @Config("entities", "bool", always) bool entities;
                //@Config("error-handler", "ErrorHandler", always) ErrorHandler error_handler;
                @Config("namespace-declarations", "bool", always) bool namespace_declarations;
                @Config("split-cdata-sections", "bool", always) bool split_cdata_sections;
            }
            Params params;

            void assign(string field, string type)(dom.UserData val) @trusted
            {
                mixin("if (val.convertsTo!(" ~ type ~ ")) params." ~ field ~ " = val.get!(" ~ type ~ "); \n");
            }
            bool canSet(string type, string settable)(dom.UserData val) @trusted
            {
                mixin("if (val.convertsTo!(" ~ type ~ ")) return " ~ settable ~ "(val.get!(" ~ type ~ ")); \n");
                return false;
            }
        }
        // specific to DOMConfiguration
        override
        {
            /++
            +   Implementation of $(LINK2 ../dom/DOMConfiguration.setParameter,
            +   `std.experimental.xml.dom.DOMConfiguration.setParameter`).
            +/
            void setParameter(string name, dom.UserData value) @trusted
            {
                switch (name)
                {
                    foreach (field; AliasSeq!(__traits(allMembers, Params)))
                    {
                        mixin("enum type = getUDAs!(Params." ~ field ~ ", Config)[0].type; \n");
                        mixin("case getUDAs!(Params." ~ field ~ ", Config)[0].name: assign!(field, type)(value); \n");
                    }
                    default:
                        throw new DOMException(dom.ExceptionCode.notFound);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.notFound);
                }
            }
            /++
            +   Implementation of $(LINK2 ../dom/DOMConfiguration.getParameter,
            +   `std.experimental.xml.dom.DOMConfiguration.getParameter`).
            +/
            dom.UserData getParameter(string name) @trusted
            {
                switch (name)
                {
                    foreach (field; AliasSeq!(__traits(allMembers, Params)))
                    {
                        mixin("case getUDAs!(Params." ~ field ~ ", Config)[0].name: \n" ~
                                    "return dom.UserData(params." ~ field ~ "); \n");
                    }
                    default:
                        throw new DOMException(dom.ExceptionCode.notFound);//allocator.multiVersionMake!DOMException(this.outer, dom.ExceptionCode.notFound);
                }
            }
            /++
            +   Implementation of $(LINK2 ../dom/DOMConfiguration.canSetParameter,
            +   `std.experimental.xml.dom.DOMConfiguration.canSetParameter`).
            +/
            bool canSetParameter(string name, dom.UserData value) @trusted
            {
                switch (name)
                {
                    foreach (field; AliasSeq!(__traits(allMembers, Params)))
                    {
                        mixin("enum type = getUDAs!(Params." ~ field ~ ", Config)[0].type; \n");
                        mixin("enum settable = getUDAs!(Params." ~ field ~ ", Config)[0].settable; \n");
                        mixin("case getUDAs!(Params." ~ field ~ ", Config)[0].name: \n" ~
                                    "return canSet!(type, settable)(value); \n");
                    }
                    default:
                        return false;
                }
            }
            /++
            +   Implementation of $(LINK2 ../dom/DOMConfiguration.parameterNames,
            +   `std.experimental.xml.dom.DOMConfiguration.parameterNames`).
            +/
            @property dom.DOMStringList parameterNames()
            {
                return new StringList();
            }
        }

        class StringList : dom.DOMStringList
        {
            package this() {

            }
            private template MapToConfigName(Members...)
            {
                static if (Members.length > 0)
                    mixin("alias MapToConfigName = AliasSeq!(getUDAs!(Params." ~ Members[0] ~
                            ", Config)[0].name, MapToConfigName!(Members[1..$])); \n");
                else
                    alias MapToConfigName = AliasSeq!();
            }
            static immutable string[] arr = [MapToConfigName!(__traits(allMembers, Params))];

            // specific to DOMStringList
            override
            {
                DOMString item(size_t index) { return new DOMString(arr[index]); }
                size_t length() { return arr.length; }

                bool contains(DOMString str)
                {
                    import std.algorithm: canFind;
                    return arr.canFind(str);
                }
            }
            //alias arr this;
        }
    }
}

/++
+   Instantiates a `DOMBuilder` specialized for the `DOMImplementation` implemented
+   in this module.
+/
/+auto domBuilder(CursorType)(auto ref CursorType cursor)
{
    //import std.experimental.allocator.gc_allocator;//import stdx.allocator.gc_allocator;
    import dompar = std.experimental.xml.domparser;
    return dompar.domBuilder(cursor, new DOMImplementation());//return dompar.domBuilder(cursor, new DOMImplementation!(CursorType.StringType, shared(GCAllocator))());
}+/

unittest
{
    
    DOMImplementation impl = new DOMImplementation();

    auto doc = impl.createDocument(new DOMString("myNamespaceURI"), new DOMString("myPrefix:myRootElement"), null);
    auto root = doc.documentElement;
    assert(root.prefix == "myPrefix");

    auto attr = doc.createAttributeNS(new DOMString("myAttrNamespace"), new DOMString("myAttrPrefix:myAttrName"));
    root.setAttributeNode(attr);
    assert(root.attributes.length == 1);
    assert(root.getAttributeNodeNS(new DOMString("myAttrNamespace"), new DOMString("myAttrName")) is attr);

    attr.nodeValue = new DOMString("myAttrValue");
    assert(attr.childNodes.length == 1);
    assert(attr.firstChild.nodeType == dom.NodeType.text);
    assert(attr.firstChild.nodeValue == attr.nodeValue);

    auto elem = doc.createElementNS(new DOMString("myOtherNamespace"), new DOMString("myOtherPrefix:myOtherElement"));
    assert(root.ownerDocument is doc);
    assert(elem.ownerDocument is doc);
    root.appendChild(elem);
    assert(root.firstChild is elem);
    assert(root.firstChild.namespaceURI == "myOtherNamespace");

    auto comm = doc.createComment(new DOMString("myWonderfulComment"));
    doc.insertBefore(comm, root);
    assert(doc.childNodes.length == 2);
    assert(doc.firstChild is comm);

    assert(comm.substringData(1, 4) == "yWon");
    comm.replaceData(0, 2, new DOMString("your"));
    comm.deleteData(4, 9);
    comm.insertData(4, new DOMString("Questionable"));
    assert(comm.data == "yourQuestionableComment");

    auto pi = doc.createProcessingInstruction(new DOMString("myPITarget"), new DOMString("myPIData"));
    elem.appendChild(pi);
    assert(elem.lastChild is pi);
    auto cdata = doc.createCDATASection(new DOMString("mycdataContent"));
    elem.replaceChild(cdata, pi);
    assert(elem.lastChild is cdata);
    elem.removeChild(cdata);
    assert(elem.childNodes.length == 0);

    assert(doc.getElementsByTagNameNS(new DOMString("myOtherNamespace"), new DOMString("myOtherElement")).item(0) is elem);

    doc.setUserData("userDataKey1", dom.UserData(3.14), null);
    doc.setUserData("userDataKey2", dom.UserData(new Object()), null);
    doc.setUserData("userDataKey3", dom.UserData(null), null);
    assert(doc.getUserData("userDataKey1") == 3.14);
    assert(doc.getUserData("userDataKey2").type == typeid(Object));
    assert(doc.getUserData("userDataKey3").peek!long is null);

    assert(elem.lookupNamespaceURI(new DOMString("myOtherPrefix")) == "myOtherNamespace");
    assert(doc.lookupPrefix(new DOMString("myNamespaceURI")) == "myPrefix");

    assert(elem.isEqualNode(elem.cloneNode(false)));
    assert(root.isEqualNode(root.cloneNode(true)));
    assert(comm.isEqualNode(comm.cloneNode(false)));
    assert(pi.isEqualNode(pi.cloneNode(false)));
}

unittest
{
    import newxml.lexers;
    import newxml.parser;
    import newxml.cursor;
    //import newxml.domparser;
    import std.stdio;

    string xml = q"{
    <?xml version = '1.0' standalone = 'yes'?>
    <books>
        <book ISBN = '078-5342635362'>
            <title>The D Programming Language</title>
            <author>A. Alexandrescu</author>
        </book>
        <book ISBN = '978-1515074601'>
            <title>Programming in D</title>
            <author>Ali Çehreli</author>
        </book>
        <book ISBN = '978-0201704310' about-d = 'no'>
            <title>Modern C++ Design</title>
            <author>A. Alexandrescu</author>
        </book>
    </books>
    }";

    /+auto builder =
         xml
        .lexer
        .parser
        .cursor
        .domBuilder;

    builder.setSource(xml);
    builder.buildRecursive;

    auto doc = builder.getDocument;
    auto books = doc.getElementsByTagName("book");
    auto authors = doc.getElementsByTagName("author");
    auto titles = doc.getElementsByTagName("title");

    assert(doc.xmlVersion == "1.0");
    assert(doc.xmlStandalone);

    enum Pos(dom.DocumentPosition pos) = cast(BitFlags!(dom.DocumentPosition))pos;
    with (dom.DocumentPosition)
    {
        assert(books[1].compareDocumentPosition(authors[2]) == Pos!following);
        assert(authors[2].compareDocumentPosition(titles[0]) == Pos!preceding);
        assert(books[1].compareDocumentPosition(titles[1]) == (Pos!containedBy | Pos!following));
        assert(authors[0].compareDocumentPosition(books[0]) == (Pos!contains | Pos!preceding));
        assert(titles[2].compareDocumentPosition(titles[2]) == Pos!none);
        assert(books[2].attributes[0].compareDocumentPosition(books[2].attributes[1])
                == (Pos!implementationSpecific | Pos!following));
        assert(books[2].attributes[1].compareDocumentPosition(books[2].attributes[0])
                == (Pos!implementationSpecific | Pos!preceding));
    }

    assert(books[1].cloneNode(true).childNodes[1].isEqualNode(authors[1]));

    books[2].setIdAttributeNode(books[2].attributes[1], true);
    assert(books[2].attributes[1].isId);
    assert(doc.getElementById("978-0201704310") is books[2]);

    alias Text = typeof(doc.implementation).Text;
    titles[1].appendChild(doc.createTextNode(" for Dummies"));
    assert((cast(Text)(titles[1].firstChild)).wholeText == "Programming in D for Dummies");
    (cast(Text)(titles[1].lastChild)).replaceWholeText(titles[1].firstChild.textContent);
    assert(titles[1].textContent == "Programming in D");
    assert(titles[1].childNodes.length == 1);+/
}
 

module newxml;

public import newxml.dom;
public import domimpl = newxml.domimpl;
public import newxml.domparser;
public import newxml.domstring;
public import newxml.sax;
public import newxml.writer;
public import newxml.cursor;
public import newxml.lexers;
public import newxml.parser;

/++ This function parses a string `input`
+ into `Document`
+
+ Params:
+   input = The `string` to parse
+
+ Returns:
+   The parsed xml `Document`
+/
Document parseXMLString(string input)
{
    auto builder =
             input
            .lexer
            .parser
            .cursor
            .domBuilder(new domimpl.DOMImplementation());

    builder.setSource(input);
    builder.buildRecursive();
    return builder.getDocument;
}

///
unittest {
    import std.format;

    string xml = q"{
    <!DOCTYPE mydoc https://myUri.org/bla [
        <!ELEMENT myelem ANY>
        <!ENTITY   myent    "replacement text">
        <!ATTLIST myelem foo cdata #REQUIRED >
        <!NOTATION PUBLIC 'h'>
        <!FOODECL asdffdsa >
    ]>
    }";

    Document doc = parseXMLString(xml);
    assert(doc !is null);
    assert(doc.doctype.entities.getNamedItem(new DOMString("myent")).nodeValue == "replacement text");
}
